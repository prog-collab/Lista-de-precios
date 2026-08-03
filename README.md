# Lista-de-precios — repo archivado (solo redirección)

Este repo **ya no tiene el sistema**. La app "Gestión C&G" vive en
**https://www.camerino.com.ar/gestion**, dentro del repo
[`camerino-giustozzi-web`](https://github.com/prog-collab/camerino-giustozzi-web)
(carpeta `public/gestion/`).

Lo único que queda acá es la página de GitHub Pages que:

1. desinstala el service worker viejo y borra su caché (si no, los celulares
   siguen abriendo la app vieja desde adentro), y
2. manda al usuario a la dirección nueva.

Se mantiene online **solo** porque los celulares del local tienen instalado el
acceso directo a la URL vieja. No borrar el repo ni desactivar Pages hasta que
todos hayan reinstalado la app desde `camerino.com.ar/gestion`.

## Qué se llevó y a dónde

| Antes (acá)                             | Ahora (repo `camerino-giustozzi-web`)  |
| --------------------------------------- | -------------------------------------- |
| `index.html` (la app entera)            | `public/gestion/index.html`            |
| `productos.json`, íconos, `sw.js`       | `public/gestion/`                      |
| `supabase/*.sql`                        | `supabase/gestion/`                    |
| `actualizar_precios.py` y demás scripts | `tools/`                               |
| `ESPECIFICACIONES.md`, `PASOS_*.md`     | `docs/gestion/`                        |
| `LISTA*.xlsx`, `contactos.csv`          | fuera de todo repo, en `_datos/` local |

## Archivos

- `index.html` — la redirección + limpieza del service worker.
- `sw.js`, `manifest.json`, `icon-*.png` — restos del PWA viejo, necesarios para
  que el service worker instalado se deje reemplazar.
