-- ============================================================
--  Tabla maestra de precios: "articulos"
--  Fuente de verdad única para la app de vendedores y para el catálogo web.
--  Se importa desde el Excel (LISTA.xlsx). Ejecutar en el MISMO proyecto Supabase
--  del catálogo (grswqigekcopfrozcxqj). Pegar en SQL Editor → Run.
-- ============================================================

create extension if not exists "pgcrypto";

create table if not exists articulos (
  id           uuid primary key default gen_random_uuid(),
  codigo       text unique not null,          -- código del Excel (clave del artículo)
  nombre       text not null,
  categoria    text,
  precio_lista numeric(12,2) not null,
  talles       jsonb not null default '[]'::jsonb,  -- [{ "talle": "...", "precio": 0 }]
  updated_at   timestamptz not null default now()
);

create index if not exists idx_articulos_categoria on articulos(categoria);

-- Mantener updated_at
create or replace function set_articulos_updated_at() returns trigger as $$
begin new.updated_at = now(); return new; end;
$$ language plpgsql;
drop trigger if exists trg_articulos_updated on articulos;
create trigger trg_articulos_updated
  before update on articulos
  for each row execute function set_articulos_updated_at();

-- Seguridad: lectura pública (la app de vendedores la consulta con la anon key,
-- igual que hoy el productos.json es público); escritura solo para admins.
alter table articulos enable row level security;

drop policy if exists "public read articulos" on articulos;
create policy "public read articulos" on articulos for select using (true);

drop policy if exists "admin write articulos" on articulos;
create policy "admin write articulos" on articulos
  for all using (public.is_admin()) with check (public.is_admin());
