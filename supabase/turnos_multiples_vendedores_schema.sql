-- Permitir 2 o más vendedores por turno (mañana/tarde) en un mismo día/local.
--
-- El frontend siempre trató cada vendedor como una fila propia en `turnos`
-- (una fila = local + fecha + turno + vendedor_id). Si al cargar el 2º vendedor
-- daba "No se pudo actualizar", era porque la tabla tenía una restricción UNIQUE
-- sobre (local, fecha, turno) que impedía más de una fila por turno.
--
-- Esta migración:
--   1) elimina cualquier UNIQUE viejo que ignore vendedor_id, y
--   2) deja una UNIQUE correcta que sí lo incluye (evita cargar dos veces al
--      MISMO vendedor en el mismo turno, pero permite varios vendedores distintos).
-- Es idempotente: se puede correr varias veces sin romper nada.

DO $$
DECLARE r record;
BEGIN
  -- 1) Borrar toda UNIQUE constraint sobre turnos que NO involucre vendedor_id.
  FOR r IN
    SELECT con.conname
    FROM pg_constraint con
    JOIN pg_class rel ON rel.oid = con.conrelid
    JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
    WHERE rel.relname = 'turnos'
      AND nsp.nspname = 'public'
      AND con.contype = 'u'
      AND NOT EXISTS (
        SELECT 1
        FROM unnest(con.conkey) AS k(attnum)
        JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = k.attnum
        WHERE a.attname = 'vendedor_id'
      )
  LOOP
    EXECUTE format('ALTER TABLE public.turnos DROP CONSTRAINT %I', r.conname);
  END LOOP;

  -- 2) Crear la UNIQUE correcta (local, fecha, turno, vendedor_id) si falta.
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint con
    JOIN pg_class rel ON rel.oid = con.conrelid
    WHERE rel.relname = 'turnos' AND con.conname = 'turnos_local_fecha_turno_vendedor_key'
  ) THEN
    ALTER TABLE public.turnos
      ADD CONSTRAINT turnos_local_fecha_turno_vendedor_key
      UNIQUE (local, fecha, turno, vendedor_id);
  END IF;
END $$;
