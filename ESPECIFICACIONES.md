# Especificaciones — App de Lista de Precios

App web para consultar rápidamente el precio de los productos del negocio.
Alojada en GitHub Pages, igual que el proyecto "Himnario".

---

## 1. Objetivo

Buscar el precio de un producto en segundos desde el celular en el mostrador.
Escribís parte del nombre y aparece el producto con su precio.
Busqueda por codigo,nombre, talle y categoría (ej. "camperas")

---

## 2. Cómo funciona (resumen técnico)

- **Una sola página web** (`index.html`) con todo adentro: HTML + CSS + JavaScript.
- Los productos viven en un archivo **`productos.json`** dentro del repo.
- La app carga ese JSON y filtra en vivo mientras escribís.
- **No necesita servidor ni base de datos.** Funciona 100% en el navegador.
- Una vez cargada, anda incluso sin internet (se puede instalar como app en el celular).

---

## 3. Origen de los datos

Los precios salen de tu Google Sheet. El flujo es:

1. Mantenés tu planilla de Google como siempre.
2. Cuando cambian precios, **exportás** la planilla a `productos.json`.
3. Subís el JSON actualizado a GitHub.

> Más adelante puedo darte un mini-script o un paso simple para que esa
> exportación sea casi automática (copiar/pegar o un botón).

### Estructura de cada producto en el JSON

```json
[
  {
    "codigo": "001",
    "nombre": "Coca Cola 1.5L",
    "categoria": "Bebidas",
    "precio": 1800
  },
  {
    "codigo": "002",
    "nombre": "Pan lactal",
    "categoria": "Almacén",
    "precio": 1200
  }
]
```

**Columnas mínimas necesarias en el Sheet:** nombre y precio.
**Opcionales (recomendadas):** código y categoría.

> ❓ **Necesito confirmar:** ¿qué columnas tiene hoy tu planilla y cómo se llaman?
> (Ej: "Producto", "Precio", "Rubro", "Código"). Con eso ajusto el mapeo exacto.
Las categorias estan en filas, luego debajo de la categoria viene una fila de talles
---
en general, del talle 1 al 4 el precio se mantiene. Los productos que tienen precios en las siguientes columnas, es porque disponen de talles grandes, del 5 en adelante. Esos deben cambiar de precio al seleccionar esos talles mas grandes
## 4. Funciones de la app

### Búsqueda
- Campo de texto arriba de todo. Filtra a medida que escribís (sin apretar Enter).
- Busca por **codigo,nombre, talle y categoría** (e ignora mayúsculas/acentos).
- Si la planilla tiene códigos, también busca por **código**.

### Filtro por categoría
- Botones o desplegable para mostrar solo una categoría (Bebidas, Almacén, etc.).
- Opción "Todas" para ver todo.

### Resultados
- Lista con: codigo, nombre del producto y **precio bien grande y visible**.
- Si corresponde, muestra categoría y en chico.
- Ordenados por Código.
Cuando se toca un codigo encontrado, necesito que me muestr el precio de lista, el de contado efectivo con 10% de descuento ya calculado. Tambien el precio en 3 cuotas sin interés (actualmente trabajamos con 3 cuotas sin interés), también la opción de seleccionar 6, 9, 12 cuotas con un 4 % mensual de interés por ahora (puede cambiar en el futuro).
también que muestre el precio si se aplica una promo bancaria opcional con 15 , 20 , 25 , 30% de descuento


---

## 5. Diseño

- **Optimizado para celular**: botones y texto grandes, fácil de leer al instante.
- Funciona también en compu/tablet (diseño responsive).
- Colores claros y limpios. (Podemos usar los colores de tu negocio si querés.)
- Precio destacado en negrita y color, para verlo de un vistazo.

> ❓ **Opcional:** ¿querés un logo, nombre del negocio o colores específicos arriba? Por ahora no, pero lo podemos agregar luego

---

## 6. Archivos del proyecto

