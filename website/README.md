# Kara — site web

Landing page bilingue de Kara, une application iOS et Android en préparation pour suivre un patrimoine physique en métaux précieux. Le site est construit avec SvelteKit, Svelte 5, Tailwind CSS 4, Paraglide, Three.js et GSAP ScrollTrigger.

## Configuration

Copier `.env.example` vers `.env` et remplacer les valeurs d’exemple :

- `PUBLIC_SITE_URL` : origine canonique publique du site ;
- `PUBLIC_APP_STORE_URL` : fiche App Store officielle ;
- `PUBLIC_GOOGLE_PLAY_URL` : fiche Google Play officielle ;
- `PUBLIC_SUPPORT_EMAIL` : adresse ouverte par les liens `mailto:` ;
- `PUBLIC_LEGAL_NAME` : nom de l’éditeur du site.

`METALS_DATA_MANIFEST_URL` est optionnelle. Elle permet à un fork de remplacer
la source publique Kara utilisée par le cache des métaux.

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

## Déploiement Docker avec Dokploy

L'image utilise Node.js 26.5.0 sur Alpine 3.24 et pnpm 11.15.1 pour la
compilation multistage. L'image finale ne contient que le serveur SvelteKit, ses
dépendances de production et les fichiers compilés. Le processus s'exécute avec
l'utilisateur non privilégié `node` sur le port `3000`.

Dans Dokploy, sélectionner le type de build `Dockerfile`, puis configurer :

- `Build Path` : `/` (racine du dépôt) ;
- `Dockerfile Path` : `website/Dockerfile` ;
- `Docker Context Path` : `website` ;
- `Docker Build Stage` : laisser vide ;
- port interne de l'application : `3000`.

Toutes les variables sont exclusivement fournies au conteneur au runtime. Ne
configurer aucun argument de build. Variables requises :

- `PUBLIC_SITE_URL` ;
- `PUBLIC_APP_STORE_URL` ;
- `PUBLIC_GOOGLE_PLAY_URL` ;
- `PUBLIC_SUPPORT_EMAIL` ;
- `PUBLIC_LEGAL_NAME` ;
- `ORIGIN`, avec l'origine HTTPS publique du site.

`METALS_DATA_MANIFEST_URL` reste optionnelle. `HOST`, `PORT`, `NODE_ENV` et
`SHUTDOWN_TIMEOUT` possèdent déjà des valeurs adaptées dans l'image. Une
configuration publique manquante ou invalide arrête immédiatement le serveur au
démarrage, mais n'est pas nécessaire pour construire l'image.

Construction et test local :

```bash
docker build --tag kara-website ./website
docker run --rm --publish 3000:3000 \
  --env-file ./website/.env \
  --env ORIGIN=http://localhost:3000 \
  kara-website
```

## Routes

- `/` et `/en` : landing page ;
- `/privacy` et `/en/privacy` : confidentialité ;
- `/support` et `/en/support` : support et informations pré-lancement ;
- `/sitemap.xml` et `/robots.txt` : indexation.
- `/v1/manifest.json` : version et couverture du snapshot mensuel ;
- `/v1/metals-monthly.json` : historique mensuel complet ;
- `/v1/metals-spot.json?metal=XAU&currency=EUR` : cours temps réel par once troy.

## Cache des métaux

Le serveur démarre avec un snapshot valide embarqué, puis vérifie le manifeste
public au démarrage et toutes les douze heures. Une nouvelle publication ne
remplace le cache en mémoire qu'après validation de son schéma, de sa taille et
de son SHA-256. Une panne réseau ou une publication invalide conserve la dernière
version valide. Les requêtes API lisent uniquement la mémoire et ne déclenchent
aucun téléchargement GitHub.

Le générateur mensuel se trouve dans `data-pipeline/`. Le workflow GitHub
`Update monthly metals data` s'exécute tous les jours à 05:17 UTC, télécharge
les sources FMI et Eurostat, valide le snapshot, puis met à jour uniquement
`data/v1/manifest.json` et `data/v1/metals-monthly.json` lorsque le SHA-256
change. Un retard d'un mois du FMI est traité comme une attente normale sans
commit ; un retard supérieur à un mois fait échouer le workflow.

Le cours temps réel accepte `XAU`, `XAG`, `XPT` et `XPD`, ainsi que les devises
`USD`, `EUR`, `GBP`, `JPY`, `CAD`, `AUD`, `CHF`, `CNY`, `HKD`, `SGD`, `SEK`,
`NOK`, `DKK`, `NZD`, `MXN`, `INR`, `BRL`, `ZAR` et `KRW`. Chaque couple
métal/devise est conservé en mémoire pendant 60 secondes. Les appels concurrents
identiques sont regroupés. Si Gold API est momentanément indisponible, la dernière
valeur valide peut être servie pendant cinq minutes supplémentaires avec
`X-Cache: STALE` et un en-tête HTTP `Warning`.

L'endpoint temps réel public de Gold API ne nécessite actuellement aucune clé.
La variable privée utilisée pour les endpoints historiques ou OHLC n'est donc
ni lue, ni transmise, ni exposée par cette route.

## Scène et confidentialité

Le contrôleur Three.js expose `mount`, `setProgress`, `resize`, `setQuality` et `destroy`. Les profils `high`, `mobile` et `static` sélectionnent le budget graphique sans changer les chapitres. Le mode statique est utilisé sans WebGL, avec Save-Data ou mouvement réduit.

Le site n’accepte aucun inventaire et l'API n'expose que des données de marché
publiques. Umami est le seul service tiers : sans cookie, respect de Do Not
Track, paramètres de recherche exclus, sans replay ni heatmap. Les seuls
événements personnalisés sont `download_app_store` et `download_google_play`.
