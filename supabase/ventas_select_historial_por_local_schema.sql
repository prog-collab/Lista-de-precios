-- ============================================================
--  Amplía la política SELECT de "ventas": antes un vendedor (no gerente)
--  solo podía ver las ventas de HOY, sin importar el local — lo que hacía
--  que el buscador por fecha y el buscador por producto de Devoluciones
--  nunca encontraran nada de días anteriores para esas cuentas. Ahora
--  también puede ver el historial completo de SU PROPIO local (mismo
--  criterio que ya se usa en traspasos/caja/devoluciones), pero sigue sin
--  poder ver el historial de ventas del otro local.
--  Confirmado explícitamente por el usuario el 2026-07-12 antes de aplicar
--  (clasificador de seguridad lo pidió por tocar RLS de "ventas").
--  Ya aplicada en Supabase — este archivo queda como referencia/backup.
-- ============================================================

drop policy if exists "select ventas" on ventas;
create policy "select ventas" on ventas for select
  using (
    is_gerente()
    or fecha = current_date
    or (mi_local_asignado() is not null and local = mi_local_asignado())
  );
