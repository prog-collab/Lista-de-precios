# Lista de Precios — App del negocio

App web para consultar precios al instante desde el celular. Buscás por código,
nombre o categoría, elegís el talle y la app te muestra el precio de lista,
contado, cuotas y promociones ya calculados.

## Archivos

- **index.html** — la app (no se toca).
- **productos.json** — los datos de los productos y precios.
- **actualizar_precios.py** — script para regenerar `productos.json` desde el Excel.

## Cómo usar la app

1. Abrí la URL de GitHub Pages en el celular.
2. Escribí parte del código o nombre. Los resultados se filtran solos.
3. Tocá un producto para ver el detalle:
   - **Precio de lista** (cambia si elegís un talle grande).
   - **Contado efectivo** con 10% de descuento.
   - **3 cuotas sin interés**.
   - **6, 9 y 12 cuotas** con interés mensual (editable; por defecto 4%).
   - **Promos bancarias** con 15, 20, 25 y 30% de descuento.

Consejo: en el celular, "Agregar a pantalla de inicio" para abrirla como una app.

## Cómo actualizar los precios

Cuando cambien los precios:

1. Actualizá tu Excel (`LISTA 2025.xlsx`) como siempre.
2. Generá el nuevo `productos.json`:
   ```
   python actualizar_precios.py
   ```
   (requiere `pip install openpyxl`). El script lee el Excel y escribe
   `productos.json` con el mismo formato.
3. Subí el `productos.json` actualizado a GitHub (ver abajo).

> Si preferís, también podés pedirme a mí que regenere el JSON cada vez que
> tengas un Excel nuevo.

## Publicar en GitHub Pages

1. Creá un repositorio nuevo (ej. `lista-de-precios`).
2. Subí `index.html` y `productos.json`.
3. En el repo: **Settings → Pages → Branch: main → Save**.
4. A los minutos queda online en:
   `https://TUUSUARIO.github.io/lista-de-precios/`

Para actualizar precios después: subí el `productos.json` nuevo (reemplazando el
anterior) y listo, la app muestra los precios actualizados.

## Notas sobre los datos

- Las 4 columnas de precio del Excel son **rangos de talle**: la 1ª es el precio
  base (talles 1 al 4) y las siguientes son talles más grandes (5 en adelante).
- Productos sin nombre propio heredan el de la marca/categoría de arriba.
- Un bloque de jeans/pantalones del Excel no tenía título de categoría en el
  origen, así que quedó bajo la categoría anterior. Los nombres están bien; si
  querés, se puede corregir la categoría de ese bloque.

## Cómo se calculan los precios

Sobre el precio de lista del talle elegido:

- **Contado:** −10%.
- **3 cuotas:** precio ÷ 3 (sin interés).
- **6/9/12 cuotas:** sistema francés con la tasa mensual indicada (4% por defecto).
- **Promos:** −15% / −20% / −25% / −30%.

La tasa de interés se puede cambiar desde la misma pantalla de detalle.
