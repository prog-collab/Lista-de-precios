# 📦 Carga de stock por escaneo (app de vendedores)

La app de precios ahora tiene un **modo Stock**: se escanea el código de barras de cada
prenda con la cámara del celular y se suma +1 al stock de ese color/talle en el local
elegido. Sirve para hacer el inventario inicial y para cargar mercadería nueva.

## Qué se hizo

1. **Botón 📦 en el encabezado** de la app. Al tocarlo:
   - Pide **iniciar sesión** (email y contraseña del panel — el PIN del modo editor no
     alcanza: la base de datos solo deja escribir stock a usuarios habilitados).
   - Elegís el **local** (Camerino / Giustozzi) — queda recordado en el celular.
   - Se abre la **cámara** y queda escaneando prenda tras prenda (no se cierra entre
     lecturas). También hay un campo para escribir el código a mano.
2. **Cómo lee el código** (Taverniti: 11 dígitos = 5 artículo + 3 color + 3 talle):
   - Busca el artículo por prefijo: completo → 8 dígitos → 5+XXX → 5 dígitos.
   - **Color y talle**: la PRIMERA vez que aparece un código de color (ej. 001) te
     pregunta qué color es (ej. "Negro") y lo recuerda **para todos los celulares**
     (tabla `barcode_maps` en Supabase). Lo mismo con el talle. A partir de ahí,
     cada escaneo viene preseleccionado y confirmás con **un solo toque**.
   - Si el prefijo no existe en la lista → mini-formulario para **crear el artículo**
     (nombre, categoría, precio) sin salir del escaneo.
3. **Sumar / deshacer**: botón grande "➕ Sumar 1 a {local}", contador de la sesión y
   "↩ Deshacer último" por si escaneaste de más. El guardado es **atómico** (función
   `ajustar_stock` en Supabase): dos celulares pueden escanear a la vez sin pisarse.
4. **Stock visible en el detalle**: en modo editor, el detalle de un producto muestra
   el stock del talle elegido (total y por local).
5. El stock cargado acá es el mismo que se ve en el **panel web** (botón 📦 Stock) y el
   que muestra la **página pública** ("N unidades disponibles").

## Lo que tenés que hacer

### 1. Nada en Supabase
La migración (tabla `barcode_maps` + función `ajustar_stock`) ya está aplicada y probada.

### 2. Subir a GitHub (repo `prog-collab/Lista-de-precios`)
Subí estos 2 archivos actualizados, como siempre:
- `index.html`
- `sw.js`

### 3. Probar en el celular
1. Abrí la app → botón **📦** → iniciá sesión con tu usuario del panel.
2. Elegí el local, apuntá la cámara al código de barras de una prenda.
3. La primera vez con un color/talle nuevo: escribí el nombre del color y tocá el talle.
4. Confirmá con "➕ Sumar 1". Escaneá la siguiente prenda.
5. Si te equivocás: "↩ Deshacer último".

> Consejo para el inventario inicial: hacé una pasada por percha/estante. Después de las
> primeras prendas de cada modelo, casi todo queda en un toque por prenda.

### 4. (Opcional) Cuenta para vendedores
Si querés que los vendedores carguen stock sin usar tu cuenta, creá un usuario nuevo
siguiendo `PASOS_Nuevo_Admin.md` (del proyecto del catálogo web).

## Probado (08/07/2026)
- Login real + flujo completo con código manual `14727-001-040`: mapeo de color/talle,
  +1 a Camerino verificado en la base, deshacer verificado, segundo escaneo con todo
  preseleccionado. Los datos de prueba se limpiaron.
- El escaneo con cámara usa la misma infraestructura que el 📷 de búsqueda que ya venías
  usando (probalo con una etiqueta real en el celular).

## Pendiente (fases siguientes)
- **Modo venta (POS)**: botón "−1" para descontar stock al vender en el local.
- Cobro online con bloqueo por stock.
