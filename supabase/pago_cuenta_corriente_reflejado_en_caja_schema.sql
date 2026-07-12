-- ============================================================
--  Pagos de cuenta corriente reflejados en caja: hasta ahora, cuando un
--  cliente pagaba su saldo pendiente, quedaba solo como un movimiento de
--  cuenta corriente, sin tocar caja_sesiones — si el pago era en efectivo,
--  ese dinero entraba a la caja física pero no se sumaba al efectivo
--  esperado al cerrar, generando una diferencia sin explicación en el arqueo.
--
--  Se agrega el mismo desglose de medios de pago que tiene una venta
--  (efectivo, transferencia + alias, débito, crédito con cuotas/recargo) y
--  se conecta con caja_sesiones: un pago con algo de efectivo exige que haya
--  caja abierta en ese local, y cerrar_caja_sesion ahora también lo suma al
--  efectivo esperado (además de las ventas en efectivo, y restando las
--  devoluciones en efectivo).
--
--  Confirmado explícitamente por el usuario el 2026-07-12 antes de aplicar
--  (clasificador de seguridad lo pidió por tocar caja + cuenta corriente).
--  Ya aplicada en Supabase — este archivo queda como referencia/backup.
-- ============================================================

alter table cuenta_corriente_movimientos add column if not exists pago_contado numeric(12,2);
alter table cuenta_corriente_movimientos add column if not exists pago_transferencia numeric(12,2);
alter table cuenta_corriente_movimientos add column if not exists transferencia_alias text;
alter table cuenta_corriente_movimientos add column if not exists pago_tarjeta_debito numeric(12,2);
alter table cuenta_corriente_movimientos add column if not exists pago_tarjeta_credito numeric(12,2);
alter table cuenta_corriente_movimientos add column if not exists tarjeta_credito_cuotas integer;
alter table cuenta_corriente_movimientos add column if not exists tarjeta_credito_recargo_pct numeric(6,2);
alter table cuenta_corriente_movimientos add column if not exists caja_sesion_id uuid references caja_sesiones(id);

create or replace function public.registrar_pago_cuenta_corriente(
  p_cliente_id uuid, p_local text,
  p_pago_contado numeric, p_pago_transferencia numeric, p_transferencia_alias text,
  p_pago_tarjeta_debito numeric, p_pago_tarjeta_credito numeric,
  p_tarjeta_credito_cuotas integer, p_tarjeta_credito_recargo_pct numeric,
  p_nota text default null
) returns uuid
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_usuario text;
  v_local_asignado text;
  v_monto numeric;
  v_caja_sesion_id uuid;
  v_id uuid;
begin
  if not public.is_admin() then
    raise exception 'Necesitás una sesión válida para registrar un pago.';
  end if;
  if p_local not in ('camerino','giustozzi') then
    raise exception 'Local inválido.';
  end if;
  v_local_asignado := public.mi_local_asignado();
  if v_local_asignado is not null and v_local_asignado <> p_local then
    raise exception 'Tu usuario solo puede registrar pagos en %', v_local_asignado;
  end if;

  v_monto := coalesce(p_pago_contado,0) + coalesce(p_pago_transferencia,0)
    + coalesce(p_pago_tarjeta_debito,0) + coalesce(p_pago_tarjeta_credito,0);
  if v_monto <= 0 then
    raise exception 'Ingresá un monto mayor a 0 en algún medio de pago.';
  end if;

  if coalesce(p_pago_contado,0) > 0 then
    select id into v_caja_sesion_id from caja_sesiones where local = p_local and estado = 'abierta';
    if v_caja_sesion_id is null then
      raise exception 'No hay caja abierta en % — abrila antes de registrar un pago en efectivo.', p_local;
    end if;
  end if;

  v_usuario := auth.jwt()->>'email';
  insert into cuenta_corriente_movimientos (
    cliente_id, tipo, monto, local, usuario, nota,
    pago_contado, pago_transferencia, transferencia_alias,
    pago_tarjeta_debito, pago_tarjeta_credito, tarjeta_credito_cuotas, tarjeta_credito_recargo_pct,
    caja_sesion_id
  ) values (
    p_cliente_id, 'pago', v_monto, p_local, v_usuario, p_nota,
    nullif(p_pago_contado,0), nullif(p_pago_transferencia,0), p_transferencia_alias,
    nullif(p_pago_tarjeta_debito,0), nullif(p_pago_tarjeta_credito,0), p_tarjeta_credito_cuotas, p_tarjeta_credito_recargo_pct,
    v_caja_sesion_id
  ) returning id into v_id;

  return v_id;
end $function$;
grant execute on function public.registrar_pago_cuenta_corriente(uuid, text, numeric, numeric, text, numeric, numeric, integer, numeric, text) to authenticated;

-- cerrar_caja_sesion: ahora también suma el efectivo entrado por pagos de
-- cuenta corriente (además de ventas, y restando devoluciones en efectivo).
create or replace function public.cerrar_caja_sesion(
  p_sesion_id uuid, p_gastos numeric, p_retiros numeric, p_adelantos numeric,
  p_cambio numeric, p_arqueo numeric, p_observaciones text default null
) returns void
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_usuario text;
  v_local_asignado text;
  v_sesion record;
  v_ventas_contado numeric := 0;
  v_devoluciones_efectivo numeric := 0;
  v_pagos_cc_efectivo numeric := 0;
  v_esperado numeric;
begin
  if not public.is_admin() then
    raise exception 'Necesitás una sesión válida para cerrar la caja.';
  end if;
  select * into v_sesion from caja_sesiones where id = p_sesion_id for update;
  if not found then raise exception 'Caja no encontrada.'; end if;
  if v_sesion.estado <> 'abierta' then
    raise exception 'Esta caja ya está cerrada.';
  end if;

  v_local_asignado := public.mi_local_asignado();
  if v_local_asignado is not null and v_local_asignado <> v_sesion.local then
    raise exception 'Tu usuario solo puede cerrar la caja de %', v_sesion.local;
  end if;

  select coalesce(sum(pago_contado),0) into v_ventas_contado from ventas where caja_sesion_id = p_sesion_id;
  select coalesce(sum(monto),0) into v_devoluciones_efectivo from devoluciones where caja_sesion_id = p_sesion_id and medio_devolucion = 'efectivo';
  select coalesce(sum(pago_contado),0) into v_pagos_cc_efectivo from cuenta_corriente_movimientos where caja_sesion_id = p_sesion_id and tipo = 'pago';
  v_esperado := v_sesion.fondo_inicial + v_ventas_contado + v_pagos_cc_efectivo - v_devoluciones_efectivo
    + coalesce(p_cambio,0) - coalesce(p_gastos,0) - coalesce(p_retiros,0) - coalesce(p_adelantos,0);
  v_usuario := auth.jwt()->>'email';

  update caja_sesiones set
    estado = 'cerrada',
    gastos = coalesce(p_gastos,0),
    retiros = coalesce(p_retiros,0),
    adelantos = coalesce(p_adelantos,0),
    cambio = coalesce(p_cambio,0),
    arqueo = p_arqueo,
    efectivo_esperado = v_esperado,
    diferencia = coalesce(p_arqueo,0) - v_esperado,
    observaciones = p_observaciones,
    cerrada_por = v_usuario,
    cerrada_at = now()
  where id = p_sesion_id;
end $function$;
