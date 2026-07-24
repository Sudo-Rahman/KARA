# KARA — Consignes du dépôt

## Scroll horizontal bord-à-bord

Tout élément d’interface qui défile horizontalement doit avoir un viewport bord-à-bord : le `ScrollView(.horizontal)` ne doit jamais être rogné par le padding horizontal de la page, d’une section ou d’une surface parente. Pendant le geste, son contenu doit pouvoir atteindre visuellement les limites gauche et droite de l’écran.

- Conserver l’alignement de repos du premier et du dernier élément avec le contenu de la page en utilisant des marges de contenu, pas en réduisant le viewport du scroll.
- Utiliser `karaFullBleedHorizontalScroll(pageInset:)` sur chaque scroll horizontal contenu dans une page paddée. `pageInset` est la somme de tous les paddings horizontaux entre le scroll et le bord de l’écran (par exemple padding de page + padding de carte).
- Ajouter au contenu du scroll un léger espace vertical, au minimum 1 pt, pour que les bordures, focus rings et ombres des chips ou cartes ne soient pas coupés.
- Un pager déjà naturellement plein écran, sans padding horizontal parent, est conforme sans compensation supplémentaire.
- Lors de l’ajout ou de la modification d’un scroll horizontal, auditer ses ancêtres et vérifier ce comportement sur les deux bords avant de terminer.

## Règles Git

- Les fichiers situés dans `docs/superpowers/**` sont des documents de travail locaux.
- Ils ne doivent jamais être ajoutés à l'index Git, staged ou commités.
- Avant chaque commit, vérifier avec `git status --short` qu'aucun fichier de ce répertoire n'est suivi.
