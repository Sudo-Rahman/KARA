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

## Clavier et focus

Tous les écrans de saisie doivent permettre de fermer le clavier de manière cohérente et évidente.

- En dehors des écrans d’ajout et de modification d’un actif, utiliser le modificateur commun `karaDismissibleKeyboard(focusedField:)` sur le conteneur de saisie.
- Le comportement commun doit fermer le clavier uniquement lorsqu’un tap sur une zone non interactive retire le focus du champ.
- Un défilement, même rapide, ne doit jamais fermer le clavier. Il doit rester possible de consulter le reste du formulaire sans perdre le champ actif.
- Ne pas ajouter de bouton « Terminé » au-dessus du clavier : les actions persistantes du formulaire restent seules dans la barre inférieure.
- La fermeture du clavier doit uniquement retirer le focus. Elle ne doit ni modifier la valeur saisie, ni valider le formulaire, ni déclencher une navigation.
- Le geste de fermeture ne doit jamais intercepter les champs, boutons, liens, pickers, toggles ou steppers.
- Les écrans d’ajout et de modification d’un actif sont explicitement exclus de ce comportement commun jusqu’à leur traitement dédié.
- Lors de l’ajout ou de la modification d’un écran de saisie, tester au minimum la fermeture par tap extérieur, la conservation du clavier pendant le défilement et le pavé numérique lorsqu’il est utilisé.

## Couleurs des contrôles de saisie

Les contrôles interactifs posés sur une surface cobalt doivent utiliser `cobaltBright`, jamais le gold, pour leur contenu.

- Utiliser `karaCobaltControlSurface()` pour les `Picker`, sélecteurs et contrôles comparables sur fond cobalt.
- La valeur affichée, le texte, le tint et les icônes interactives d’un contrôle sur fond cobalt doivent être en `cobaltBright`.
- Les `DatePicker`, y compris leur valeur compacte et leur calendrier, doivent utiliser le tint `cobaltBright`.
- Utiliser `karaTextInputSurface()` pour les champs de saisie textuelle standards afin d’harmoniser leur surface, leur texte et la couleur du curseur.
- Ne pas laisser un contrôle de saisie hériter implicitement du tint gold global de l’application.
- Lors de l’ajout ou de la modification d’un contrôle, vérifier ses états normal, sélectionné, désactivé et contraste renforcé.

## Règles Git

- Les fichiers situés dans `docs/superpowers/**` sont des documents de travail locaux.
- Ils ne doivent jamais être ajoutés à l'index Git, staged ou commités.
- Avant chaque commit, vérifier avec `git status --short` qu'aucun fichier de ce répertoire n'est suivi.
