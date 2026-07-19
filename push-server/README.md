# Serveur Web Push — Sagesse Bitachon

Envoie un rappel **toutes les 3 heures** aux abonnements Web Push (PWA iOS / navigateur).

## Prérequis

1. Compte gratuit [Cloudflare](https://dash.cloudflare.com/sign-up)
2. Node.js 20+
3. Clés VAPID (déjà générées pour ce projet ; la **clé privée** est dans `.dev.vars`, non versionnée)

## Déploiement (une fois)

```bash
cd push-server
npm install

# Connexion Cloudflare (navigateur)
npx wrangler login

# Créer le stockage des abonnements
npx wrangler kv namespace create SUBSCRIPTIONS
# Copier l'id affiché dans wrangler.toml :
# [[kv_namespaces]]
# binding = "SUBSCRIPTIONS"
# id = "...."

# Secrets
npx wrangler secret put VAPID_PRIVATE_KEY
# coller la clé privée (fichier .dev.vars en local)
npx wrangler secret put ADMIN_TOKEN
# mot de passe au choix pour déclencher un envoi manuel

# Variables optionnelles
npx wrangler secret put APP_URL
# https://eli2109.github.io/sagesse-bitachon/

npx wrangler deploy
```

L’URL du worker ressemble à :

`https://sagesse-bitachon-push.<votre-compte>.workers.dev`

## Brancher la webapp

Éditez `assets/push_config.json` :

```json
{
  "vapidPublicKey": "BDOHuJxy-7QveDgDGewF8cj3b9zMjuTl3lpwEfZfjdfvhXvMKJ7Sukc1iQXZMgnmxJrisOdarHQGUMQMAm2OzIo",
  "apiBaseUrl": "https://sagesse-bitachon-push.VOTRE_COMPTE.workers.dev",
  "appUrl": "https://eli2109.github.io/sagesse-bitachon/"
}
```

Puis rebuild + redeploy GitHub Pages.

## Endpoints

| Méthode | Chemin | Rôle |
|---------|--------|------|
| GET | `/health` | Santé + KV |
| POST | `/subscribe` | Enregistre un abonnement |
| POST | `/unsubscribe` | Supprime un abonnement |
| POST | `/send` | Envoi immédiat (header `X-Admin-Token`) |
| Cron | `0 */3 * * *` | Rappels automatiques |

## Test manuel

```bash
curl -X POST https://VOTRE_WORKER/send \
  -H "X-Admin-Token: VOTRE_TOKEN"
```
