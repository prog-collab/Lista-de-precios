-- ============================================================
--  Tabla "facturas": registro propio de cada comprobante emitido
--  vía /api/facturar (AFIP es la fuente de verdad legal; esto es
--  una copia para listar/filtrar/reimprimir desde el panel admin).
--  Ya aplicada en Supabase — este archivo queda como referencia/backup.
-- ============================================================

create extension if not exists "pgcrypto";

create table if not exists facturas (
  id              uuid primary key default gen_random_uuid(),
  local           text not null,             -- 'camerino' | 'giustozzi'
  tipo            text not null,             -- 'A' | 'B'
  pto_vta         integer not null,
  numero          integer not null,
  cuit_emisor     text not null,
  cliente_cuit    text,                      -- null si es Factura B
  monto           numeric(12,2) not null,
  fecha           date not null,             -- fecha del comprobante (AAAA-MM-DD)
  cae             text not null,
  cae_vencimiento date,
  ambiente        text not null,             -- 'homologacion' | 'produccion'
  created_at      timestamptz not null default now()
);

create unique index if not exists idx_facturas_comprobante
  on facturas(cuit_emisor, pto_vta, tipo, numero, ambiente);
create index if not exists idx_facturas_fecha on facturas(fecha desc);
create index if not exists idx_facturas_local on facturas(local);

alter table facturas enable row level security;

drop policy if exists "admin all facturas" on facturas;
create policy "admin all facturas" on facturas
  for all using (public.is_admin()) with check (public.is_admin());
