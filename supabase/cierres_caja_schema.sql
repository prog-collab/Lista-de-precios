-- ============================================================
--  Tabla "cierres_caja": reemplaza el resto de la planilla de papel
--  (la parte de arqueo/cierre diario que no cubrimos con "ventas").
--  Ya aplicada en Supabase — este archivo queda como referencia/backup.
-- ============================================================

create table if not exists cierres_caja (
  id             uuid primary key default gen_random_uuid(),
  local          text not null,
  fecha          date not null,
  caja_chica     numeric(12,2) not null default 0,
  cambio         numeric(12,2) not null default 0,
  gastos         numeric(12,2) not null default 0,
  retiros        numeric(12,2) not null default 0,
  adelantos      numeric(12,2) not null default 0,
  arqueo         numeric(12,2) not null default 0,   -- efectivo contado a mano al cerrar
  observaciones  text,
  cerrado_por    text,
  created_at     timestamptz not null default now(),
  unique(local, fecha)
);

create index if not exists idx_cierres_caja_fecha on cierres_caja(fecha desc);

alter table cierres_caja enable row level security;
drop policy if exists "admin all cierres_caja" on cierres_caja;
create policy "admin all cierres_caja" on cierres_caja
  for all using (public.is_admin()) with check (public.is_admin());
