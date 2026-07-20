# Kara Design System

## Direction

La landing est une chambre forte lumineuse : une scène noire neutre, traversée par un cobalt instrumental, où l’or n’apparaît que comme matière ou action importante. Le lingot gravé KARA relie tous les chapitres. Les interfaces produit ressemblent à des instruments précis, jamais à des cartes en verre flottantes.

## Color

Toutes les couleurs sont définies en OKLCH.

| Token | Valeur | Rôle |
| --- | --- | --- |
| `--color-void` | `oklch(0.075 0 0)` | Fond principal neutre |
| `--color-ink` | `oklch(0.965 0.006 95)` | Texte principal |
| `--color-muted` | `oklch(0.69 0.014 258)` | Texte secondaire accessible |
| `--color-surface` | `oklch(0.125 0.012 258)` | Surface produit |
| `--color-surface-raised` | `oklch(0.17 0.016 258)` | Élévation en mode sombre |
| `--color-line` | `oklch(0.29 0.018 258)` | Bordures et séparateurs |
| `--color-cobalt` | `oklch(0.56 0.18 258)` | Identité, actions et lumière |
| `--color-cobalt-bright` | `oklch(0.72 0.15 258)` | Tracés et détails lumineux |
| `--color-gold` | `oklch(0.80 0.13 88)` | Matière, valeur et accent rare |
| `--color-positive` | `oklch(0.76 0.13 153)` | Performance positive |

Le cobalt porte la majorité de la couleur de marque. L’or reste rare. Aucun texte courant gris n’est posé sur une surface cobalt ; le texte y est blanc.

## Typography

- Famille principale : Geologica Variable, auto-hébergée, poids 350 à 650.
- Gravure et wordmark : Georgia, utilisée uniquement pour `KARA` et la matière 3D.
- Display : `clamp(3rem, 7vw, 6rem)`, interlettrage minimum `-0.04em`, graisse 440.
- Titres de section : `clamp(2.25rem, 5vw, 4.5rem)`, graisse 450.
- Corps : `1rem`, hauteur de ligne `1.65`, largeur maximale `68ch`.
- Données : chiffres tabulaires, corps fixe, aucune taille fluide dans les mockups produit.

## Spacing & Layout

Échelle 4 pt : 4, 8, 12, 16, 24, 32, 48, 64, 96 et 144 px. Les espacements de page sont fluides avec `clamp()`. La landing alterne des chapitres plein écran généreux et des interfaces plus denses. Les composants interactifs ont une cible minimale de 44 × 44 px.

Le contenu utilise un conteneur maximal de 1280 px. Mobile commence à 320 px, tablette à 768 px et desktop à 1024 px, avec des ruptures supplémentaires uniquement lorsque la composition le demande.

## Components

- Navigation : barre sobre, wordmark, ancres principales, langue et CTA.
- Store CTA : badges officiels, état actif et état désactivé explicite en développement.
- App mockups : surfaces nettes, rayon de 12 à 16 px maximum, bordure ou ombre mais jamais les deux comme décoration.
- Chapters : une idée dominante par séquence, composition variable, aucun quadrillage répétitif de cartes.
- Legal pages : même matière et même typographie, mouvement réduit et mesure de lecture confortable.

## Motion

Une timeline continue Three.js/GSAP associe chaque changement de caméra, de lumière et d’objet à une idée produit. Le scroll reste natif. Les micro-interactions utilisent `ease-out-quart`, `ease-out-quint` ou `ease-out-expo`, sans rebond.

Desktop et mobile contiennent les mêmes scènes. Le profil mobile réduit seulement DPR, ombres, antialiasing et post-traitement. `prefers-reduced-motion`, Save-Data ou WebGL indisponible affichent des compositions statiques complètes.

## Responsive Behavior

- Mobile : cadrage portrait propre, texte au premier plan, canvas en arrière-plan, navigation compacte et QR codes masqués.
- Tablette : compositions hybrides à deux zones lorsque l’espace le permet.
- Desktop : asymétrie plus ample, mockups et objet visibles simultanément, QR codes affichés.
- Paysage mobile : hauteur de section réduite sans supprimer de chapitre.

## Accessibility

Focus cobalt très visible, structure sémantique, liens autonomes, libellés explicites et contraste AA minimum. Aucun contenu n’est initialement masqué dans l’attente d’un reveal JavaScript.
