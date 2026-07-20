# Kara Landing Page — Design Specification

## Outcome

Créer une landing premium bilingue pour Kara, accompagnée de pages Confidentialité et Support. Le site met en scène un lingot KARA 3D dans une narration continue qui explique l’inventaire, la valorisation, la simulation, les rapports et la confidentialité locale des applications.

## Experience

La page s’ouvre sur « Votre patrimoine. En pleine lumière. ». Le lingot traverse sept chapitres : hero, inventaire, portefeuille, simulation, rapport, confidentialité et téléchargement. Les mockups produit sont construits en HTML/Svelte avec des données fictives réalistes. Aucune preuve sociale ou métrique d’adoption n’est inventée.

## Visual Contract

- Noir neutre, cobalt lumineux, or réservé à la matière.
- Geologica Variable pour toute l’interface ; gravure serif pour le wordmark.
- Un canvas Three.js persistant, piloté par GSAP ScrollTrigger et le scroll natif.
- Même narration 3D sur mobile et desktop ; qualité de rendu seulement réduite sur mobile.
- Repli statique complet pour mouvement réduit, Save-Data ou absence de WebGL.

## Product Claims

- Inventaire des lingots, pièces, bijoux et objets précieux.
- Cours de référence récupérés sans envoyer l’inventaire, avec ajustement manuel.
- Plus-value globale et par objet, simulation indicative avant frais et fiscalité.
- Rapport interactif et PDF généré localement.
- Données sur l’appareil et sauvegarde dans l’espace privé iCloud/Google Drive ; aucun serveur Kara ne reçoit l’inventaire.

## Delivery

Routes françaises et anglaises pour la landing, la confidentialité et le support. Configuration publique centralisée pour les stores, le domaine, l’opérateur et le support. Umami ne mesure que les pages vues et les clics stores, sans cookie, replay ni données personnalisées.
