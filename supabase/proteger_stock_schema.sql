-- ============================================================
--  Protege articulos.talles[].stock de escrituras directas desde
--  cualquier canal que no sea la funcion de stock de la app de
--  vendedores (_ajustar_stock_uno, usada por ajustar_stock,
--  aplicar_venta_stock, iniciar_traspaso_stock, gerente_traspasar_stock).
--
--  Motivo: el panel admin de la web podia hacer un UPDATE directo a
--  articulos.talles (editor de stock, edicion de precio) sin pasar por
--  ninguna auditoria (stock_movimientos) ni respetar el local_asignado
--  del usuario. Esta migracion:
--   1) Agrega un trigger que compara el "stock" (por talle y color) antes
--      y despues del UPDATE, ignorando talle/precio -- si cambia y no vino
--      de un llamado ya autorizado, rechaza el UPDATE.
--   2) Marca _ajustar_stock_uno como el unico llamado autorizado (via un
--      flag de sesion local a la transaccion).
--   3) Agrega actualizar_precio_articulo(), para que la web pueda seguir
--      editando el precio de lista sin volver a escribir el array
--      completo de talles a mano (evita pisar stock por una lectura vieja).
-- ============================================================

-- Representacion normalizada (orden estable) del "stock" de un array de
-- talles, ignorando talle/precio -- sirve para comparar OLD vs NEW.
create or replace function public._talles_stock_json(p_talles jsonb)
returns jsonb
language sql
immutable
set search_path to 'public', 'pg_temp'
as $function$
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'talle', t->>'talle',
      'stock', (
        select coalesce(jsonb_agg(
          jsonb_build_object(
            'color', s->>'color',
            'camerino', coalesce((s->>'camerino')::int, 0),
            'giustozzi', coalesce((s->>'giustozzi')::int, 0)
          ) order by s->>'color'
        ), '[]'::jsonb)
        from jsonb_array_elements(
          case when jsonb_typeof(t->'stock') = 'array' then t->'stock' else '[]'::jsonb end
        ) s
      )
    ) order by t->>'talle'
  ), '[]'::jsonb)
  from jsonb_array_elements(coalesce(p_talles, '[]'::jsonb)) t;
$function$;

create or replace function public._articulos_proteger_stock()
returns trigger
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
begin
  if current_setting('app.bypass_stock_protection', true) = 'on' then
    return new;
  end if;
  if public._talles_stock_json(new.talles) is distinct from public._talles_stock_json(old.talles) then
    raise exception 'El stock no se puede modificar desde acá — cargalo desde la app de vendedores (Lista de precios).';
  end if;
  return new;
end $function$;

drop trigger if exists trg_articulos_proteger_stock on articulos;
create trigger trg_articulos_proteger_stock
  before update on articulos
  for each row execute function public._articulos_proteger_stock();

-- _ajustar_stock_uno (la única función que de verdad escribe stock) marca
-- el flag de bypass justo antes de su propio UPDATE, para que el trigger
-- de arriba la deje pasar. El flag es local a la transacción (tercer
-- argumento `true` de set_config), así que no "queda prendido" para nada
-- más en la misma sesión.
create or replace function public._ajustar_stock_uno(
  p_codigo text, p_talle text, p_color text, p_local text, p_delta integer,
  p_motivo text, p_usuario text, p_referencia uuid
) returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_talles   jsonb;
  v_new      jsonb := '[]'::jsonb;
  v_newstock jsonb;
  t          jsonb;
  s          jsonb;
  v_talle_ok boolean := false;
  v_color_ok boolean;
  v_qty      int;
  v_local_asignado text;
