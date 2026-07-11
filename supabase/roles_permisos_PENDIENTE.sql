-- ============================================================
--  PENDIENTE DE APLICAR — necesita tu confirmación explícita.
--  El clasificador de seguridad frenó esto durante el trabajo autónomo
--  overnight porque cambia permisos/RLS en la base de producción, y
--  eso requiere que lo pidas puntualmente (no alcanza con una
--  autorización genérica). Revisalo y pedime que lo aplique cuando
--  estés de acuerdo.
--
--  Qué hace:
--  1. Agrega el campo "rol" a admins ('vendedor' por defecto, 'gerente'
--     para vos — jsgiusto@gmail.com).
--  2. Restringe la LECTURA de "facturas" y "ventas" (reportes completos)
--     a rol='gerente' únicamente. La creación (INSERT) de facturas/ventas
--     sigue abierta a cualquier admin (vendedor), porque la app de
--     vendedores necesita poder registrar ventas y facturas normalmente
--     — la app de vendedores nunca hace SELECT sobre estas tablas hoy,
--     así que esto no debería romper nada ahí.
--
--  Efecto práctico: un vendedor puede seguir vendiendo/cargando stock/
--  facturando desde la app, pero NO va a poder abrir /admin/facturacion,
--  /admin/dashboard ni /admin/caja para ver los números completos del
--  negocio (esas pantallas quedan solo para vos). Si un vendedor entra
--  a esas URLs igual va a poder loguearse, pero las consultas le van a
--  devolver 0 filas (RLS lo bloquea del lado de la base, no solo la UI).
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

drop policy if exists "gerente select facturas" on facturas;
drop policy if exists "admin insert facturas" on facturas;
drop policy if exists "gerente update facturas" on facturas;
drop policy if exists "gerente delete facturas" on facturas;
drop policy if exists "admin all facturas" on facturas;
create policy "gerente select facturas" on facturas for select using (public.is_gerente());
create policy "admin insert facturas" on facturas for insert with check (public.is_admin());
create policy "gerente update facturas" on facturas for update using (public.is_gerente()) with check (public.is_gerente());
create policy "gerente delete facturas" on facturas for delete using (public.is_gerente());

drop policy if exists "gerente select ventas" on ventas;
drop policy if exists "admin insert ventas" on ventas;
drop policy if exists "admin update ventas" on ventas;
drop policy if exists "gerente delete ventas" on ventas;
drop policy if exists "admin all ventas" on ventas;
create policy "gerente select ventas" on ventas for select using (public.is_gerente());
create policy "admin insert ventas" on ventas for insert with check (public.is_admin());
create policy "admin update ventas" on ventas for update using (public.is_admin()) with check (public.is_admin());
create policy "gerente delete ventas" on ventas for delete using (public.is_gerente());
