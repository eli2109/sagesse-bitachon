// Injected into flutter_service_worker.js after build (see tool/inject_push_handlers.sh).
// Handles Web Push for the PWA (including iOS Home Screen, Safari 16.4+).

self.addEventListener('push', (event) => {
  let title = 'Sagesse du Bitachon';
  let body = 'Prenez un moment pour lire une phrase de sagesse.';
  let url = self.registration.scope;

  try {
    if (event.data) {
      const data = event.data.json();
      if (data.title) title = data.title;
      if (data.body) body = data.body;
      if (data.url) url = data.url;
    }
  } catch (_) {
    try {
      const text = event.data && event.data.text();
      if (text) body = text;
    } catch (__) {}
  }

  event.waitUntil(
    self.registration.showNotification(title, {
      body: body,
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-192.png',
      data: { url: url },
      renotify: true,
      tag: 'bitachon-reminder',
    }),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const targetUrl =
    (event.notification.data && event.notification.data.url) ||
    self.registration.scope;

  event.waitUntil(
    (async () => {
      const allClients = await clients.matchAll({
        type: 'window',
        includeUncontrolled: true,
      });
      for (const client of allClients) {
        if ('focus' in client) {
          await client.focus();
          if ('navigate' in client) {
            try {
              await client.navigate(targetUrl);
            } catch (_) {}
          }
          return;
        }
      }
      if (clients.openWindow) {
        await clients.openWindow(targetUrl);
      }
    })(),
  );
});