begin
  if p_local not in ('camerino','giustozzi') then
    raise exception 'Local inválido: %', p_local;
  end if;

  v_local_asignado := public.mi_local_asignado();
  if v_local_asignado is not null and v_local_asignado <> p_local then
    raise exception 'Tu usuario solo puede operar stock en %', v_local_asignado;
  end if;

  select talles into v_talles from articulos where codigo = p_codigo for update;
  if v_talles is null then
    raise exception 'Artículo % no encontrado o sin permisos', p_codigo;
  end if;

  for t in select * from jsonb_array_elements(v_talles) loop
    if t->>'talle' = p_talle then
      v_talle_ok := true;
      v_newstock := '[]'::jsonb;
      v_color_ok := false;
      for s in select * from jsonb_array_elements(
        case when jsonb_typeof(t->'stock') = 'array' then t->'stock' else '[]'::jsonb end
      ) loop
        if lower(coalesce(s->>'color','')) = lower(p_color) then
          v_color_ok := true;
          v_qty := greatest(0, coalesce((s->>p_local)::int, 0) + p_delta);
          s := jsonb_set(s, array[p_local], to_jsonb(v_qty));
        end if;
        v_newstock := v_newstock || jsonb_build_array(s);
      end loop;
      if not v_color_ok then
        v_qty := greatest(0, p_delta);
        v_newstock := v_newstock || jsonb_build_array(jsonb_build_object(
          'color', p_color,
          'camerino',  case when p_local = 'camerino'  then v_qty else 0 end,
          'giustozzi', case when p_local = 'giustozzi' then v_qty else 0 end
        ));
      end if;
      t := jsonb_set(t, '{stock}', v_newstock);
    end if;
    v_new := v_new || jsonb_build_array(t);
  end loop;

  if not v_talle_ok then
    raise exception 'Talle "%" no existe en el artículo %', p_talle, p_codigo;
  end if;

  perform set_config('app.bypass_stock_protection', 'on', true);
  update articulos set talles = v_new where codigo = p_codigo;

  insert into stock_movimientos(codigo, talle, color, local, delta, stock_resultante, motivo, referencia_id, usuario)
  values (p_codigo, p_talle, p_color, p_local, p_delta, v_qty, p_motivo, p_referencia, p_usuario);

  return v_new;
end $function$;

-- Editar el precio de lista desde el panel web sin volver a escribir el
-- array completo de talles a mano en el cliente (que podía pisar stock
-- cargado en simultáneo, por partir de una lectura vieja). Usa "for
-- update" igual que _ajustar_stock_uno, y solo toca el campo "precio" de
-- cada talle -- nunca "stock", así que ni siquiera necesita el bypass.
create or replace function public.actualizar_precio_articulo(p_codigo text, p_precio_lista numeric)
returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_talles jsonb;
  v_new    jsonb := '[]'::jsonb;
  t        jsonb;
  v_base   numeric;
  v_factor numeric;
  i        int := 0;
begin
  if not public.is_admin() then
    raise exception 'Necesitás una sesión de administrador.';
  end if;
  if p_precio_lista is null or p_precio_lista <= 0 then
    raise exception 'El precio tiene que ser mayor a 0.';
  end if;

  select talles into v_talles from articulos where codigo = p_codigo for update;
  if v_talles is null then
    raise exception 'Artículo % no encontrado', p_codigo;
  end if;

  if jsonb_array_length(v_talles) = 0 then
    v_new := jsonb_build_array(jsonb_build_object('talle', 'Único', 'precio', p_precio_lista));
  else
    v_base := (v_talles->0->>'precio')::numeric;
    v_factor := case when coalesce(v_base, 0) > 0 then p_precio_lista / v_base else 1 end;
    for t in select * from jsonb_array_elements(v_talles) loop
      if i = 0 then
        t := jsonb_set(t, '{precio}', to_jsonb(p_precio_lista));
      else
        t := jsonb_set(t, '{precio}', to_jsonb(round((coalesce((t->>'precio')::numeric, 0) * v_factor))));
      end if;
      v_new := v_new || jsonb_build_array(t);
      i := i + 1;
    end loop;
  end if;

  update articulos set precio_lista = p_precio_lista, talles = v_new where codigo = p_codigo;
  return v_new;
end $function$;

grant execute on function public.actualizar_precio_articulo(text, numeric) to authenticated;
