-- Redondeo del pago en efectivo (en más o en menos) en el POS.
--
-- Al cobrar en efectivo, el vendedor puede redondear el importe hacia arriba o
-- hacia abajo (típico cuando no hay cambio). El monto del redondeo se guarda
-- en su propia columna, y YA viene incluido tanto en pago_contado como en total,
-- así el arqueo de caja cuadra solo sin cálculos extra.
--
-- Positivo = redondeo en más (el cliente paga de más).
-- Negativo = redondeo en menos (el cliente paga de menos).

ALTER TABLE public.ventas
  ADD COLUMN IF NOT EXISTS redondeo_contado numeric NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.ventas.redondeo_contado IS
  'Redondeo del efectivo (en mas positivo / en menos negativo). Ya incluido en pago_contado y en total.';
