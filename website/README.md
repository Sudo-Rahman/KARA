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

Le registre App Attest nécessite également quatre variables privées :

- `REDIS_URL` : connexion au Redis persistant, de préférence `rediss://` hors réseau privé ;
- `APP_ATTEST_TEAM_ID` : identifiant Apple Developer, actuellement `LBPZB5S37F` ;
- `APP_ATTEST_BUNDLE_ID` : bundle iOS, actuellement `com.karaprivate.KARA` ;
- `APP_ATTEST_ENVIRONMENT` : `development` sur le backend de développement et `production` sur le backend TestFlight/App Store.

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
- `REDIS_URL` ;
- `APP_ATTEST_TEAM_ID` ;
- `APP_ATTEST_BUNDLE_ID` ;
- `APP_ATTEST_ENVIRONMENT`.

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
- `/auth/app-attest/challenges` et `/auth/app-attest/registrations` : enrôlement et challenges iOS publics ;
- `/healthz` et `/readyz` : liveness publique et readiness Redis ;
- `/v1/manifest.json` : version et couverture du snapshot mensuel, protégé par App Attest ;
- `/v1/metals-monthly.json` : historique mensuel complet, protégé par App Attest ;
- `/v1/metals-spot.json?metal=XAU&currency=EUR` : cours temps réel par once troy, protégé par App Attest.

## App Attest et Redis

Toutes les routes `/v1/**`, méthodes `GET` et `HEAD` comprises, exigent les
headers `X-Kara-App-Attest-Key-Id`, `X-Kara-App-Attest-Challenge-Id` et
`X-Kara-App-Attest-Assertion`. Un challenge expire après cinq minutes et ne peut
être consommé qu'une fois. Le client signe une représentation canonique de la
méthode, du chemin, de la query triée et du SHA-256 du corps.

Redis contient uniquement les clés publiques App Attest, compteurs et challenges.
Dans Dokploy, utiliser une instance non exposée à Internet, un volume persistant,
la journalisation AOF (`appendonly yes`, `appendfsync everysec`) et une sauvegarde
régulière. Une panne Redis rend `/readyz` indisponible et les routes protégées
répondent `503`, sans provoquer de rotation de clé côté iOS.

Une perte réelle du registre renvoie `unknown_app_attest_key`. L'application crée
alors automatiquement une nouvelle clé et refait l'attestation une seule fois.
Restaurer une sauvegarde reste préférable afin d'éviter un réenrôlement massif et
le throttling Apple.

Les erreurs d'authentification utilisent un corps JSON stable avec les codes
`app_attest_required`, `unknown_app_attest_key`,
`invalid_app_attest_registration`, `invalid_app_attest_assertion`,
`expired_app_attest_challenge`, `replayed_app_attest_assertion` et
`app_attest_store_unavailable`. Seul `unknown_app_attest_key` déclenche une
rotation côté iOS ; une indisponibilité `503` conserve l'identité existante.

### Activation Apple

Activer App Attest sur l'App ID `com.karaprivate.KARA` dans Certificates,
Identifiers & Profiles, puis rafraîchir les profils de provisioning. La cible
utilise l'environnement `development` en Debug et `production` en Release. Les
builds Debug utilisent `http://127.0.0.1:3000` par défaut ; remplacer le build
setting `KARA_API_BASE_URL` par l'URL HTTPS joignable du backend de développement
pour les essais sur appareil physique. Les
tests de bout en bout doivent être effectués sur un appareil physique ; le
simulateur utilise les doubles injectés dans les tests et ne bénéficie d'aucun
bypass sur le backend de production.

Déployer dans l'ordre : Redis, endpoints `/auth/app-attest/**`, version iOS
compatible, puis protection de `/v1/**`. Le dépôt étant en pré-lancement, la
protection est actuellement activée sans mode de compatibilité hérité.

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

`GOLD_API_KEY` est une variable privée obligatoire chargée au runtime. Le serveur
la transmet uniquement à Gold API dans l'en-tête `x-api-key` ; elle n'est ni
intégrée au build, ni renvoyée dans les réponses publiques, ni inscrite dans les
logs applicatifs.

### Diagnostic du cours temps réel

Lorsqu'un appel Gold API échoue, le serveur écrit sur `stderr` un événement
`[metals-spot] Gold API request failed`. Il contient l'identifiant de requête,
le métal, la devise, le statut HTTP éventuel et la chaîne limitée des causes
réseau. La réponse `502` expose le même identifiant dans `X-Request-Id` pour
retrouver immédiatement le bon événement dans les logs Dokploy. La clé API, les
headers sortants et le corps de la réponse Gold API ne sont jamais journalisés.

## Scène et confidentialité

Le contrôleur Three.js expose `mount`, `setProgress`, `resize`, `setQuality` et `destroy`. Les profils `high`, `mobile` et `static` sélectionnent le budget graphique sans changer les chapitres. Le mode statique est utilisé sans WebGL, avec Save-Data ou mouvement réduit.

Le site n’accepte aucun inventaire et l'API n'expose que des données de marché
publiques. Umami est le seul service tiers : sans cookie, respect de Do Not
Track, paramètres de recherche exclus, sans replay ni heatmap. Les seuls
événements personnalisés sont `download_app_store` et `download_google_play`.
