-- ============================================================
--  Foto principal por artículo (se ve en la app de precios y en la web).
--  Ejecutar en el mismo proyecto Supabase (SQL Editor → Run).
-- ============================================================

alter table articulos add column if not exists foto_url text;
