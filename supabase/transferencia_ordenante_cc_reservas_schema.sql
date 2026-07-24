-- Mismo respaldo de la transferencia verificada en Mercado Pago que ya se
-- guarda en ventas, ahora tambien en los pagos de cuenta corriente y en los
-- abonos/retiros de reservas.
--
-- Las tres funciones se recrean con cuatro parametros nuevos, todos con
-- DEFAULT NULL, asi las llamadas viejas siguen funcionando igual. Hay que
-- borrar la version anterior primero: agregar parametros crea una sobrecarga
-- nueva en vez de reemplazar, y PostgREST no sabria cual elegir.

alter table cuenta_corriente_movimientos add column if not exists transferencia_pago_id text;
alter table cuenta_corriente_movimientos add column if not exists transferencia_pagador text;
alter table cuenta_corriente_movimientos add column if not exists transferencia_pagador_cuit text;
alter table cuenta_corriente_movimientos add column if not exists transferencia_verificada_at timestamptz;

alter table reserva_pagos add column if not exists transferencia_pago_id text;
alter table reserva_pagos add column if not exists transferencia_pagador text;
alter table reserva_pagos add column if not exists transferencia_pagador_cuit text;
alter table reserva_pagos add column if not exists transferencia_verificada_at timestamptz;

-- ---------------------------------------------------------------- cuenta cte
drop function if exists public.registrar_pago_cuenta_corriente(uuid, text, numeric, numeric, text, numeric, numeric, integer, numeric, text);

create or replace function public.registrar_pago_cuenta_corriente(
  p_cliente_id uuid, p_local text, p_pago_contado numeric, p_pago_transferencia numeric,
  p_transferencia_alias text, p_pago_tarjeta_debito numeric, p_pago_tarjeta_credito numeric,
  p_tarjeta_credito_cuotas integer, p_tarjeta_credito_recargo_pct numeric, p_nota text default null,
  p_transferencia_pago_id text default null, p_transferencia_pagador text default null,
  p_transferencia_pagador_cuit text default null, p_transferencia_verificada_at timestamptz default null)
returns uuid
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
    caja_sesion_id,
    transferencia_pago_id, transferencia_pagador, transferencia_pagador_cuit, transferencia_verificada_at
  ) values (
    p_cliente_id, 'pago', v_monto, p_local, v_usuario, p_nota,
    nullif(p_pago_contado,0), nullif(p_pago_transferencia,0), p_transferencia_alias,
    nullif(p_pago_tarjeta_debito,0), nullif(p_pago_tarjeta_credito,0), p_tarjeta_credito_cuotas, p_tarjeta_credito_recargo_pct,
    v_caja_sesion_id,
    p_transferencia_pago_id, p_transferencia_pagador, p_transferencia_pagador_cuit, p_transferencia_verificada_at
  ) returning id into v_id;

  return v_id;
end $function$;

grant execute on function public.registrar_pago_cuenta_corriente(uuid, text, numeric, numeric, text, numeric, numeric, integer, numeric, text, text, text, text, timestamptz) to anon, authenticated, service_role;

-- ------------------------------------------------------------ abono reserva
drop function if exists public.registrar_pago_reserva(uuid, numeric, text, uuid, text, text);

create or replace function public.registrar_pago_reserva(
  p_reserva_id uuid, p_monto numeric, p_medio text, p_caja_sesion_id uuid,
  p_alias text default null, p_nota text default null,
  p_transferencia_pago_id text default null, p_transferencia_pagador text default null,
  p_transferencia_pagador_cuit text default null, p_transferencia_verificada_at timestamptz default null)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_reserva  record;
  v_saldo    numeric;
  v_usuario  text;
