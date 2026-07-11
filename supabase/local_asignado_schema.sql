-- ============================================================
--  Restringe a los usuarios vendedores "camerino" y "giustozzi" a operar
--  (cargar stock, vender, facturar) solo en su propio local. El gerente
--  (jsgiusto) y camerinosantafe quedan sin restricción (local_asignado null).
--  La vista de stock del catálogo principal NO se ve afectada — sigue
--  mostrando siempre los dos locales, porque es de solo lectura y no pasa
--  por ninguna de estas políticas.
--  Ya aplicada en Supabase — este archivo queda como referencia/backup.
-- ============================================================

alter table admins add column if not exists local_asignado text;
alter table admins drop constraint if exists admins_local_asignado_check;
alter table admins add constraint admins_local_asignado_check check (local_asignado in ('camerino','giustozzi') or local_asignado is null);

update admins set local_asignado = 'camerino' where email = 'camerino@vendedores.local';
update admins set local_asignado = 'giustozzi' where email = 'giustozzi@vendedores.local';

create or replace function public.mi_local_asignado()
returns text
language sql
stable
security definer
set search_path to 'public'
as $$
  select local_asignado from admins where user_id = auth.uid();
$$;
grant execute on function public.mi_local_asignado() to authenticated, anon, public;

-- Un vendedor con local asignado solo puede insertar ventas de su propio local.
drop policy if exists "admin insert ventas" on ventas;
create policy "admin insert ventas" on ventas for insert
  with check (public.is_admin() and (public.mi_local_asignado() is null or local = public.mi_local_asignado()));

-- _ajustar_stock_uno (usada por ajustar_stock y aplicar_venta_stock) rechaza
-- ajustar stock de un local que no sea el asignado.
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

  update articulos set talles = v_new where codigo = p_codigo;

  insert into stock_movimientos(codigo, talle, color, local, delta, stock_resultante, motivo, referencia_id, usuario)
  values (p_codigo, p_talle, p_color, p_local, p_delta, v_qty, p_motivo, p_referencia, p_usuario);

  return v_new;
end $function$;