```
lista-de-precios/
├── index.html        ← la app completa (HTML + CSS + JS)
├── productos.json    ← los datos de tus productos
└── README.md         ← instrucciones para actualizar precios
```

---

## 7. Publicación en GitHub (igual que Himnario)

1. Creás un repositorio nuevo (ej: `lista-de-precios`).
2. Subís los 3 archivos.
3. Activás **GitHub Pages** en Settings → Pages.
4. Te queda una URL pública tipo:
   `https://tuusuario.github.io/lista-de-precios/`
5. Esa URL la abrís en el celular y la guardás en la pantalla de inicio.

---

## 8. Para actualizar precios (uso diario)

1. Editás precios en tu Google Sheet.
2. Exportás → reemplazás `productos.json`.
3. Subís el archivo a GitHub.
4. Listo: la app muestra los precios nuevos.

---

## 9. Decisiones tomadas

| Tema | Decisión |
|------|----------|
| Origen de datos | Exportar a `productos.json` en el repo |
| Búsqueda | Por nombre + filtro por categoría |
| Dispositivo | Optimizado para celular (responsive) |
| Hosting | GitHub Pages |

## 10. Pendientes a confirmar con vos

1. Nombres exactos de las columnas de tu Google Sheet.
2. ¿Tu planilla tiene códigos y categorías, o solo nombre y precio?
3. ¿Logo / nombre del negocio / colores para el encabezado? Giustozzi/Camerino
4. ¿Cómo querés ordenar: alfabético o por precio? Por codigo

---
---

# BITÁCORA DEL PROYECTO (estado actual)

## Facturas FAJ 19803 y 19804 (cargadas 11/06/2026)

(La 19804 está a nombre de Barberis Florencia Jimena; se cargó como stock del
mismo negocio.)

- **Prefijos actualizados** (factura × 2,42): 6996XXX → 81.800;
  04240XXX y 07544XXX → 71.700; 23458XXX → 88.100.
- **Modelos más baratos separados con código completo** (regla del usuario):
  buzos 06996640/539/676/693 a 65.300; chombas a 38.700 (facturadas a $16.000,
  posible liquidación): 04240604, 07544416, 07544815, 20562619, 20566603,
  20566606, 20570653, 20572416. Los prefijos viejos quedaron para el stock
  anterior.
- **Subas por divergencia** (regla del usuario: subir toda la categoría en la
  proporción de los repetidos que subieron): BUZOS HOMBRE +14,4% (150 filas);
  CHOMBAS M/LARGA +15,65% (121 filas).
- **Nuevos:** 11913XXX (jean dama 96.800 / t.18 103.600); 13052602 (pantalón
  hombre 126.000 / t.40-46 134.900).
- **Corrección 13052603:** la base (t.28-38) es 126.000 y 134.900 es el talle
  grande (40-46); el mini-bloque JEANS HOMBRE del final ahora tiene talles
  '28-38' (col C) y '40-46' (col F).
- Resultado: 4.893 productos, todo redondeado a $100, verificado.

## Aviso de aumentos en la app (11/06/2026)

- Archivo **`avisos.json`** en el repo: `{"fecha":"AAAA-MM-DD","categorias":[…]}`.
  **Regla para Claude:** cada vez que se cargue una factura con subas de
  categoría, actualizar `avisos.json` con la fecha del día y las categorías
  (SIN porcentajes). Hay que subirlo a GitHub junto con productos.json.
- La app muestra un **banner amarillo cerrable (✕)** durante **5 días** desde
  la fecha: "📢 Subieron los precios en: …". Cerrado queda cerrado (localStorage).
- **Notificaciones a las 9:30 y 17:00** durante esos 5 días (una vez por
  horario por día). Requieren tocar el 🔔 del banner la primera vez para dar
  permiso. Limitación de una web sin servidor: la notificación se dispara si
  la app está abierta a esa hora, o al abrirla más tarde ese día.
- `sw.js` pasó a caché v2 e incluye avisos.json.

## ÚLTIMO CAMBIO (11/06/2026): factura FAJ + redondeo a $100

