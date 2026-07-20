-- ============================================================
--  Observación libre y opcional sobre una venta puntual (ej. "cliente pide
--  cambio de talle la semana que viene"), cargada en un pequeño campo junto
--  a "Saldo pendiente" en Vender (POS). Ya aplicada en Supabase — este
--  archivo queda como referencia/backup.
-- ============================================================

alter table ventas add column if not exists nota text;
