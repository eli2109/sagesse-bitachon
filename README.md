# Sagesse du Bitachon

Web app Flutter pour lire, une à une, des phrases et résumés d'idées issus du Shaar HaBitachon (Chovot HaLevavot). Les phrases défilent dans un ordre mélangé, sans répétition avant la fin du cycle, avec **sauvegarde locale** de la progression (navigateur).

## Prérequis

- Flutter 3.x (stable)
- Un navigateur moderne (Safari iOS, Chrome, Firefox…)

## Lancer en développement (web)

```bash
cd sagesse_bitachon
flutter pub get
flutter run -d chrome
# ou : flutter run -d web-server --web-port 8080
```

## Build web (production)

```bash
flutter build web --release
```

Sortie : `build/web/`

## Déploiement Vercel

1. Pousse le dépôt sur GitHub.
2. Sur [vercel.com](https://vercel.com) : **Add New Project** → importe le repo.
3. Vercel lit `vercel.json` :
   - **Build Command** : `bash tool/build_web.sh` (installe Flutter si besoin)
   - **Output Directory** : `build/web`
4. Deploy.

Le premier build peut prendre plusieurs minutes (téléchargement du SDK Flutter).

### Déploiement local vers Vercel (optionnel)

```bash
flutter build web --release
npx vercel --prod
# pointer le dossier de sortie sur build/web si demandé
```

## Mémoire locale

La progression (ordre du cycle, position, taille de police) est stockée dans le navigateur via `shared_preferences` → `localStorage` sur le web.

- Même URL + même navigateur → la position est conservée
- Vider les données du site / navigation privée → réinitialisation possible
- Pas de compte, pas de serveur, pas de base de données

Sur **iPhone** : ouvre le lien dans Safari. Optionnel : Partager → **Sur l'écran d'accueil** pour une icône type app.

## Ajouter ou modifier des phrases

1. Édite `assets/phrases.json` (tableau JSON de chaînes).
2. Rebuild / redéploie.

## Rappels iOS (PWA + Web Push)

Sur iPhone, les rappels **toutes les 3 h** passent par :

1. **Ajouter à l’écran d’accueil** (Safari → Partager → Sur l’écran d’accueil)
2. Ouvrir l’app **depuis l’icône** (pas depuis un onglet Safari)
3. Icône **cloche** → **Activer les rappels**
4. Un **serveur Web Push** qui envoie le rappel (Cloudflare Worker, gratuit) — voir `push-server/README.md`

Sans l’étape 4 (`apiBaseUrl` dans `assets/push_config.json`), l’UI explique que le serveur n’est pas configuré.

Exigences Apple : **iOS 16.4+**, PWA installée, permission notifications acceptée.

App en ligne : https://eli2109.github.io/sagesse-bitachon/

## Fonctionnalités

- Affichage d'une phrase à la fois
- Bouton « Suivant » avec cycle mélangé et reshuffle en fin de cycle
- Persistance locale (web et mobile)
- Progression : « Phrase X / Y dans ce cycle »
- Copie (long-press ou bouton)
- Taille de police réglable (mémorisée)
- Thème Material 3 clair/sombre
- Message de bienvenue à la première ouverture
- Rappels Web Push PWA (iOS Home Screen / navigateurs compatibles) via cloche + `push-server`
- (Android natif) rappels locaux toutes les 3 h

## Structure

```
lib/
├── main.dart
├── models/reading_state.dart
├── services/
│   ├── phrase_service.dart
│   ├── font_size_service.dart
│   └── notification_service*.dart
└── widgets/phrase_display.dart
assets/
└── phrases.json
web/
├── index.html
└── manifest.json
tool/
└── build_web.sh
vercel.json
```
