-- ============================================================
--  editar_sistema_talles(): permite cambiar el array de talles de un
--  artículo (ej. "Único" mal cargado -> S,M,L,XL) desde la app de
--  vendedores, sin poder pisar stock a mano.
--
--  El array de talles nuevo lo arma el SERVIDOR, no el cliente: para
--  cada nombre de talle nuevo, si coincide (sin mayúsculas) con un
--  talle que ya existía, reusa su "stock" y "precio" tal cual estaban;
--  si es un talle realmente nuevo, arranca con stock vacío. El cliente
--  nunca puede mandar un "stock" propio -- así se mantiene la garantía
--  del trigger trg_articulos_proteger_stock (proteger_stock_schema.sql).
--
--  Si un talle viejo con stock cargado NO tiene equivalente en la lista
--  nueva, ese stock se pierde (es inevitable: ya no hay dónde ponerlo) --
--  pero queda registrado en stock_movimientos con motivo 'correccion',
--  igual que cualquier otro ajuste, para no romper la auditoría.
-- ============================================================

create or replace function public.editar_sistema_talles(
  p_codigo text, p_talles jsonb, p_precio numeric default null, p_usuario text default null
) returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_talles      jsonb;
  v_new         jsonb := '[]'::jsonb;
  v_old_stock   jsonb;
  v_old_precio  numeric;
  v_base_precio numeric;
  t             jsonb;
  s             jsonb;
  nombre        text;
begin
  if p_talles is null or jsonb_typeof(p_talles) <> 'array' or jsonb_array_length(p_talles) = 0 then
    raise exception 'La lista de talles no puede estar vacía.';
  end if;

  select talles into v_talles from articulos where codigo = p_codigo for update;
  if v_talles is null then
    raise exception 'Artículo % no encontrado', p_codigo;
  end if;

  v_base_precio := coalesce((v_talles->0->>'precio')::numeric, p_precio, 0);

  for nombre in select jsonb_array_elements_text(p_talles) loop
    v_old_stock := null; v_old_precio := null;
    for t in select * from jsonb_array_elements(v_talles) loop
      if lower(t->>'talle') = lower(nombre) then
        v_old_stock := case when jsonb_typeof(t->'stock') = 'array' then t->'stock' else '[]'::jsonb end;
        v_old_precio := (t->>'precio')::numeric;
      end if;
    end loop;
    v_new := v_new || jsonb_build_array(jsonb_build_object(
      'talle', nombre,
      'precio', coalesce(v_old_precio, p_precio, v_base_precio, 0),
      'stock', coalesce(v_old_stock, '[]'::jsonb)
    ));
  end loop;

  -- Audita el stock de talles viejos que no están en la lista nueva.
  for t in select * from jsonb_array_elements(v_talles) loop
    if not exists (
      select 1 from jsonb_array_elements_text(p_talles) x where lower(x) = lower(t->>'talle')
    ) then
      for s in select * from jsonb_array_elements(
        case when jsonb_typeof(t->'stock') = 'array' then t->'stock' else '[]'::jsonb end
      ) loop
        if coalesce((s->>'camerino')::int, 0) <> 0 then
          insert into stock_movimientos(codigo, talle, color, local, delta, stock_resultante, motivo, usuario)
          values (p_codigo, t->>'talle', coalesce(s->>'color','Único'), 'camerino',
                  -coalesce((s->>'camerino')::int, 0), 0, 'correccion', p_usuario);
        end if;
        if coalesce((s->>'giustozzi')::int, 0) <> 0 then
          insert into stock_movimientos(codigo, talle, color, local, delta, stock_resultante, motivo, usuario)
          values (p_codigo, t->>'talle', coalesce(s->>'color','Único'), 'giustozzi',
                  -coalesce((s->>'giustozzi')::int, 0), 0, 'correccion', p_usuario);
        end if;
      end loop;
    end if;
  end loop;

  perform set_config('app.bypass_stock_protection', 'on', true);
  update articulos set talles = v_new, precio_lista = (v_new->0->>'precio')::numeric where codigo = p_codigo;

  return v_new;
end $function$;

grant execute on function public.editar_sistema_talles(text, jsonb, numeric, text) to public, anon, authenticated, service_role;
