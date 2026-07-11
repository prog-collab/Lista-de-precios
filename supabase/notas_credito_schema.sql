-- ============================================================
--  Tabla "notas_credito": registro propio de cada Nota de Crédito
--  emitida contra una factura anterior (devoluciones/anulaciones).
--  Ya aplicada en Supabase — este archivo queda como referencia/backup.
-- ============================================================

create table if not exists notas_credito (
  id               uuid primary key default gen_random_uuid(),
  factura_id       uuid references facturas(id),
  local            text not null,
  tipo             text not null,             -- 'A' | 'B' (mismo tipo que la factura original)
  pto_vta          integer not null,
  numero           integer not null,
  cuit_emisor      text not null,
  cliente_cuit     text,
  monto            numeric(12,2) not null,
  fecha            date not null,
  cae              text not null,
  cae_vencimiento  date,
  ambiente         text not null,
  motivo           text,
  items            jsonb not null default '[]'::jsonb,
  restituyo_stock  boolean not null default false,
  created_at       timestamptz not null default now()
);

create index if not exists idx_notas_credito_factura on notas_credito(factura_id);
create index if not exists idx_notas_credito_fecha on notas_credito(fecha desc);

alter table notas_credito enable row level security;
drop policy if exists "admin all notas_credito" on notas_credito;
create policy "admin all notas_credito" on notas_credito
  for all using (public.is_admin()) with check (public.is_admin());