- **Factura Fábrica Argentina de Jeans (29/05/2026):** precio venta = factura
  × 2,42, redondeado a $100. Actualizados: 10431XXX (90.000), 10461XXX
  (101.300), 10561XXX (94.500 / t.grande 101.100), 11599XXX (101.300).
  11719XXX NO se bajó (quedó 97.000 por decisión del usuario, la fórmula daba
  93.300). Nuevos en JEANS DAMA: 11671XXX, 11737XXX, 11847XXX, 11907XXX,
  11909XXX; en JEANS HOMBRE: 13052668 y 13052603 (código completo de 8 dígitos
  porque ambos empiezan 13052 y chocarían con el formato XXX). Quedaron al
  final de la hoja bajo encabezados nuevos "JEANS DAMA" y "JEANS HOMBRE".
- **Redondeo a $100 en TODA la planilla** (columnas C-L): valores sueltos
  redondeados; las **fórmulas se conservaron** envueltas en
  `=ROUND((expr)/100,0)*100` (7.762 fórmulas, 5.038 valores). Las columnas
  auxiliares (M-U: factores, porcentajes) no se tocaron.
- El talle grande de 10431/10461/11599 es fórmula (C×factor): se recalcula
  solo al abrir en Sheets con el C nuevo; el próximo "actualizá precios" lo
  toma para la app.
- `actualizar_precios.py` ahora también redondea a $100 al generar el JSON.
- **Aumento general JEANS DAMA (+10%, 11/06/2026):** la fábrica subió en
  general (+9,63% promedio en los modelos repetidos de la factura), así que se
  subió +10% el resto de la categoría: 250 filas, excluyendo los 12 códigos de
  la factura. **Regla permanente pedida por el usuario:** al cargar facturas,
  avisar siempre si los precios nuevos divergen de los existentes y ofrecer
  subir toda la categoría en la proporción promedio.
- **Backup previo:** `LISTA-backup-2026-06-11.xlsx` en la carpeta local
  (anterior al redondeo, la factura y el +10%).
- **Pendiente del usuario:** (1) reemplazar la planilla en Drive SIN cambiar
  el enlace: Drive → clic derecho en LISTA.xlsx → **Administrar versiones →
  Subir versión nueva** → elegir el LISTA.xlsx de la carpeta del proyecto.
  (2) Subir a GitHub: productos.json + index.html (+ manifest.json, sw.js,
  icon-192.png, icon-512.png de la PWA).

_Última actualización: 11/06/2026_

## A. Qué quedó construido

App web 100% funcional y **publicada en GitHub Pages**.

- **Repositorio:** `prog-collab/Lista-de-precios` (público).
- **URL en vivo:** https://prog-collab.github.io/Lista-de-precios/
- **Archivos en el repo:** `index.html`, `productos.json`, `README.md`,
  `actualizar_precios.py`.

## B. Cómo está armada la app

- Una sola página (`index.html`) con HTML + CSS + JavaScript, diseño
  **mobile-first** (fondo oscuro, precio grande y destacado).
- Carga `productos.json` (mismo repo) y filtra en vivo.
- **Buscador** por código, nombre y categoría (ignora mayúsculas y acentos).
  Resultados ordenados por código.
- **Filtro** por categoría (desplegable).
- Al tocar un producto se abre el detalle con:
  - **Precio de lista** (cambia según el talle elegido).
  - **Contado efectivo:** −10%.
  - **3 cuotas sin interés:** precio ÷ 3.
  - **6 / 9 / 12 cuotas:** sistema francés con interés mensual editable (4% por defecto).
  - **Promos bancarias:** −15% / −20% / −25% / −30%.

## C. Cómo se entendió el Excel (clave para el parser)

- Origen: `LISTA 2025.xlsx`, hoja única, ~5.000 filas.
- **Columna A** = código. **Columna B** = nombre del producto / nombre de marca.
- **Columnas C, D, E, F** = precios por **rango de talle**:
  - C = talles 1 al 4 (precio base / precio de lista).
  - D, E, F = talles más grandes (del 5 en adelante), suben de precio.
