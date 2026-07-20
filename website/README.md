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
