-- Respaldo de quien mando la transferencia, verificado contra Mercado Pago al
-- momento de cobrar (y cruzado con el padron A5 de AFIP cuando MP informa el
-- CUIT). Ya aplicado en el proyecto camerino-giustozzi.
--
-- Ojo: MP solo identifica al ordenante cuando la transferencia viene de otra
-- cuenta de Mercado Pago (sub_type INTRA_PSP). Si la transferencia entra desde
-- un banco (INTER_PSP / account_fund), el bloque "payer" que devuelve la API
-- trae los datos de la cuenta que recibe, no del emisor -- en ese caso estas
-- columnas quedan en null salvo el id del pago y la hora de acreditacion.

alter table ventas add column if not exists transferencia_pago_id text;
alter table ventas add column if not exists transferencia_pagador text;
alter table ventas add column if not exists transferencia_pagador_cuit text;
alter table ventas add column if not exists transferencia_verificada_at timestamptz;

comment on column ventas.transferencia_pago_id is 'id del pago en Mercado Pago que se verifico para esta venta';
comment on column ventas.transferencia_pagador is 'nombre/razon social o email de quien transfirio, segun MP + padron AFIP';
comment on column ventas.transferencia_pagador_cuit is 'CUIT/CUIL del ordenante, cuando MP lo informa';
comment on column ventas.transferencia_verificada_at is 'fecha y hora de la acreditacion en Mercado Pago';
