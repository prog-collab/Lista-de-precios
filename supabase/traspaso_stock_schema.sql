-- ============================================================
--  Traspaso de stock entre Camerino y Giustozzi (solo gerente). Descuenta
--  en el local de origen y suma en destino de forma atomica (todo o nada,
--  misma transaccion), valida que haya stock suficiente antes de mover, y
--  deja 2 movimientos ligados por el mismo referencia_id en
--  stock_movimientos (motivo 'traspaso_salida' / 'traspaso_entrada').
--  Confirmado explicitamente por el usuario el 2026-07-11 antes de aplicar
--  (clasificador de seguridad lo pidio por tocar stock de los dos locales).
--  Ya aplicada en Supabase — este archivo queda como referencia/backup.
-- ============================================================

create or replace function public.gerente_traspasar_stock(
  p_codigo text, p_talle text, p_color text,
  p_local_origen text, p_local_destino text, p_cantidad integer
) returns void
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_usuario text;
  v_referencia uuid;
  v_talles jsonb;
  v_stock_actual int := 0;
  t jsonb; s jsonb;
begin
  if not public.is_gerente() then
    raise exception 'Solo un gerente puede hacer traspasos de stock entre locales.';
  end if;
  if p_local_origen not in ('camerino','giustozzi') or p_local_destino not in ('camerino','giustozzi') then
    raise exception 'Local inválido.';
  end if;
  if p_local_origen = p_local_destino then
    raise exception 'El local de origen y destino no pueden ser el mismo.';
  end if;
  if p_cantidad <= 0 then
    raise exception 'La cantidad tiene que ser mayor a 0.';
  end if;

  select talles into v_talles from articulos where codigo = p_codigo for update;
  if v_talles is null then
    raise exception 'Artículo % no encontrado', p_codigo;
  end if;

  for t in select * from jsonb_array_elements(v_talles) loop
    if t->>'talle' = p_talle then
      for s in select * from jsonb_array_elements(
        case when jsonb_typeof(t->'stock')='array' then t->'stock' else '[]'::jsonb end
      ) loop
        if lower(coalesce(s->>'color','')) = lower(p_color) then
          v_stock_actual := coalesce((s->>p_local_origen)::int, 0);
        end if;
      end loop;
    end if;
  end loop;

  if v_stock_actual < p_cantidad then
    raise exception 'No hay stock suficiente en % (hay %, se pidió %)', p_local_origen, v_stock_actual, p_cantidad;
  end if;

  v_usuario := auth.jwt()->>'email';
  v_referencia := gen_random_uuid();
  perform public._ajustar_stock_uno(p_codigo, p_talle, p_color, p_local_origen, -p_cantidad, 'traspaso_salida', v_usuario, v_referencia);
  perform public._ajustar_stock_uno(p_codigo, p_talle, p_color, p_local_destino, p_cantidad, 'traspaso_entrada', v_usuario, v_referencia);
end $function$;

grant execute on function public.gerente_traspasar_stock(text, text, text, text, text, integer) to authenticated;
