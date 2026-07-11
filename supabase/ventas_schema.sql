-- ============================================================
--  Tabla "ventas": reemplaza la planilla de papel de cierre de venta.
--  Cada venta (uno o mas items escaneados en Modo Venta) queda registrada
--  con el desglose de medios de pago, saldo pendiente, y si se facturo.
--  Ya aplicada en Supabase — este archivo queda como referencia/backup.
-- ============================================================

create extension if not exists "pgcrypto";

create table if not exists ventas (
  id                       uuid primary key default gen_random_uuid(),
  local                    text not null,             -- 'camerino' | 'giustozzi'
  vendedor                 text,                      -- email de quien vendio (sbSession)
  fecha                    date not null default current_date,
  items                    jsonb not null default '[]'::jsonb,  -- [{codigo,nombre,talle,color,precio}]
  total                    numeric(12,2) not null,
  pago_contado             numeric(12,2) not null default 0,
  pago_tarjeta_credito     numeric(12,2) not null default 0,
  pago_tarjeta_debito      numeric(12,2) not null default 0,
  pago_credito_personal    numeric(12,2) not null default 0,
  pago_credito_financiero  numeric(12,2) not null default 0,
  saldo_pendiente          numeric(12,2) not null default 0,
  facturada                boolean not null default false,
  factura_tipo             text,             -- 'A' | 'B', si se facturo
  factura_pto_vta          integer,
  factura_numero           integer,
  factura_cae              text,
  created_at               timestamptz not null default now()
);

create index if not exists idx_ventas_fecha on ventas(fecha desc);
create index if not exists idx_ventas_local on ventas(local);

alter table ventas enable row level security;

drop policy if exists "admin all ventas" on ventas;
create policy "admin all ventas" on ventas
  for all using (public.is_admin()) with check (public.is_admin());
