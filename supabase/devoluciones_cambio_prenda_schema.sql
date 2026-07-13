-- ============================================================
--  Devoluciones — "cambio con diferencia": permite devolver mercadería
--  aunque la venta original ya esté facturada (no se emite Nota de
--  Crédito, se registra igual) y, si el cliente se lleva otra prenda a
--  cambio, calcula la diferencia de precio:
--    · diferencia > 0 (la prenda nueva es más cara): no se cobra acá.
--      El frontend abre la ventana de Vender con esa diferencia cargada
--      en el carrito (leyenda "Diferencia por cambio") para cobrarla
--      como una venta nueva, vinculada via ventas.devolucion_id.
--    · diferencia < 0 (la prenda nueva es más barata, o no hay prenda
--      nueva — devolución simple): se reintegra como antes, en efectivo
--      o transferencia (misma lógica de caja abierta de siempre).
--    · diferencia = 0: cambio sin movimiento de dinero.
--  Reemplaza registrar_devolucion (firma nueva: agrega p_items_nuevos,
--  p_medio_devolucion pasa a ser opcional) y elimina el bloqueo por
--  venta facturada.
--  Confirmado explícitamente por el usuario el 2026-07-12 (respondió
--  preguntas sobre diferencia negativa, alcance del bypass de factura y
--  trazabilidad) antes de aplicar — clasificador de seguridad lo pide
--  por tocar stock + caja + facturación.
-- ============================================================

alter table devoluciones
  add column if not exists items_nuevos jsonb not null default '[]'::jsonb,
  add column if not exists diferencia numeric(12,2) not null default 0;
alter table devoluciones alter column medio_devolucion drop not null;

alter table ventas
  add column if not exists devolucion_id uuid references devoluciones(id);

drop function if exists public.registrar_devolucion(uuid, jsonb, text, text);

create or replace function public.registrar_devolucion(
  p_venta_id uuid, p_items jsonb, p_medio_devolucion text default null, p_motivo text default null,
  p_items_nuevos jsonb default '[]'::jsonb
) returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_usuario text;
  v_local_asignado text;
  v_venta record;
  v_monto_devuelto numeric := 0;
  v_monto_nuevo numeric := 0;
  v_diferencia numeric := 0;
  it jsonb;
  v_caja_sesion_id uuid;
  v_id uuid := gen_random_uuid();
begin
  if not public.is_admin() then
    raise exception 'Necesitás una sesión válida para registrar una devolución.';
  end if;
  if p_medio_devolucion is not null and p_medio_devolucion not in ('efectivo','transferencia') then
    raise exception 'Medio de devolución inválido.';
  end if;

  select * into v_venta from ventas where id = p_venta_id;
  if not found then raise exception 'Venta no encontrada.'; end if;

  v_local_asignado := public.mi_local_asignado();
  if v_local_asignado is not null and v_local_asignado <> v_venta.local then
    raise exception 'Tu usuario solo puede procesar devoluciones en %', v_local_asignado;
  end if;

  if jsonb_array_length(coalesce(p_items,'[]'::jsonb)) = 0 then
    raise exception 'Elegí al menos un producto para devolver.';
  end if;

  v_usuario := auth.jwt()->>'email';

  for it in select * from jsonb_array_elements(p_items) loop
    v_monto_devuelto := v_monto_devuelto + coalesce((it->>'precio')::numeric, 0);
  end loop;
  for it in select * from jsonb_array_elements(coalesce(p_items_nuevos,'[]'::jsonb)) loop
    v_monto_nuevo := v_monto_nuevo + coalesce((it->>'precio')::numeric, 0);
  end loop;
  v_diferencia := v_monto_nuevo - v_monto_devuelto;

  -- Si la diferencia queda a favor del cliente, hay que reintegrarla ya
  -- (mismo control de caja abierta que la devolución simple de siempre).
  -- Si queda a favor del negocio (diferencia > 0), no se cobra acá: la
  -- cobra el frontend como una venta nueva, con su propio control de caja.
  if v_diferencia < 0 then
    if p_medio_devolucion is null then
      raise exception 'Elegí el medio de reintegro.';
    end if;
    if p_medio_devolucion = 'efectivo' then
      select id into v_caja_sesion_id from caja_sesiones where local = v_venta.local and estado = 'abierta';
      if v_caja_sesion_id is null then
        raise exception 'No hay caja abierta en % — abrila antes de devolver en efectivo.', v_venta.local;
      end if;
    end if;
  end if;

  for it in select * from jsonb_array_elements(p_items) loop
    perform public._ajustar_stock_uno(
      it->>'codigo', it->>'talle', it->>'color', v_venta.local, 1, 'devolucion', v_usuario, v_id
    );
  end loop;
  for it in select * from jsonb_array_elements(coalesce(p_items_nuevos,'[]'::jsonb)) loop
    perform public._ajustar_stock_uno(
      it->>'codigo', it->>'talle', it->>'color', v_venta.local, -1, 'cambio_prenda', v_usuario, v_id
    );
  end loop;

  insert into devoluciones (id, venta_id, local, items, items_nuevos, monto, diferencia, medio_devolucion, caja_sesion_id, motivo, usuario)
  values (v_id, p_venta_id, v_venta.local, p_items, coalesce(p_items_nuevos,'[]'::jsonb),
    greatest(0, -v_diferencia), v_diferencia, p_medio_devolucion, v_caja_sesion_id, p_motivo, v_usuario);

  return jsonb_build_object('id', v_id, 'diferencia', v_diferencia);
end $function$;

grant execute on function public.registrar_devolucion(uuid, jsonb, text, text, jsonb) to authenticated;

-- cerrar_caja_sesion no cambia: sigue restando devoluciones.monto (el
-- reintegro efectivo) del efectivo esperado. Para diferencia > 0, monto
-- queda en 0 acá — el efectivo real entra después con la venta nueva.
