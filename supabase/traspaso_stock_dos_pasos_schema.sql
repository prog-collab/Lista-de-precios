-- ============================================================
--  Traspaso de stock entre locales en 2 pasos (mercadería "en tránsito"):
--  cualquier vendedor puede ENVIAR stock desde su propio local (se descuenta
--  al instante), y recién cuando alguien del local destino CONFIRMA la
--  recepción se suma ahí. Si nadie confirma, quien envió puede cancelar y
--  recuperar el stock. Coexiste con gerente_traspasar_stock (el traspaso
--  directo, atómico, sin paso de confirmación, que sigue siendo solo para
--  gerente — pensado para cuando el gerente mueve la mercadería él mismo).
--  Confirmado explícitamente por el usuario el 2026-07-11 antes de aplicar
--  (clasificador de seguridad lo pidió por dar a vendedores sin rango de
--  gerente la capacidad de mover stock entre los dos locales).
--  Ya aplicada en Supabase — este archivo queda como referencia/backup.
-- ============================================================

create table if not exists traspasos_stock (
  id uuid primary key default gen_random_uuid(),
  codigo text not null,
  talle text not null,
  color text not null,
  cantidad integer not null check (cantidad > 0),
  local_origen text not null check (local_origen in ('camerino','giustozzi')),
  local_destino text not null check (local_destino in ('camerino','giustozzi')),
  estado text not null default 'enviado' check (estado in ('enviado','recibido','cancelado')),
  enviado_por text,
  enviado_at timestamptz not null default now(),
  recibido_por text,
  recibido_at timestamptz,
  nota text
);
create index if not exists idx_traspasos_estado_destino on traspasos_stock(estado, local_destino);
create index if not exists idx_traspasos_fecha on traspasos_stock(enviado_at desc);

alter table traspasos_stock enable row level security;
drop policy if exists "admin all traspasos_stock" on traspasos_stock;
create policy "admin all traspasos_stock" on traspasos_stock for all using (public.is_admin()) with check (public.is_admin());

-- Envía: descuenta stock en origen ya mismo (deja de estar disponible ahí) y
-- crea el registro "en tránsito". Restringido al local propio (si el
-- usuario tiene local_asignado) — mismo criterio que el resto de las
-- operaciones de stock.
create or replace function public.iniciar_traspaso_stock(
  p_codigo text, p_talle text, p_color text,
  p_local_origen text, p_local_destino text, p_cantidad integer, p_nota text default null
) returns uuid
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_usuario text;
  v_local_asignado text;
  v_talles jsonb;
  v_stock_actual int := 0;
  t jsonb; s jsonb;
  v_id uuid;
begin
  if not public.is_admin() then
    raise exception 'Necesitás una sesión válida para enviar stock.';
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

  v_local_asignado := public.mi_local_asignado();
  if v_local_asignado is not null and v_local_asignado <> p_local_origen then
    raise exception 'Tu usuario solo puede enviar stock desde %', v_local_asignado;
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
  v_id := gen_random_uuid();
  perform public._ajustar_stock_uno(p_codigo, p_talle, p_color, p_local_origen, -p_cantidad, 'traspaso_enviado', v_usuario, v_id);
  insert into traspasos_stock (id, codigo, talle, color, cantidad, local_origen, local_destino, estado, enviado_por, nota)
  values (v_id, p_codigo, p_talle, p_color, p_cantidad, p_local_origen, p_local_destino, 'enviado', v_usuario, p_nota);
  return v_id;
end $function$;
grant execute on function public.iniciar_traspaso_stock(text, text, text, text, text, integer, text) to authenticated;

-- Confirma la recepción: recién acá se suma el stock en destino. Restringido
-- al local propio (destino) si el usuario tiene local_asignado.
create or replace function public.confirmar_traspaso_stock(p_traspaso_id uuid)
returns void
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_usuario text;
  v_local_asignado text;
  v_tr record;
begin
  if not public.is_admin() then
    raise exception 'Necesitás una sesión válida para confirmar la recepción.';
  end if;
  select * into v_tr from traspasos_stock where id = p_traspaso_id for update;
  if not found then raise exception 'Traspaso no encontrado.'; end if;
  if v_tr.estado <> 'enviado' then
    raise exception 'Este traspaso ya está %', v_tr.estado;
  end if;

  v_local_asignado := public.mi_local_asignado();
  if v_local_asignado is not null and v_local_asignado <> v_tr.local_destino then
    raise exception 'Tu usuario solo puede confirmar recepciones en %', v_local_asignado;
  end if;

  v_usuario := auth.jwt()->>'email';
  perform public._ajustar_stock_uno(v_tr.codigo, v_tr.talle, v_tr.color, v_tr.local_destino, v_tr.cantidad, 'traspaso_recibido', v_usuario, p_traspaso_id);
  update traspasos_stock set estado='recibido', recibido_por=v_usuario, recibido_at=now() where id=p_traspaso_id;
end $function$;
grant execute on function public.confirmar_traspaso_stock(uuid) to authenticated;

-- Cancela un envío que todavía no fue recibido: repone el stock en origen.
-- Solo quien está en el local de origen (o gerente) puede cancelar.
create or replace function public.cancelar_traspaso_stock(p_traspaso_id uuid)
returns void
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_usuario text;
  v_local_asignado text;
  v_tr record;
begin
  if not public.is_admin() then
    raise exception 'Necesitás una sesión válida para cancelar.';
  end if;
  select * into v_tr from traspasos_stock where id = p_traspaso_id for update;
  if not found then raise exception 'Traspaso no encontrado.'; end if;
  if v_tr.estado <> 'enviado' then
    raise exception 'Este traspaso ya está %', v_tr.estado;
  end if;

  v_local_asignado := public.mi_local_asignado();
  if v_local_asignado is not null and v_local_asignado <> v_tr.local_origen then
    raise exception 'Tu usuario solo puede cancelar envíos hechos desde %', v_local_asignado;
  end if;

  v_usuario := auth.jwt()->>'email';
  perform public._ajustar_stock_uno(v_tr.codigo, v_tr.talle, v_tr.color, v_tr.local_origen, v_tr.cantidad, 'traspaso_cancelado', v_usuario, p_traspaso_id);
  update traspasos_stock set estado='cancelado' where id=p_traspaso_id;
end $function$;
grant execute on function public.cancelar_traspaso_stock(uuid) to authenticated;
