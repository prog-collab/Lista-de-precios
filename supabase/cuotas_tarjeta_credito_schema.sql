-- ============================================================
--  Cuotas con interés (6/9/12) para el pago con tarjeta de crédito
--  en Vender. Reutiliza la misma tasa mensual y cantidad de cuotas
--  ya configuradas para el carrito de la lista de precios
--  (tasaMensual / CUOTAS_INT / cuotaDirecta en index.html), para
--  que el recargo que ve el cliente sea el mismo en los dos lugares.
--  El recargo elegido se suma al total de la venta (y a la factura,
--  si corresponde) — no afecta a los demás medios de pago.
--  Ya aplicada en Supabase — este archivo queda como referencia/backup.
-- ============================================================

alter table ventas add column if not exists tarjeta_credito_cuotas integer not null default 1;
alter table ventas add column if not exists tarjeta_credito_recargo_pct numeric(6,2) not null default 0;

-- gerente_editar_venta_pago gana 2 parametros nuevos (con default, para no
-- romper llamadas viejas): p_tarjeta_credito_cuotas, p_tarjeta_credito_recargo_pct.
drop function if exists public.gerente_editar_venta_pago(uuid, numeric, numeric, numeric, text, numeric, numeric, numeric, numeric);

create or replace function public.gerente_editar_venta_pago(
  p_venta_id uuid,
  p_total numeric,
  p_pago_contado numeric,
  p_pago_transferencia numeric,
  p_transferencia_alias text,
  p_pago_tarjeta_credito numeric,
  p_pago_tarjeta_debito numeric,
  p_pago_credito_personal numeric,
  p_pago_credito_financiero numeric,
  p_tarjeta_credito_cuotas integer default 1,
  p_tarjeta_credito_recargo_pct numeric default 0
) returns void
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_facturada boolean;
  v_saldo numeric;
begin
  if not public.is_gerente() then
    raise exception 'Solo un gerente puede editar una venta.';
  end if;
  select facturada into v_facturada from ventas where id = p_venta_id for update;
  if not found then
    raise exception 'Venta no encontrada.';
  end if;
  if v_facturada then
    raise exception 'No se puede editar una venta ya facturada.';
  end if;
  v_saldo := greatest(0, p_total - (
    coalesce(p_pago_contado,0) + coalesce(p_pago_transferencia,0) + coalesce(p_pago_tarjeta_credito,0)
    + coalesce(p_pago_tarjeta_debito,0) + coalesce(p_pago_credito_personal,0) + coalesce(p_pago_credito_financiero,0)
  ));
  update ventas set
    total = p_total,
    pago_contado = coalesce(p_pago_contado,0),
    pago_transferencia = coalesce(p_pago_transferencia,0),
    transferencia_alias = p_transferencia_alias,
    pago_tarjeta_credito = coalesce(p_pago_tarjeta_credito,0),
    pago_tarjeta_debito = coalesce(p_pago_tarjeta_debito,0),
    pago_credito_personal = coalesce(p_pago_credito_personal,0),
    pago_credito_financiero = coalesce(p_pago_credito_financiero,0),
    tarjeta_credito_cuotas = coalesce(p_tarjeta_credito_cuotas,1),
    tarjeta_credito_recargo_pct = coalesce(p_tarjeta_credito_recargo_pct,0),
    saldo_pendiente = v_saldo
  where id = p_venta_id;
end $function$;

grant execute on function public.gerente_editar_venta_pago(uuid, numeric, numeric, numeric, text, numeric, numeric, numeric, numeric, integer, numeric) to authenticated;
