-- ============================================================
--  Devoluciones de mercadería: distinto del flujo de Notas de Crédito AFIP
--  (que sigue sin probarse). Busca la venta original (debe estar SIN
--  facturar — si ya tiene CAE real, corresponde una Nota de Crédito, no
--  esto), repone el stock de los productos elegidos, y registra el
--  reintegro (efectivo o transferencia). Si el reintegro es en efectivo,
--  exige que haya una caja abierta en ese local, y se descuenta del
--  efectivo esperado al cerrar esa caja (cerrar_caja_sesion actualizada).
--  Confirmado explícitamente por el usuario el 2026-07-12 antes de aplicar
--  (clasificador de seguridad lo pidió por tocar stock + caja + tabla nueva).
--  Ya aplicada en Supabase — este archivo queda como referencia/backup.
-- ============================================================

create table if not exists devoluciones (
  id uuid primary key default gen_random_uuid(),
  venta_id uuid not null references ventas(id),
  local text not null check (local in ('camerino','giustozzi')),
  items jsonb not null default '[]'::jsonb,
  monto numeric(12,2) not null check (monto >= 0),
  medio_devolucion text not null check (medio_devolucion in ('efectivo','transferencia')),
  caja_sesion_id uuid references caja_sesiones(id),
  motivo text,
  usuario text,
  created_at timestamptz not null default now()
);
create index if not exists idx_devoluciones_venta on devoluciones(venta_id);
create index if not exists idx_devoluciones_fecha on devoluciones(created_at desc);

alter table devoluciones enable row level security;
drop policy if exists "admin all devoluciones" on devoluciones;
create policy "admin all devoluciones" on devoluciones for all using (public.is_admin()) with check (public.is_admin());

create or replace function public.registrar_devolucion(
  p_venta_id uuid, p_items jsonb, p_medio_devolucion text, p_motivo text default null
) returns uuid
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_usuario text;
  v_local_asignado text;
  v_venta record;
  v_monto numeric := 0;
  it jsonb;
  v_caja_sesion_id uuid;
  v_id uuid;
begin
  if not public.is_admin() then
    raise exception 'Necesitás una sesión válida para registrar una devolución.';
  end if;
  if p_medio_devolucion not in ('efectivo','transferencia') then
    raise exception 'Medio de devolución inválido.';
  end if;

  select * into v_venta from ventas where id = p_venta_id;
  if not found then raise exception 'Venta no encontrada.'; end if;
  if v_venta.facturada then
    raise exception 'Esta venta ya está facturada — para devoluciones de ventas facturadas hay que emitir una Nota de Crédito.';
  end if;

  v_local_asignado := public.mi_local_asignado();
  if v_local_asignado is not null and v_local_asignado <> v_venta.local then
    raise exception 'Tu usuario solo puede procesar devoluciones en %', v_local_asignado;
  end if;

  if jsonb_array_length(coalesce(p_items,'[]'::jsonb)) = 0 then
    raise exception 'Elegí al menos un producto para devolver.';
  end if;

  v_usuario := auth.jwt()->>'email';

  if p_medio_devolucion = 'efectivo' then
    select id into v_caja_sesion_id from caja_sesiones where local = v_venta.local and estado = 'abierta';
    if v_caja_sesion_id is null then
      raise exception 'No hay caja abierta en % — abrila antes de devolver en efectivo.', v_venta.local;
    end if;
  end if;

  for it in select * from jsonb_array_elements(p_items) loop
    v_monto := v_monto + coalesce((it->>'precio')::numeric, 0);
    perform public._ajustar_stock_uno(
      it->>'codigo', it->>'talle', it->>'color', v_venta.local, 1, 'devolucion', v_usuario, p_venta_id
    );
  end loop;

  insert into devoluciones (venta_id, local, items, monto, medio_devolucion, caja_sesion_id, motivo, usuario)
  values (p_venta_id, v_venta.local, p_items, v_monto, p_medio_devolucion, v_caja_sesion_id, p_motivo, v_usuario)
  returning id into v_id;

  return v_id;
end $function$;
grant execute on function public.registrar_devolucion(uuid, jsonb, text, text) to authenticated;

-- cerrar_caja_sesion pasa a restar las devoluciones en efectivo de esa caja
-- del efectivo esperado (misma firma de siempre, solo cambia el cálculo).
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
  v_esperado := v_sesion.fondo_inicial + v_ventas_contado - v_devoluciones_efectivo + coalesce(p_cambio,0) - coalesce(p_gastos,0) - coalesce(p_retiros,0) - coalesce(p_adelantos,0);
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