- **Categorías:** son filas con el nombre en la **columna B** y **sin precios**.
  La categoría aplica a todos los productos de abajo hasta el próximo encabezado.
- **Nombres heredados:** un producto sin nombre propio hereda el nombre de la
  marca/categoría del encabezado anterior.
- La app calcula contado, cuotas y promos a partir del precio del talle elegido.

## D. Reglas de cálculo

Sobre el precio de lista del talle seleccionado:

- Contado efectivo: −10%.
- 3 cuotas: precio ÷ 3 (sin interés).
- 6/9/12 cuotas: **interés directo (simple)**, tasa mensual configurable (4% por
  defecto, editable desde la pantalla de detalle). Recargo = tasa × cantidad de
  cuotas; cuota = precio × (1 + tasa × n) / n.
  _(Cambiado el 11/06/2026: antes era sistema francés.)_
- Promos bancarias: −15% / −20% / −25% / −30%.

## D ter. Cambios de UI (11/06/2026)

- "Precio de lista" pasó a llamarse **"DÉBITO / TRANSFERENCIA / CRED 1 PAGO"** en el detalle.
- Código cian en la lista de resultados al mismo tamaño que el nombre (15px).
- Botones **A− / A+** en el encabezado para achicar/agrandar la letra (se
  guarda en el navegador, rango 0.8×–1.6×).
- El detalle se cierra con un botón **"← Atrás"** celeste, arriba a la derecha,
  junto a la estrella de favorito (reemplaza la ×). Se probó flotante abajo a
  la derecha pero tapaba contenido; se volvió arriba (decisión 11/06/2026).
  El botón "atrás" físico/gesto del celular también cierra el detalle sin
  salir de la app (history API).
- **Promo banco:** ahora es una sola fila con desplegable (−15/−20/−25/−30%),
  por defecto **−20%**.
- El título "2025" solo existía en la versión publicada vieja; el index.html
  actual dice "Lista de Precios" (se corrige al subirlo a GitHub).

## D quater. PWA instalable (11/06/2026)

- Se agregaron `manifest.json`, `sw.js` (service worker) e íconos
  `icon-192.png` / `icon-512.png`. Con esto Android ofrece **"Instalar app"**
  (no solo acceso directo) y la app funciona **sin internet**.
- El service worker usa **red primero** con respaldo en caché: los precios
  nuevos llegan apenas hay conexión, y sin señal se usan los últimos guardados.
- Archivos NUEVOS que hay que subir a GitHub: `manifest.json`, `sw.js`,
  `icon-192.png`, `icon-512.png` (además de los `index.html` y
  `productos.json` actualizados).

## D quinquies. Carrito (agregado 11/06/2026)

- Botón **"🛒 Agregar al carrito"** en el detalle (agrega el producto con el
  talle seleccionado; si ya está, suma cantidad).
- Botón 🛒 en el encabezado con contador de artículos; abre la pantalla del
  carrito.
- Pantalla del carrito: lista de ítems con cantidad (+/−), quitar (✕),
  subtotales, y el TOTAL con **las mismas opciones de pago** del detalle:
  débito/transferencia/cred 1 pago, contado −10%, 3 cuotas s/int.,
  6/9/12 cuotas con interés directo (tasa editable) y promo banco
  (desplegable, −20% por defecto).
- "Vaciar carrito" con confirmación. El carrito persiste en localStorage.
- El botón "atrás" del celular también cierra el carrito.

## D bis. Favoritos e historial (agregado 11/06/2026)

- **Favoritos:** estrella (☆/★) en cada producto y en el detalle. Se guardan en
  el navegador del celular (localStorage), persisten entre usos.
- **Historial:** los últimos códigos consultados (máx. 15) se guardan al abrir el
  detalle de un producto.
