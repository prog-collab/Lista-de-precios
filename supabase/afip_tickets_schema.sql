-- ============================================================
--  Tabla "afip_tickets": cachea el Ticket de Acceso (TA) de WSAA
--  entre invocaciones de la función serverless (que no comparten
--  disco entre sí). Sin esto, AFIP rechaza pedir un TA nuevo mientras
--  el anterior siga vigente ("coe.alreadyAuthenticated").
--  Ya aplicada en Supabase — este archivo queda como referencia/backup.
-- ============================================================

create extension if not exists "pgcrypto";

create table if not exists afip_tickets (
  id         uuid primary key default gen_random_uuid(),
  cuit       text not null,
  servicio   text not null,          -- 'wsfe', 'ws_sr_padron_a5', etc.
  ambiente   text not null,          -- 'homologacion' | 'produccion'
  ticket     jsonb not null,         -- { header, credentials } tal cual lo devuelve la librería
  expira     timestamptz not null,
  updated_at timestamptz not null default now()
);

create unique index if not exists idx_afip_tickets_clave
  on afip_tickets(cuit, servicio, ambiente);

alter table afip_tickets enable row level security;

drop policy if exists "admin all afip_tickets" on afip_tickets;
create policy "admin all afip_tickets" on afip_tickets
  for all using (public.is_admin()) with check (public.is_admin());
