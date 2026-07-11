-- ============================================================
--  Vista de solo lectura para el dashboard: talle/color con stock bajo
--  (entre 1 y 2 unidades entre las dos marcas — el umbral "<=2" original
--  incluía miles de combinaciones que nunca tuvieron stock cargado, sin
--  ninguna utilidad como alerta de reposición). No cambia ningún permiso —
--  hereda el RLS ya existente de "articulos" (lectura pública).
--  Ya aplicada en Supabase — este archivo queda como referencia/backup.
-- ============================================================
create or replace view v_stock_bajo as
select a.codigo, a.nombre, a.categoria, t->>'talle' as talle, s->>'color' as color,
  coalesce((s->>'camerino')::int,0) as camerino,
  coalesce((s->>'giustozzi')::int,0) as giustozzi,
  coalesce((s->>'camerino')::int,0) + coalesce((s->>'giustozzi')::int,0) as total
from articulos a,
  jsonb_array_elements(a.talles) as t,
  jsonb_array_elements(case when jsonb_typeof(t->'stock')='array' then t->'stock' else '[]'::jsonb end) as s
where coalesce((s->>'camerino')::int,0) + coalesce((s->>'giustozzi')::int,0) between 1 and 2;

grant select on v_stock_bajo to authenticated, anon, public;

-- Función de solo lectura (SECURITY INVOKER, respeta el RLS de "ventas" tal
-- cual está hoy — no amplía ningún acceso) para el ranking de más vendidos.
create or replace function public.productos_mas_vendidos(p_dias integer default 30)
returns table(codigo text, nombre text, cantidad bigint, total numeric)
language sql
stable
set search_path to 'public'
as $$
  select it->>'codigo' as codigo, it->>'nombre' as nombre,
    count(*) as cantidad, sum((it->>'precio')::numeric) as total
  from ventas v, jsonb_array_elements(v.items) as it
  where v.fecha >= current_date - p_dias
  group by it->>'codigo', it->>'nombre'
  order by cantidad desc
  limit 20;
$$;

grant execute on function public.productos_mas_vendidos(integer) to authenticated, anon, public;
