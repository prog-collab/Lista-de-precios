-- ============================================================
--  Sesión de caja real: hay que abrirla (con un fondo inicial) antes de
--  poder guardar una venta en ese local, y se cierra con arqueo/gastos/
--  retiros/adelantos/cambio, calculando el efectivo esperado y la
--  diferencia contra el arqueo real. No se puede tener 2 cajas abiertas
--  a la vez en el mismo local (índice único parcial). Cada usuario abre
--  y cierra la caja de su propio local (mismo criterio de local_asignado
--  ya usado en el resto del sistema); el gerente no tiene restricción.
--  Confirmado explícitamente por el usuario el 2026-07-11 antes de aplicar
--  (clasificador de seguridad lo pidió por cambiar la politica de insert
--  de "ventas" para exigir una caja abierta).
--  Ya aplicada en Supabase — este archivo queda como referencia/backup.
--
--  NOTA: la tabla vieja "cierres_caja" y la pantalla /admin/caja del panel
--  Next.js (gerente-only) siguen existiendo tal cual, sin tocar — son un
--  formulario de recapitulación de fin de día manual, independiente de
--  esta sesión de caja real. Quedan dos sistemas de cierre de caja
--  coexistiendo; si en algún momento se quiere unificarlos, ese panel
--  debería pasar a leer de caja_sesiones en vez de cierres_caja.
-- ============================================================

create table if not exists caja_sesiones (
  id uuid primary key default gen_random_uuid(),
  local text not null check (local in ('camerino','giustozzi')),
  fecha date not null default current_date,
  estado text not null default 'abierta' check (estado in ('abierta','cerrada')),
  fondo_inicial numeric(12,2) not null default 0,
  abierta_por text,
  abierta_at timestamptz not null default now(),
  gastos numeric(12,2) not null default 0,
  retiros numeric(12,2) not null default 0,
  adelantos numeric(12,2) not null default 0,
  cambio numeric(12,2) not null default 0,
  arqueo numeric(12,2),
  efectivo_esperado numeric(12,2),
  diferencia numeric(12,2),
  observaciones text,
  cerrada_por text,
  cerrada_at timestamptz
);
create unique index if not exists idx_caja_sesion_abierta_unica on caja_sesiones(local) where estado='abierta';
create index if not exists idx_caja_sesiones_fecha on caja_sesiones(fecha desc);

alter table caja_sesiones enable row level security;
drop policy if exists "admin all caja_sesiones" on caja_sesiones;
create policy "admin all caja_sesiones" on caja_sesiones for all using (public.is_admin()) with check (public.is_admin());

alter table ventas add column if not exists caja_sesion_id uuid references caja_sesiones(id);

create or replace function public.abrir_caja_sesion(p_local text, p_fondo_inicial numeric)
returns uuid
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_usuario text;
  v_local_asignado text;
  v_existente uuid;
  v_id uuid;
begin
  if not public.is_admin() then
    raise exception 'Necesitás una sesión válida para abrir la caja.';
  end if;
  if p_local not in ('camerino','giustozzi') then
    raise exception 'Local inválido.';
  end if;
  v_local_asignado := public.mi_local_asignado();
  if v_local_asignado is not null and v_local_asignado <> p_local then
    raise exception 'Tu usuario solo puede abrir la caja de %', v_local_asignado;
  end if;

  select id into v_existente from caja_sesiones where local = p_local and estado = 'abierta';
  if v_existente is not null then
    raise exception 'Ya hay una caja abierta en % — cerrala antes de abrir una nueva.', p_local;
  end if;

  v_usuario := auth.jwt()->>'email';
  insert into caja_sesiones (local, fondo_inicial, abierta_por)
  values (p_local, coalesce(p_fondo_inicial,0), v_usuario)
  returning id into v_id;
  return v_id;
end $function$;
grant execute on function public.abrir_caja_sesion(text, numeric) to authenticated;

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
  v_esperado := v_sesion.fondo_inicial + v_ventas_contado + coalesce(p_cambio,0) - coalesce(p_gastos,0) - coalesce(p_retiros,0) - coalesce(p_adelantos,0);
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
grant execute on function public.cerrar_caja_sesion(uuid, numeric, numeric, numeric, numeric, numeric, text) to authenticated;

-- A partir de ahora, guardar una venta exige que haya una caja abierta para
-- ese local (mismo criterio de local_asignado que ya se usaba).
drop policy if exists "admin insert ventas" on ventas;
create policy "admin insert ventas" on ventas for insert
  with check (
    public.is_admin()
    and (public.mi_local_asignado() is null or local = public.mi_local_asignado())
    and caja_sesion_id is not null
    and exists (
      select 1 from caja_sesiones cs
      where cs.id = ventas.caja_sesion_id and cs.local = ventas.local and cs.estado = 'abierta'
    )
  );
