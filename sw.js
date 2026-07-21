// Service worker — permite instalar como app y funcionar sin internet.
// Estrategia: red primero (para que los precios nuevos lleguen),
// y si no hay internet, usa la copia guardada.
const CACHE = 'lista-precios-v6';
const FILES = ['./', './index.html', './avisos.json',
               './manifest.json', './icon-192.png', './icon-512.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(FILES)));
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;

  const url = new URL(e.request.url);
  // No tocar la API de Supabase ni ningún otro origen (precios, stock, pagos):
  // siempre a la red, sin guardar en caché, para no mostrar datos viejos.
  if (url.origin !== self.location.origin) {
    return; // deja pasar la petición normal del navegador
  }

  // Archivos propios de la app: red primero, con respaldo a la copia guardada.
  e.respondWith(
    fetch(e.request).then(resp => {
      const copy = resp.clone();
      caches.open(CACHE).then(c => c.put(e.request, copy));
      return resp;
    }).catch(() => caches.match(e.request, { ignoreSearch: true }))
  );
});