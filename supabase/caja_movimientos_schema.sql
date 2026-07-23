-- ============================================================
--  Movimientos de caja durante el día: hasta ahora los gastos, retiros,
--  adelantos y el cambio se cargaban TODOS JUNTOS recién al tocar "Cerrar
--  caja" — de memoria, al final de la jornada, sin detalle de qué fue cada
--  cosa y sin poder ver durante el día cuánto efectivo debería haber.
--
--  Ahora cada movimiento se carga en el momento en que pasa, con tipo,
--  categoría, descripción y quién lo cargó. El cierre de caja pasa a pedir
--  solo el ARQUEO (lo contado a mano) + observaciones: gastos, retiros,
--  adelantos, ingresos y cambio salen sumados de esta tabla.
--
--  Signos: gasto / retiro / adelanto SALEN de la caja (-)
--          ingreso / cambio ENTRAN a la caja (+)
--
--  Anulación: mientras la caja siga abierta, cualquier usuario del local
--  puede anular un movimiento (queda marcado anulado=true, nunca se borra);
--  el gerente puede anular siempre. Decidido con el usuario el 2026-07-23.
-- ============================================================

create table if not exists caja_movimientos (
  id            uuid primary key default gen_random_uuid(),
  sesion_id     uuid not null references caja_sesiones(id) on delete cascade,
  local         text not null check (local in ('camerino','giustozzi')),
  tipo          text not null check (tipo in ('gasto','retiro','adelanto','ingreso','cambio')),
  categoria     text,
  monto         numeric(12,2) not null check (monto > 0),
  descripcion   text,
  usuario       text,
  created_at    timestamptz not null default now(),
  anulado       boolean not null default false,
  anulado_por   text,
  anulado_at    timestamptz,
  anulado_motivo text
);
create index if not exists idx_caja_mov_sesion on caja_movimientos(sesion_id);
create index if not exists idx_caja_mov_fecha on caja_movimientos(created_at desc);

alter table caja_movimientos enable row level security;
drop policy if exists "admin all caja_movimientos" on caja_movimientos;
create policy "admin all caja_movimientos" on caja_movimientos
  for all using (public.is_admin()) with check (public.is_admin());

-- Signo de cada tipo, en un solo lugar.
create or replace function public.caja_mov_signo(p_tipo text)
returns integer language sql immutable
set search_path to 'public', 'pg_temp'
as $function$ select case when p_tipo in ('ingreso','cambio') then 1 else -1 end $function$;

-- ---------- Registrar un movimiento (durante el día) ----------
create or replace function public.registrar_movimiento_caja(
  p_local text, p_tipo text, p_monto numeric,
  p_categoria text default null, p_descripcion text default null
) returns uuid
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_usuario text;
  v_local_asignado text;
  v_sesion_id uuid;
  v_id uuid;
begin
  if not public.is_admin() then
    raise exception 'Necesitás una sesión válida para cargar un movimiento de caja.';
  end if;
  if p_local not in ('camerino','giustozzi') then
    raise exception 'Local inválido.';
  end if;
  if p_tipo not in ('gasto','retiro','adelanto','ingreso','cambio') then
    raise exception 'Tipo de movimiento inválido.';
  end if;
  if coalesce(p_monto,0) <= 0 then
    raise exception 'El monto tiene que ser mayor a 0.';
  end if;

  v_local_asignado := public.mi_local_asignado();
  if v_local_asignado is not null and v_local_asignado <> p_local then
    raise exception 'Tu usuario solo puede cargar movimientos en %', v_local_asignado;
  end if;

  select id into v_sesion_id from caja_sesiones where local = p_local and estado = 'abierta';
  if v_sesion_id is null then
    raise exception 'No hay caja abierta en % — abrila antes de cargar movimientos.', p_local;
  end if;

  v_usuario := auth.jwt()->>'email';
  insert into caja_movimientos (sesion_id, local, tipo, categoria, monto, descripcion, usuario)
  values (v_sesion_id, p_local, p_tipo, nullif(trim(coalesce(p_categoria,'')),''), p_monto,
          nullif(trim(coalesce(p_descripcion,'')),''), v_usuario)
  returning id into v_id;
  return v_id;
end $function$;
grant execute on function public.registrar_movimiento_caja(text, text, numeric, text, text) to authenticated;

-- ---------- Anular un movimiento cargado por error ----------
create or replace function public.anular_movimiento_caja(p_id uuid, p_motivo text default null)
returns void
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_usuario text;
  v_local_asignado text;
  v_mov record;
  v_estado text;
begin
  if not public.is_admin() then
    raise exception 'Necesitás una sesión válida para anular un movimiento.';
  end if;
  select * into v_mov from caja_movimientos where id = p_id for update;
  if not found then raise exception 'Movimiento no encontrado.'; end if;
  if v_mov.anulado then raise exception 'Ese movimiento ya estaba anulado.'; end if;

  select estado into v_estado from caja_sesiones where id = v_mov.sesion_id;
  if v_estado <> 'abierta' and not public.is_gerente() then
    raise exception 'La caja de ese movimiento ya está cerrada — pedile al gerente que lo corrija.';
  end if;

  v_local_asignado := public.mi_local_asignado();
  if v_local_asignado is not null and v_local_asignado <> v_mov.local then
    raise exception 'Tu usuario solo puede anular movimientos de %', v_local_asignado;
  end if;

  v_usuario := auth.jwt()->>'email';
  update caja_movimientos
     set anulado = true, anulado_por = v_usuario, anulado_at = now(),
         anulado_motivo = nullif(trim(coalesce(p_motivo,'')),'')
   where id = p_id;
