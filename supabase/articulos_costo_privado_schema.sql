-- ============================================================
--  Sacar el COSTO de compra de la lectura publica.
--
--  Por que: la clave anonima de Supabase es publica (viaja en index.html, y el
--  repo es publico). La policy "public read articulos [true]" mas el grant de
--  SELECT sobre toda la tabla hacian que cualquiera con esa clave pudiera leer
--  articulos.costo, o sea el costo de compra de cada articulo. Hoy la columna
--  esta vacia (0 de 4677 articulos), asi que todavia no filtro nada, pero el
--  dia que se empiecen a cargar costos quedarian a la vista.
--
--  Como se arregla: no se toca la policy. Se usa permiso columna por columna,
--  que PostgREST respeta: anon ve todo el catalogo MENOS costo. Con sesion
--  iniciada (authenticated) se sigue viendo todo.
--
--  OJO CON EL ORDEN — esto va DESPUES de publicar el cambio de index.html:
--  la app pedia `select=...,costo` con la clave anonima en cargarCatalogo(), y
--  con este permiso revocado ese pedido devuelve 42501 y la lista de precios
--  no carga. El index.html ya arreglado pide el catalogo sin costo y trae los
--  costos aparte, con sesion, en cargarCostos().
--
--  Estado: NO aplicada todavia. Aplicar cuando el nuevo index.html este en main
--  y publicado en GitHub Pages.
-- ============================================================

revoke select on public.articulos from anon;

grant select (
  id,
  codigo,
  nombre,
  categoria,
  precio_lista,
  talles,
  updated_at,
  foto_url
) on public.articulos to anon;

grant select on public.articulos to authenticated;

-- Para volver atras si algo se rompe:
--   grant select on public.articulos to anon;
