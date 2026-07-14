-- ============================================================
--  Ventas financiadas por el sindicato ASOEM: agrega el desglose de
--  cuotas (mismo esquema que tarjeta de credito: 1 pago, 3 sin interes,
--  6/9/12 con interes = tasaMensual x cuotas) y el numero de
--  autorizacion que envia el sindicato, para poder rastrear estas
--  ventas desde el Dashboard ASOEM (solo gerente) de la app.
--  TODAVIA NO APLICADA EN SUPABASE -- pendiente de confirmacion
--  explicita antes de correrla (mismo criterio que proteger_stock_schema.sql).
-- ============================================================

alter table ventas add column if not exists asoem_cuotas integer not null default 1;
alter table ventas add column if not exists asoem_recargo_pct numeric(6,2) not null default 0;
alter table ventas add column if not exists asoem_autorizacion text;

alter table ventas drop constraint if exists ventas_asoem_cuotas_check;
alter table ventas add constraint ventas_asoem_cuotas_check check (asoem_cuotas in (1,3,6,9,12));

create index if not exists idx_ventas_asoem on ventas(pago_credito_financiero) where pago_credito_financiero > 0;
