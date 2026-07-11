-- ============================================================
--  Un gerente puede editar (medios de pago + total) o borrar una
--  venta no facturada. Al borrar, se repone automáticamente el
--  stock de cada producto vendido (queda en el historial con
--  motivo 'anulacion'). Bloqueado en ambos casos si la venta ya
--  tiene CAE real de AFIP (facturada = true) — para eso existe
--  (sin probar aún) el flujo de Nota de Crédito.
--  Ya aplicada en Supabase (confirmado explícitamente por el
--  usuario el 2026-07-11) — este archivo queda como referencia/backup.
-- ============================================================

-- UPDATE/DELETE en "ventas" pasan a ser de gerente en general, con una
-- excepción acotada: un vendedor puede seguir tocando SU PROPIA venta de
-- HOY mientras no esté facturada (necesario para enlazar los datos de la
-- factura justo después de emitirla, y para borrar su propio registro
-- huérfano si el descuento de stock llegó a fallar al guardar).
drop policy if exists "admin update ventas" on ventas;
drop policy if exists "gerente delete ventas" on ventas;

create policy "gerente update ventas" on ventas
  for update using (public.is_gerente()) with check (public.is_gerente());

create policy "gerente delete ventas" on ventas
  for delete using (public.is_gerente());

create policy "vendedor propia venta hoy sin facturar update" on ventas
  for update
  using (vendedor = (auth.jwt()->>'email') and facturada = false and fecha = current_date)
  with check (vendedor = (auth.jwt()->>'email') and fecha = current_date);

create policy "vendedor propia venta hoy sin facturar delete" on ventas
  for delete
  using (vendedor = (auth.jwt()->>'email') and facturada = false and fecha = current_date);

create or replace function public.gerente_editar_venta_pago(
  p_venta_id uuid,
  p_total numeric,
  p_pago_contado numeric,
  p_pago_transferencia numeric,
  p_transferencia_alias text,
  p_pago_tarjeta_credito numeric,
  p_pago_tarjeta_debito numeric,
  p_pago_credito_personal numeric,
  p_pago_credito_financiero numeric
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
    saldo_pendiente = v_saldo
  where id = p_venta_id;
end $function$;

grant execute on function public.gerente_editar_venta_pago(uuid, numeric, numeric, numeric, text, numeric, numeric, numeric, numeric) to authenticated;

create or replace function public.gerente_borrar_venta(p_venta_id uuid)
returns void
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_facturada boolean;
  v_local text;
  v_items jsonb;
  it jsonb;
  v_usuario text;
begin
  if not public.is_gerente() then
    raise exception 'Solo un gerente puede borrar una venta.';
  end if;
  select facturada, local, items into v_facturada, v_local, v_items from ventas where id = p_venta_id for update;
  if not found then
    raise exception 'Venta no encontrada.';
  end if;
  if v_facturada then
    raise exception 'No se puede borrar una venta ya facturada. Emití una Nota de Crédito primero.';
  end if;

  v_usuario := auth.jwt()->>'email';
  for it in select * from jsonb_array_elements(coalesce(v_items,'[]'::jsonb)) loop
    perform public._ajustar_stock_uno(
      it->>'codigo', it->>'talle', it->>'color', v_local, 1, 'anulacion', v_usuario, p_venta_id
    );
  end loop;

  delete from ventas where id = p_venta_id;
end $function$;

grant execute on function public.gerente_borrar_venta(uuid) to authenticated;
