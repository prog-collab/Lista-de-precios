-- ============================================================
--  Costo por producto (un valor por articulo, no por talle), para poder
--  calcular margen. Arranca vacio para todo el catalogo existente — se va
--  completando de a poco desde el formulario de editar producto.
--  Ya aplicada en Supabase — este archivo queda como referencia/backup.
-- ============================================================

alter table articulos add column if not exists costo numeric(12,2);
