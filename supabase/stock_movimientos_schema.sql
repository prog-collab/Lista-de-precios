-- ============================================================
--  Tabla "stock_movimientos": historial inmutable de cada ajuste
--  de stock (carga o venta), con motivo, referencia y usuario.
--  ajustar_stock() ya no solo pisa el stock — también deja rastro.
--  Ya aplicada en Supabase — este archivo queda como referencia/backup.
-- ============================================================

create table if not exists stock_movimientos (
  id                uuid primary key default gen_random_uuid(),
  codigo            text not null,
  talle             text not null,
  color             text not null,
  local             text not null,
  delta             integer not null,
  stock_resultante  integer not null,
  motivo            text not null,             -- 'carga' | 'venta' | 'correccion' | 'devolucion'
  referencia_id     uuid,                        -- ej. ventas.id cuando motivo='venta'
  usuario           text,                        -- email de quien hizo el ajuste
  created_at        timestamptz not null default now()
);

create index if not exists idx_stock_mov_codigo on stock_movimientos(codigo);
create index if not exists idx_stock_mov_fecha on stock_movimientos(created_at desc);
create index if not exists idx_stock_mov_referencia on stock_movimientos(referencia_id);

alter table stock_movimientos enable row level security;
drop policy if exists "admin all stock_movimientos" on stock_movimientos;
create policy "admin all stock_movimientos" on stock_movimientos
  for all using (public.is_admin()) with check (public.is_admin());

-- ============================================================
--  Función interna compartida: ajusta UN talle/color y registra
--  el movimiento. La usan tanto ajustar_stock (Cargar, de a uno)
--  como aplicar_venta_stock (Vender, todo el carrito de una vez).
-- ============================================================
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
begin
  if p_local not in ('camerino','giustozzi') then
    raise exception 'Local inválido: %', p_local;
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

  update articulos set talles = v_new where codigo = p_codigo;

  insert into stock_movimientos(codigo, talle, color, local, delta, stock_resultante, motivo, referencia_id, usuario)
  values (p_codigo, p_talle, p_color, p_local, p_delta, v_qty, p_motivo, p_referencia, p_usuario);

  return v_new;
end $function$;

-- Reemplaza ajustar_stock (misma firma + 1 parametro opcional al final,
-- para que el codigo ya desplegado siga funcionando igual).
drop function if exists public.ajustar_stock(text, text, text, text, integer);
create or replace function public.ajustar_stock(
  p_codigo text, p_talle text, p_color text, p_local text, p_delta integer, p_usuario text default null
) returns jsonb
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
begin
  return public._ajustar_stock_uno(p_codigo, p_talle, p_color, p_local, p_delta, 'carga', p_usuario, null);
end $function$;

grant execute on function public.ajustar_stock(text, text, text, text, integer, text) to public, anon, authenticated, service_role;

-- Aplica el descuento de stock de TODOS los items de una venta en una sola
-- transaccion (todo o nada) — soluciona la falta de atomicidad del carrito.
create or replace function public.aplicar_venta_stock(
  p_items jsonb, p_local text, p_usuario text, p_referencia uuid
) returns void
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  it jsonb;
begin
  for it in select * from jsonb_array_elements(p_items) loop
    perform public._ajustar_stock_uno(
      it->>'codigo', it->>'talle', it->>'color', p_local, -1, 'venta', p_usuario, p_referencia
    );
  end loop;
end $function$;

grant execute on function public.aplicar_venta_stock(jsonb, text, text, uuid) to public, anon, authenticated, service_role;
