# KARA — Consignes du dépôt

## Scroll horizontal bord-à-bord

Un scroll horizontal doit occuper toute la largeur de son conteneur visuel : pendant le geste, son contenu peut traverser le padding interne et atteindre visuellement les limites gauche et droite de ce conteneur.

- Le conteneur visuel de référence est la surface la plus proche (carte, champ groupé, panneau, modal). En l’absence de surface, c’est la page ou l’écran. Le viewport peut neutraliser le padding de ce conteneur, mais ne doit jamais franchir son fond ou ses coins arrondis.
- Conserver l’alignement de repos du premier et du dernier élément avec le contenu paddé du conteneur en utilisant des marges de contenu, pas en réduisant le viewport du scroll.
- Dans une surface paddée, utiliser `karaSurfaceEdgeHorizontalScroll(surfaceInset:)` avec uniquement le padding interne de cette surface.
- Au niveau d’une page paddée, utiliser `karaFullBleedHorizontalScroll(pageInset:)` avec la somme des paddings horizontaux entre le scroll et le bord de l’écran.
- Ajouter au contenu du scroll un léger espace vertical, au minimum 1 pt, pour que les bordures, focus rings et ombres des chips ou cartes ne soient pas coupés.
- Un pager déjà naturellement plein écran, sans padding horizontal parent, est conforme sans compensation supplémentaire.
- Lors de l’ajout ou de la modification d’un scroll horizontal, auditer ses ancêtres, identifier la surface visuelle la plus proche, puis vérifier son comportement sur les deux bords avant de terminer.

## Dialogues de confirmation

Toute confirmation doit apparaître dans un dialogue centré au milieu de l’écran, sans flèche ni ancrage visuel vers le contrôle qui a déclenché l’action.

- En SwiftUI, utiliser `.alert` pour demander une confirmation.
- Ne jamais utiliser `confirmationDialog` pour demander une confirmation. `confirmationDialog` et `Menu` restent autorisés uniquement pour présenter un choix d’actions qui ne constitue pas lui-même une confirmation.
- Une confirmation destructive doit comporter un titre explicite, un message décrivant la conséquence, une action destructive et une action d’annulation.
- Dans la corbeille, la suppression définitive d’un élément à l’unité est immédiate et ne demande jamais de confirmation. Seule l’action globale « Tout supprimer » demande confirmation.
- Lors de l’ajout ou de la modification d’une action nécessitant une confirmation, auditer le type de présentation et le comportement d’annulation avant de terminer.

## Règles Git

- Les fichiers situés dans `docs/superpowers/**` sont des documents de travail locaux.
- Ils ne doivent jamais être ajoutés à l'index Git, staged ou commités.
- Avant chaque commit, vérifier avec `git status --short` qu'aucun fichier de ce répertoire n'est suivi.
