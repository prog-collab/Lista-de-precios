-- ============================================================
--  Cuenta corriente de clientes: el "crédito personal" del POS deja de ser
--  un número suelto y pasa a estar atado a un cliente concreto, con un
--  ledger inmutable de cargos (ventas fiadas) y pagos (cobros posteriores).
--  Mismo patrón que stock_movimientos: nunca se edita un movimiento, solo
--  se agregan nuevos (una corrección se hace con otro movimiento, o
--  borrando — solo el gerente puede borrar — si fue un error de carga).
--  Ya aplicada en Supabase — este archivo queda como referencia/backup.
-- ============================================================

create table if not exists cuenta_corriente_movimientos (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid not null references clientes(id) on delete restrict,
  tipo text not null check (tipo in ('cargo','pago')),
  monto numeric(12,2) not null check (monto > 0),
  local text,
  referencia_venta_id uuid references ventas(id),
  usuario text,
  nota text,
  created_at timestamptz not null default now()
);
create index if not exists idx_cc_mov_cliente on cuenta_corriente_movimientos(cliente_id);
create index if not exists idx_cc_mov_fecha on cuenta_corriente_movimientos(created_at desc);

alter table cuenta_corriente_movimientos enable row level security;
drop policy if exists "admin select cc_movimientos" on cuenta_corriente_movimientos;
drop policy if exists "admin insert cc_movimientos" on cuenta_corriente_movimientos;
drop policy if exists "gerente delete cc_movimientos" on cuenta_corriente_movimientos;
create policy "admin select cc_movimientos" on cuenta_corriente_movimientos for select using (public.is_admin());
create policy "admin insert cc_movimientos" on cuenta_corriente_movimientos for insert with check (public.is_admin());
create policy "gerente delete cc_movimientos" on cuenta_corriente_movimientos for delete using (public.is_gerente());

-- La vista ya incluye nombre/teléfono del cliente (join adentro) porque
-- PostgREST no puede hacer "embed" de una tabla sobre una vista sin FK real.
drop view if exists v_cuenta_corriente_saldo;
create view v_cuenta_corriente_saldo
with (security_invoker = true) as
select m.cliente_id,
  c.nombre, c.telefono,
  sum(case when m.tipo='cargo' then m.monto else -m.monto end) as saldo,
  max(m.created_at) as ultimo_movimiento
from cuenta_corriente_movimientos m
join clientes c on c.id = m.cliente_id
group by m.cliente_id, c.nombre, c.telefono;

-- ventas gana un cliente_id opcional (se completa cuando hay credito
-- personal), para poder mostrar el nombre del cliente en "Ventas de hoy"
-- sin tener que cruzar con cuenta_corriente_movimientos.
alter table ventas add column if not exists cliente_id uuid references clientes(id);
