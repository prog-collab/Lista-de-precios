// Service worker de despedida — la app se mudó a camerino.com.ar/gestion.
// El único trabajo que le queda es borrarse a sí mismo y su caché: mientras
// exista, los celulares que todavía tengan el acceso directo viejo podrían
// seguir abriendo la app vieja sin internet, sin enterarse de la mudanza.
self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', e => {
  e.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.map(k => caches.delete(k)));
    await self.registration.unregister();
    const clients = await self.clients.matchAll({ type: 'window' });
    clients.forEach(c => c.navigate(c.url));
  })());
});
