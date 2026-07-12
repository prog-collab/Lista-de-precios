-- ============================================================
--  DNI del cliente: campo adicional, nullable, sin cambio de RLS (clientes
--  ya tiene una política is_admin() blanket desde antes). Se puede cargar
--  desde el formulario de nuevo/editar cliente, y se usa para buscar
--  clientes (junto con nombre y teléfono) en el POS y en la pantalla de
--  Clientes.
--  Ya aplicada en Supabase — este archivo queda como referencia/backup.
-- ============================================================

alter table clientes add column if not exists dni text;
