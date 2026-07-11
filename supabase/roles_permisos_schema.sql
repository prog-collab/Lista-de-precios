-- ============================================================
--  Roles: "vendedor" (por defecto) o "gerente". Un vendedor puede
--  vender/cargar stock/facturar desde la app normalmente; solo un
--  gerente puede leer (SELECT) las tablas "facturas" y "ventas" —
--  usadas en /admin/facturacion, /admin/dashboard y /admin/caja.
--  Ya aplicada en Supabase (confirmado explícitamente por el usuario
--  el 2026-07-11) — este archivo queda como referencia/backup.
-- ============================================================

alter table admins add column if not exists rol text not null default 'vendedor';
alter table admins drop constraint if exists admins_rol_check;
alter table admins add constraint admins_rol_check check (rol in ('vendedor','gerente'));
update admins set rol = 'gerente' where email = 'jsgiusto@gmail.com';

create or replace function public.is_gerente()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select exists(select 1 from admins where user_id = auth.uid() and rol = 'gerente');
$$;
grant execute on function public.is_gerente() to authenticated, anon, public;

drop policy if exists "admin all facturas" on facturas;
drop policy if exists "gerente select facturas" on facturas;
drop policy if exists "admin insert facturas" on facturas;
drop policy if exists "gerente update facturas" on facturas;
drop policy if exists "gerente delete facturas" on facturas;
create policy "gerente select facturas" on facturas for select using (public.is_gerente());
create policy "admin insert facturas" on facturas for insert with check (public.is_admin());
create policy "gerente update facturas" on facturas for update using (public.is_gerente()) with check (public.is_gerente());
create policy "gerente delete facturas" on facturas for delete using (public.is_gerente());

drop policy if exists "admin all ventas" on ventas;
drop policy if exists "gerente select ventas" on ventas;
drop policy if exists "admin insert ventas" on ventas;
drop policy if exists "admin update ventas" on ventas;
drop policy if exists "gerente delete ventas" on ventas;
-- Cualquier admin (vendedor o gerente) puede leer las ventas de HOY (para el
-- resumen diario en la app de vendedores); el historial completo, solo gerente.
-- Confirmado explícitamente por el usuario el 2026-07-11.
create policy "select ventas" on ventas for select using (public.is_gerente() or fecha = current_date);
create policy "admin insert ventas" on ventas for insert with check (public.is_admin());
create policy "admin update ventas" on ventas for update using (public.is_admin()) with check (public.is_admin());
create policy "gerente delete ventas" on ventas for delete using (public.is_gerente());