begin
  if not public.is_admin() then
    raise exception 'Necesitas una sesion valida para cobrar un abono.';
  end if;
  if p_monto is null or p_monto <= 0 then
    raise exception 'El abono tiene que ser mayor a 0.';
  end if;

  select * into v_reserva from reservas where id = p_reserva_id for update;
  if not found then raise exception 'Reserva no encontrada.'; end if;
  if v_reserva.estado <> 'activa' then
    raise exception 'La reserva no esta activa (esta %).', v_reserva.estado;
  end if;

  select saldo_pendiente into v_saldo from v_reservas where id = p_reserva_id;
  if p_monto > v_saldo then
    raise exception 'El abono (%) es mayor que el saldo pendiente (%).', p_monto, v_saldo;
  end if;

  perform public._reserva_caja_valida(p_caja_sesion_id, v_reserva.local);
  v_usuario := auth.jwt()->>'email';

  insert into reserva_pagos(reserva_id, tipo, monto, medio, transferencia_alias,
                            local, caja_sesion_id, usuario, nota,
                            transferencia_pago_id, transferencia_pagador,
                            transferencia_pagador_cuit, transferencia_verificada_at)
  values (p_reserva_id, 'abono', p_monto, coalesce(p_medio,'contado'), p_alias,
          v_reserva.local, p_caja_sesion_id, v_usuario, p_nota,
          p_transferencia_pago_id, p_transferencia_pagador,
          p_transferencia_pagador_cuit, p_transferencia_verificada_at);

  return (select to_jsonb(v) from v_reservas v where v.id = p_reserva_id);
end $function$;

grant execute on function public.registrar_pago_reserva(uuid, numeric, text, uuid, text, text, text, text, text, timestamptz) to anon, authenticated, service_role;

-- ----------------------------------------------------------- retiro reserva
drop function if exists public.retirar_reserva(uuid, uuid, numeric, text, text);

create or replace function public.retirar_reserva(
  p_reserva_id uuid, p_caja_sesion_id uuid default null, p_pago_monto numeric default null,
  p_pago_medio text default null, p_pago_alias text default null,
  p_transferencia_pago_id text default null, p_transferencia_pagador text default null,
  p_transferencia_pagador_cuit text default null, p_transferencia_verificada_at timestamptz default null)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_reserva record;
  v_saldo   numeric;
  v_usuario text;
begin
  if not public.is_admin() then
    raise exception 'Necesitas una sesion valida para retirar una reserva.';
  end if;

  select * into v_reserva from reservas where id = p_reserva_id for update;
  if not found then raise exception 'Reserva no encontrada.'; end if;
  if v_reserva.estado <> 'activa' then
    raise exception 'La reserva no esta activa (esta %).', v_reserva.estado;
  end if;

  v_usuario := auth.jwt()->>'email';

  if p_pago_monto is not null and p_pago_monto > 0 then
    select saldo_pendiente into v_saldo from v_reservas where id = p_reserva_id;
    if p_pago_monto > v_saldo then
      raise exception 'El pago (%) es mayor que el saldo pendiente (%).', p_pago_monto, v_saldo;
    end if;
    perform public._reserva_caja_valida(p_caja_sesion_id, v_reserva.local);
    insert into reserva_pagos(reserva_id, tipo, monto, medio, transferencia_alias,
                              local, caja_sesion_id, usuario,
                              transferencia_pago_id, transferencia_pagador,
                              transferencia_pagador_cuit, transferencia_verificada_at)
    values (p_reserva_id, 'abono', p_pago_monto, coalesce(p_pago_medio,'contado'),
            p_pago_alias, v_reserva.local, p_caja_sesion_id, v_usuario,
            p_transferencia_pago_id, p_transferencia_pagador,
            p_transferencia_pagador_cuit, p_transferencia_verificada_at);
  end if;

  select saldo_pendiente into v_saldo from v_reservas where id = p_reserva_id;
  if v_saldo > 0 then
    raise exception 'Todavia queda saldo pendiente (%). Cobralo antes de retirar.', v_saldo;
  end if;

  update reservas
    set estado = 'retirada', retirada_at = now()
    where id = p_reserva_id;

  return (select to_jsonb(v) from v_reservas v where v.id = p_reserva_id);
end $function$;

grant execute on function public.retirar_reserva(uuid, uuid, numeric, text, text, text, text, text, timestamptz) to anon, authenticated, service_role;