end $function$;
grant execute on function public.anular_movimiento_caja(uuid, text) to authenticated;

-- ---------- Estado en vivo de la caja abierta ----------
-- Devuelve el desglose completo para mostrar "efectivo esperado ahora"
-- sin tener que abrir el formulario de cierre.
create or replace function public.estado_caja_sesion(p_sesion_id uuid)
returns jsonb
language plpgsql stable
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_s record;
  v_ventas_contado numeric := 0;
  v_ventas_total numeric := 0;
  v_ventas_cant integer := 0;
  v_pagos_cc numeric := 0;
  v_devol numeric := 0;
  v_reservas numeric := 0;
  v_gastos numeric := 0;
  v_retiros numeric := 0;
  v_adelantos numeric := 0;
  v_ingresos numeric := 0;
  v_cambio numeric := 0;
begin
  if not public.is_admin() then
    raise exception 'Necesitás una sesión válida.';
  end if;
  select * into v_s from caja_sesiones where id = p_sesion_id;
  if not found then raise exception 'Caja no encontrada.'; end if;

  select coalesce(sum(pago_contado),0), coalesce(sum(total),0), count(*)
    into v_ventas_contado, v_ventas_total, v_ventas_cant
    from ventas where caja_sesion_id = p_sesion_id;
  select coalesce(sum(pago_contado),0) into v_pagos_cc
    from cuenta_corriente_movimientos where caja_sesion_id = p_sesion_id and tipo = 'pago';
  select coalesce(sum(monto),0) into v_devol
    from devoluciones where caja_sesion_id = p_sesion_id and medio_devolucion = 'efectivo';
  -- Efectivo neto de reservas: señas y abonos suman, reintegros restan.
  select coalesce(sum(case when tipo = 'reintegro' then -monto else monto end),0) into v_reservas
    from reserva_pagos where caja_sesion_id = p_sesion_id and medio = 'contado';

  select
    coalesce(sum(monto) filter (where tipo='gasto'),0),
    coalesce(sum(monto) filter (where tipo='retiro'),0),
    coalesce(sum(monto) filter (where tipo='adelanto'),0),
    coalesce(sum(monto) filter (where tipo='ingreso'),0),
    coalesce(sum(monto) filter (where tipo='cambio'),0)
    into v_gastos, v_retiros, v_adelantos, v_ingresos, v_cambio
    from caja_movimientos where sesion_id = p_sesion_id and not anulado;

  return jsonb_build_object(
    'sesion_id', v_s.id,
    'local', v_s.local,
    'estado', v_s.estado,
    'abierta_at', v_s.abierta_at,
    'fondo_inicial', v_s.fondo_inicial,
    'ventas_cant', v_ventas_cant,
    'ventas_total', v_ventas_total,
    'ventas_contado', v_ventas_contado,
    'pagos_cc_efectivo', v_pagos_cc,
    'devoluciones_efectivo', v_devol,
    'reservas_efectivo', v_reservas,
    'gastos', v_gastos,
    'retiros', v_retiros,
    'adelantos', v_adelantos,
    'ingresos', v_ingresos,
    'cambio', v_cambio,
    'efectivo_esperado', v_s.fondo_inicial + v_ventas_contado + v_pagos_cc + v_reservas - v_devol
                         + v_ingresos + v_cambio - v_gastos - v_retiros - v_adelantos
  );
end $function$;
grant execute on function public.estado_caja_sesion(uuid) to authenticated;

-- ---------- Cierre: ahora solo arqueo + observaciones ----------
-- La firma vieja (con gastos/retiros/adelantos/cambio a mano) se elimina:
-- esos importes ahora salen de caja_movimientos.
drop function if exists public.cerrar_caja_sesion(uuid, numeric, numeric, numeric, numeric, numeric, text);

create or replace function public.cerrar_caja_sesion(
  p_sesion_id uuid, p_arqueo numeric, p_observaciones text default null
) returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_usuario text;
  v_local_asignado text;
  v_sesion record;
  v_e jsonb;
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

  v_e := public.estado_caja_sesion(p_sesion_id);
  v_esperado := (v_e->>'efectivo_esperado')::numeric;
  v_usuario := auth.jwt()->>'email';

  update caja_sesiones set
    estado = 'cerrada',
    gastos = (v_e->>'gastos')::numeric,
    retiros = (v_e->>'retiros')::numeric,
    adelantos = (v_e->>'adelantos')::numeric,
    cambio = (v_e->>'cambio')::numeric + (v_e->>'ingresos')::numeric,
    arqueo = p_arqueo,
    efectivo_esperado = v_esperado,
    diferencia = coalesce(p_arqueo,0) - v_esperado,
    observaciones = nullif(trim(coalesce(p_observaciones,'')),''),
    cerrada_por = v_usuario,
    cerrada_at = now()
  where id = p_sesion_id;

  return v_e || jsonb_build_object('arqueo', p_arqueo, 'diferencia', coalesce(p_arqueo,0) - v_esperado);
end $function$;
grant execute on function public.cerrar_caja_sesion(uuid, numeric, text) to authenticated;
