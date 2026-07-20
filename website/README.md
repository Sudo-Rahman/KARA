# Kara — site web

Landing page bilingue de Kara, une application iOS et Android en préparation pour suivre un patrimoine physique en métaux précieux. Le site est construit avec SvelteKit, Svelte 5, Tailwind CSS 4, Paraglide, Three.js et GSAP ScrollTrigger.

## Configuration

Copier `.env.example` vers `.env` et remplacer les valeurs d’exemple :

- `PUBLIC_SITE_URL` : origine canonique publique du site ;
- `PUBLIC_APP_STORE_URL` : fiche App Store officielle ;
- `PUBLIC_GOOGLE_PLAY_URL` : fiche Google Play officielle ;
- `PUBLIC_SUPPORT_EMAIL` : adresse ouverte par les liens `mailto:` ;
- `PUBLIC_LEGAL_NAME` : nom de l’éditeur du site.

En développement, les valeurs absentes produisent des CTA désactivés et une mention « Bientôt disponible ». Une configuration incomplète ou invalide bloque le build de production.

## Commandes

```bash
pnpm install
pnpm dev
pnpm check
pnpm test:unit --run
pnpm test:e2e
pnpm build
pnpm preview --host 127.0.0.1 --port 4173
pnpm audit:lighthouse
```

L’audit Lighthouse attend un serveur sur `127.0.0.1:4173`. Si Chrome n’est pas détecté automatiquement, définir `CHROME_PATH` vers un exécutable Chromium local.

## Routes

- `/` et `/en` : landing page ;
- `/privacy` et `/en/privacy` : confidentialité ;
- `/support` et `/en/support` : support et informations pré-lancement ;
- `/sitemap.xml` et `/robots.txt` : indexation.

## Scène et confidentialité

Le contrôleur Three.js expose `mount`, `setProgress`, `resize`, `setQuality` et `destroy`. Les profils `high`, `mobile` et `static` sélectionnent le budget graphique sans changer les chapitres. Le mode statique est utilisé sans WebGL, avec Save-Data ou mouvement réduit.

Le site n’accepte aucun inventaire et n’expose aucun formulaire ou API applicative. Umami est le seul service tiers : sans cookie, respect de Do Not Track, paramètres de recherche exclus, sans replay ni heatmap. Les seuls événements personnalisés sont `download_app_store` et `download_google_play`.