- Con la búsqueda vacía, la pantalla de inicio muestra Favoritos + Últimos
  consultados. El historial se puede borrar con un botón.

## E. Errores encontrados y cómo se resolvieron

1. **Categoría fantasma `03/26`:** un bloque de camisas no tenía título y quedó
   una fecha como categoría. → El parser ignora fechas como categoría; esos
   productos heredan la categoría anterior. (Bloque WRANGLER/ALL SEASONS = camisas.)
2. **Bloque de camisas catalogado como "JEANS HOMBRE":** se probó y se revirtió;
   son camisas (categoría CAMISAS M LARGA HOMBRE).
3. **`JEANS HOMBRE` con 0 productos:** había un encabezado JEANS HOMBRE seguido
   inmediatamente de LAST POINT. Se corrigió en el Excel; ahora JEANS HOMBRE
   tiene sus productos.
4. **Categoría TAVERNITI mal:** TAVERNITI es un PRODUCTO (código en col A), pero
   en la columna C el precio venía con letras "X" pegadas (ej. `17828XXX`). Como
   no era un número válido, el parser tomaba esa fila como encabezado y creaba
   una categoría "TAVERNITI".
   - **Solución doble:** (a) el usuario limpió las X en el Excel; (b) se mejoró
     el parser para reconocer precios con X o $ pegados (regex) y leerlos como
     número. Así no vuelve a pasar.

## F. Pendiente al día de hoy

- ~~Regenerar `productos.json` con el Excel corregido (TAVERNITI).~~ ✅ Hecho el
  11/06/2026: TAVERNITI ya no aparece como categoría (0 productos, antes 85);
  4.872 productos, 61 categorías, 0 sin categoría.
- **Subir el `productos.json` nuevo a GitHub** (mismo nombre, reemplaza al
  anterior) y hacer recarga forzada en la app.
- Categorías chicas a verificar si son reales: CHALINAS (1), CINTOS DAMA (2),
  TWIN SET (2), REMERAS HILO M 3/4 (2), Billeteras dama (1).

## G. Cómo actualizar precios en el futuro

**Flujo nuevo (sin Excel, desde 11/06/2026):** el usuario no tiene licencia
de Excel; la fuente de verdad es la planilla en Google Drive.

- **Planilla:** `LISTA.xlsx` abierta con Google Sheets, compartida con enlace
  (lector): https://docs.google.com/spreadsheets/d/1cg2fM1xGxzqBOoSv2mC68W3OcsKmNHAgQSthRxkOVDI/
- El usuario edita precios ahí (celular o compu) y le dice a Claude
  "actualizá los precios".
- Claude lee la planilla por el endpoint gviz en porciones (web_fetch no trae
  las 5.092 filas de una):
  `…/gviz/tq?tqx=out:csv&tq=select A,B,C,D,E,F limit 500 offset N`
  (N = 0, 500, 1000, …), arma el CSV completo y regenera `productos.json`
  con la misma lógica del parser (categorías = filas sin precio, talles, etc.).
- Subir `productos.json` a GitHub y recargar la app.

**Dato clave de la planilla:** tiene 10 columnas de precio (talles 1-4, 5-XXL,
3xl-6, 4xl-7, 8, 9, 10, 12, 14, 16) más columnas auxiliares (S = precio×factor,
T = factor tipo 1,03). **Decisión del 11/06/2026: la app usa SOLO las primeras
4 (C-F)**, igual que siempre. Las columnas G-L quedan afuera a propósito.

**Facturas con productos nuevos:** el usuario manda una foto; Claude extrae
códigos/nombres/precios y los carga en el Google Sheet **vía Claude en Chrome**
(decisión 11/06/2026). El conector de Drive actual solo lee, no escribe.

Flujo viejo (si hubiera un .xlsx local): `python actualizar_precios.py`.

## H. Mejoras posibles a futuro (no urgentes)

- Encabezado con nombre/logo del negocio (Giustozzi/Camerino).
- Búsqueda estricta por talle individual.
- Revisar/normalizar categorías chicas.
