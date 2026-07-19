import webpush from 'web-push';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS },
  });
}

function configureWebPush(env) {
  const publicKey = env.VAPID_PUBLIC_KEY;
  const privateKey = env.VAPID_PRIVATE_KEY;
  const subject = env.VAPID_SUBJECT || 'mailto:bitachon@example.com';
  if (!publicKey || !privateKey) {
    throw new Error('VAPID keys missing (VAPID_PUBLIC_KEY / VAPID_PRIVATE_KEY)');
  }
  webpush.setVapidDetails(subject, publicKey, privateKey);
}

function subscriptionKey(subscription) {
  return subscription?.endpoint || '';
}

async function listSubscriptions(env) {
  if (!env.SUBSCRIPTIONS) return [];
  const listed = await env.SUBSCRIPTIONS.list();
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
    throw new Error(
      'KV SUBSCRIPTIONS not bound. Create a KV namespace and bind it in wrangler.toml',
    );
  }
  const key = subscriptionKey(subscription);
  if (!key) throw new Error('Invalid subscription: missing endpoint');
  // KV key max length considerations: hash if needed
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

async function sha256(text) {
  const data = new TextEncoder().encode(text);
  const hash = await crypto.subtle.digest('SHA-256', data);
  return [...new Uint8Array(hash)]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

async function sendReminders(env) {
  configureWebPush(env);
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
      await webpush.sendNotification(sub, payload);
      sent += 1;
    } catch (err) {
      failed += 1;
      const code = err?.statusCode;
      // Gone / Not Found → drop subscription
      if (code === 404 || code === 410) {
        removals.push(sub);
      }
      console.error('push failed', code, err?.message);
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

      // Manual trigger (optional): POST /send with header X-Admin-Token
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
