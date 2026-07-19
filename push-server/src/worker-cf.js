/**
 * Cloudflare Worker — Sagesse Bitachon Web Push reminders (every 3h).
 */
import { buildPushPayload } from '@block65/webcrypto-web-push';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, X-Admin-Token',
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS },
  });
}

async function sha256(text) {
  const data = new TextEncoder().encode(text);
  const hash = await crypto.subtle.digest('SHA-256', data);
  return [...new Uint8Array(hash)]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function subscriptionKey(subscription) {
  return subscription?.endpoint || '';
}

async function listSubscriptions(env) {
  if (!env.SUBSCRIPTIONS) return [];
  const listed = await env.SUBSCRIPTIONS.list({ limit: 1000 });
  const out = [];
  for (const key of listed.keys) {
    const raw = await env.SUBSCRIPTIONS.get(key.name);
    if (!raw) continue;
    try {
      out.push(JSON.parse(raw));
    } catch (_) {}
  }
  return out;
}

async function saveSubscription(env, subscription) {
  if (!env.SUBSCRIPTIONS) {
    throw new Error('KV SUBSCRIPTIONS not bound');
  }
  const key = subscriptionKey(subscription);
  if (!key) throw new Error('Invalid subscription: missing endpoint');
  const id = await sha256(key);
  await env.SUBSCRIPTIONS.put(
    id,
    JSON.stringify({
      ...subscription,
      updatedAt: new Date().toISOString(),
    }),
  );
  return id;
}

async function removeSubscription(env, subscription) {
  if (!env.SUBSCRIPTIONS) return false;
  const key = subscriptionKey(subscription);
  if (!key) return false;
  const id = await sha256(key);
  await env.SUBSCRIPTIONS.delete(id);
  return true;
}

function vapidFromEnv(env) {
  const publicKey = env.VAPID_PUBLIC_KEY;
  const privateKey = env.VAPID_PRIVATE_KEY;
  const subject = env.VAPID_SUBJECT || 'mailto:bitachon@example.com';
  if (!publicKey || !privateKey) {
    throw new Error('VAPID keys missing');
  }
  return { subject, publicKey, privateKey };
}

async function sendReminders(env) {
  const vapid = vapidFromEnv(env);
  const subs = await listSubscriptions(env);
  const payload = JSON.stringify({
    title: 'Sagesse du Bitachon',
    body: 'Prenez un moment pour lire une phrase de sagesse.',
    url: env.APP_URL || 'https://eli2109.github.io/sagesse-bitachon/',
  });

  let sent = 0;
  let failed = 0;
  const removals = [];

  for (const sub of subs) {
    try {
      const subscription = {
        endpoint: sub.endpoint,
        expirationTime: sub.expirationTime ?? null,
        keys: {
          p256dh: sub.keys.p256dh,
          auth: sub.keys.auth,
        },
      };
      const message = {
        data: payload,
        options: { ttl: 60 * 60 * 12 },
      };
      const init = await buildPushPayload(message, subscription, vapid);
      const res = await fetch(subscription.endpoint, init);
      if (res.status === 404 || res.status === 410) {
        removals.push(sub);
        failed += 1;
      } else if (!res.ok) {
        failed += 1;
        console.error('push failed', res.status, await res.text());
      } else {
        sent += 1;
      }
    } catch (err) {
      failed += 1;
      console.error('push error', err?.message || err);
    }
  }

  for (const sub of removals) {
    try {
      await removeSubscription(env, sub);
    } catch (_) {}
  }

  return { total: subs.length, sent, failed, removed: removals.length };
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS });
    }

    const url = new URL(request.url);

    try {
      if (request.method === 'GET' && url.pathname === '/health') {
        return json({
          ok: true,
          kv: Boolean(env.SUBSCRIPTIONS),
          vapidPublicKeyConfigured: Boolean(env.VAPID_PUBLIC_KEY),
          vapidPrivateKeyConfigured: Boolean(env.VAPID_PRIVATE_KEY),
        });
      }

      if (request.method === 'GET' && url.pathname === '/vapidPublicKey') {
        return json({ publicKey: env.VAPID_PUBLIC_KEY || null });
      }

      if (request.method === 'POST' && url.pathname === '/subscribe') {
        const body = await request.json();
        const subscription = body.subscription || body;
        if (!subscription?.endpoint || !subscription?.keys) {
          return json({ error: 'Invalid subscription body' }, 400);
        }
        const id = await saveSubscription(env, subscription);
        return json({ ok: true, id });
      }

      if (request.method === 'POST' && url.pathname === '/unsubscribe') {
        const body = await request.json();
        const subscription = body.subscription || body;
        await removeSubscription(env, subscription);
        return json({ ok: true });
      }

      if (request.method === 'POST' && url.pathname === '/send') {
        const token = request.headers.get('X-Admin-Token');
        if (!env.ADMIN_TOKEN || token !== env.ADMIN_TOKEN) {
          return json({ error: 'Unauthorized' }, 401);
        }
        const result = await sendReminders(env);
        return json({ ok: true, ...result });
      }

      return json({ error: 'Not found' }, 404);
    } catch (err) {
      console.error(err);
      return json({ error: err.message || String(err) }, 500);
    }
  },

  async scheduled(_event, env, ctx) {
    ctx.waitUntil(
      sendReminders(env).then((r) => console.log('cron reminders', r)),
    );
  },
};
