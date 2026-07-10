-- ============================================================
--  Tabla "clientes": nombre + teléfono (+ CUIT cuando se conoce).
--  Se usa para autocompletar el CUIT al facturar y para mandar el
--  ticket por WhatsApp directo a la persona. Pegar en SQL Editor → Run,
--  en el MISMO proyecto Supabase del catálogo (grswqigekcopfrozcxqj).
-- ============================================================

create extension if not exists "pgcrypto";

create table if not exists clientes (
  id         uuid primary key default gen_random_uuid(),
  cuit       text,                 -- puede ser null (contacto sin factura A todavía)
  nombre     text,
  telefono   text,
  updated_at timestamptz not null default now()
);

-- CUIT único SOLO cuando está cargado (permite muchos contactos sin CUIT).
create unique index if not exists idx_clientes_cuit on clientes(cuit) where cuit is not null;
create index if not exists idx_clientes_nombre on clientes (lower(nombre));
create index if not exists idx_clientes_telefono on clientes (telefono);

create or replace function set_clientes_updated_at() returns trigger as $$
begin new.updated_at = now(); return new; end;
$$ language plpgsql;
drop trigger if exists trg_clientes_updated on clientes;
create trigger trg_clientes_updated
  before update on clientes
  for each row execute function set_clientes_updated_at();

-- Seguridad: tiene teléfonos (datos personales) — solo admins leen y escriben,
-- igual criterio que ajustar_stock/barcode_maps (RLS is_admin()).
alter table clientes enable row level security;

drop policy if exists "admin all clientes" on clientes;
create policy "admin all clientes" on clientes
  for all using (public.is_admin()) with check (public.is_admin());
