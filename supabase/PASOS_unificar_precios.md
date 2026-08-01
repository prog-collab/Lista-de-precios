# Unificar la lista de precios en Supabase (Fase 1)

Objetivo: que los precios vivan en **Supabase** (una sola fuente de verdad) y la app de
vendedores los lea **en vivo**. Más adelante (Fase 2) el catálogo web también tomará de acá.

Todo va en el **mismo proyecto Supabase** del catálogo (`grswqigekcopfrozcxqj`).

---

## Paso 1 — Crear la tabla `articulos`
Supabase → **SQL Editor** → New query → pegá `supabase/articulos_schema.sql` → **Run**.

## Paso 2 — Importar los artículos (carga inicial)
Son 5 archivos (porque son ~4.600 artículos). Para cada uno: New query → pegar → **Run**.
- `supabase/articulos_seed_01.sql`
- `supabase/articulos_seed_02.sql`
- `supabase/articulos_seed_03.sql`
- `supabase/articulos_seed_04.sql`
- `supabase/articulos_seed_05.sql`

Para verificar, en SQL Editor:
```
select count(*) from articulos;
```
Tiene que dar ~4.625.

> Nota: 66 filas del Excel no tenían **código** y se omitieron (suelen ser filas vacías o
> de encabezado). Si querés, revisamos esas después.

## Paso 3 — Publicar la app de precios actualizada
Modifiqué `index.html` para que lea de Supabase en vivo (con respaldo automático a
`productos.json` si no hay conexión). Subí el `index.html` nuevo al repositorio donde está
publicada la app (GitHub Pages), igual que cuando actualizabas el JSON.

Listo: la app muestra los precios desde Supabase.

---

## Actualizar precios a futuro (cuando edites el Excel)

Tenés dos formas:

**A) Desde el panel web** (cuando hagamos la Fase 2, lo más cómodo).

**B) Con el script** (ya disponible): editás el Excel como siempre y corrés:
```
python actualizar_precios.py        (regenera productos.json desde el Excel, como hoy)
python importar_a_supabase.py       (sube esos precios a Supabase)
```
El script `importar_a_supabase.py` necesita dos variables de entorno (una sola vez por
sesión de terminal): `SUPABASE_URL` y `SUPABASE_SERVICE_KEY` (la *service_role key*, que es
secreta y NO se sube al repo). Las instrucciones están dentro del propio script.

---

## Qué sigue (Fase 2)
Conectar el catálogo web a estos artículos: elegir un artículo, ponerle fotos y decidir en
qué marca(s) se publica; el precio del sitio saldrá del precio de lista del artículo.
