# Refonte de l’onboarding KARA

Date : 29 juillet 2026
Statut : design validé, en attente de validation de la spécification

## Résumé

KARA remplace son onboarding actuel — une même image plein écran accompagnée de titres, avec trois textes descriptifs présents dans les traductions mais non rendus — par un parcours de cinq pages qui montre concrètement le produit.

Le nouveau parcours :

1. installe la promesse de marque avec le lingot KARA existant ;
2. montre comment un objet devient une fiche documentée ;
3. montre la valorisation et les principales capacités d’analyse ;
4. permet de demander immédiatement les trois autorisations utiles ;
5. recueille séparément le consentement à l’analyse assistée, puis ouvre le tableau de bord.

L’onboarding reste facultatif, balayable, rejouable depuis les Réglages et accessible. Il ne crée aucune donnée d’exemple dans SwiftData ou iCloud.

## Objectifs

- Expliquer en moins d’une minute ce que KARA permet de faire.
- Montrer de vrais exemples visuels au lieu d’une suite de slogans.
- Relier clairement la photographie, la documentation, la valorisation, l’analyse, les alertes et la confidentialité.
- Demander les autorisations système depuis l’onboarding lorsque l’utilisateur choisit de les activer.
- Obtenir un consentement explicite et indépendant pour l’envoi volontaire de médias vers OpenAI.
- Terminer par une arrivée cohérente sur le tableau de bord vide.
- Conserver l’identité visuelle premium et calme de KARA, sans esthétique de trading.

## Hors périmètre

- Créer un actif d’exemple persistant ou préremplir l’inventaire.
- Forcer l’ajout du premier actif avant d’accéder à l’application.
- Reconcevoir l’ensemble du tableau de bord, de la création d’actif ou des Réglages.
- Demander une autorisation Photos ou Fichiers : `PhotosPicker` et les sélecteurs système utilisés par KARA n’exigent pas un accès global à ces bibliothèques.
- Ajouter une autorisation de suivi publicitaire, de localisation ou de contacts ; KARA n’utilise pas ces capacités.

## Principes produit retenus

Apple recommande un onboarding rapide, facultatif et centré sur une vue d’ensemble du produit. Une autorisation peut faire partie de l’onboarding quand sa valeur est expliquée, mais elle ne doit pas être nécessaire pour accéder aux fonctions qui peuvent marcher sans elle.

Références :

- [Human Interface Guidelines — Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding)
- [Human Interface Guidelines — Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy)
- [Asking permission to use notifications](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)
- [App Review Guidelines — Privacy](https://developer.apple.com/app-store/review/guidelines/)

Le parcours respecte ces principes de la manière suivante :

- un bouton visible « Passer » laisse toujours accéder à KARA ;
- aucune demande système ne se lance automatiquement à l’apparition d’une page ;
- l’utilisateur déclenche chaque demande depuis une ligne qui en décrit le bénéfice ;
- un refus n’empêche jamais de continuer ;
- les demandes restent disponibles dans leur contexte fonctionnel si l’onboarding a été passé ;
- les médias d’illustration ne sont jamais enregistrés comme données utilisateur.

## Architecture de l’écran

`OnboardingView` reste la racine de la fonctionnalité et conserve les callbacks existants `onFinish` et `onSkip`.

Sa composition devient :

1. une barre supérieure avec le wordmark KARA et « Passer » ;
2. un pager horizontal plein écran ;
3. une zone inférieure persistante avec la progression et l’action principale.

Le pager n’a pas de padding horizontal parent. Il est donc naturellement bord-à-bord et respecte les règles du dépôt sans compensation supplémentaire. Chaque page applique son propre inset de contenu.

Chaque page peut défiler verticalement lorsque Dynamic Type ou une petite hauteur d’écran l’exige. La zone d’action inférieure reste disponible sans recouvrir le contenu. Les pages ne contiennent pas de second scroll horizontal.

Les responsabilités sont séparées :

- `OnboardingView` : navigation, progression, fin et abandon ;
- `OnboardingPage` : structure commune d’une page ;
- illustrations dédiées : fiche d’actif, tableau de bord d’exemple, configuration des accès et suggestions ;
- `OnboardingPermissionsModel` : lecture des états et orchestration asynchrone des trois demandes système ;
- préférences existantes : consentement IA et verrouillage de l’application.

## Parcours détaillé

### Page 1 — Promesse

But : donner immédiatement la raison d’être de KARA.

- Conserver `OnboardingBackgroundRevelation` en plein écran.
- Afficher le wordmark KARA.
- Titre : « Votre patrimoine. En pleine lumière. »
- Corps : KARA inventorie les métaux précieux, suit leur valeur et conserve les justificatifs.
- Action : « Découvrir KARA ».
- L’image du lingot est utilisée uniquement comme scène principale de cette page.

### Page 2 — Inventaire documenté

But : montrer le premier geste et le résultat obtenu.

- Fond sombre KARA avec lumière cobalt discrète.
- Réutiliser les illustrations existantes de pièce, lingot et bijou.
- Montrer une fiche d’exemple clairement identifiée comme illustration :
  - Napoléon 20 francs ;
  - or ;
  - 6,45 g ;
  - lieu de conservation ;
  - valeur estimée d’exemple.
- Montrer le chemin « Photographier → Compléter → Conserver ».
- Expliquer que photos, caractéristiques, facture, certificat et emplacement restent liés au même actif.
- Action : « Continuer ».

L’exemple est un pur modèle de présentation. Il n’utilise pas `Asset`, n’est jamais enregistré et ne peut pas apparaître ensuite dans le coffre.

### Page 3 — Valeur et décisions

But : démontrer la valeur récurrente du produit.

- Afficher un tableau de bord compact d’exemple avec :
  - valeur estimée ;
  - gain et pourcentage signés ;
  - évolution visuelle ;
  - nombre d’actifs ;
  - couverture de valorisation.
- Mentionner les capacités suivantes sans les transformer en menu interactif :
  - performance ;
  - répartition ;
  - simulation de vente ;
  - rapports.
- Ajouter un libellé « Exemple » pour éviter que les montants soient interprétés comme des données réelles.
- Action : « Continuer ».

### Page 4 — Configuration des accès

But : configurer immédiatement les accès utiles, sans empiler les dialogues système.

Titre : « Prêt pour vous, protégé par vous. »

La page contient une checklist de trois lignes :

1. **Appareil photo**
   - bénéfice : photographier un actif et scanner une facture ;
   - un tap demande l’accès vidéo via AVFoundation ;
   - la chaîne `NSCameraUsageDescription` existante reste la source du message système.
2. **Notifications**
   - bénéfice : être prévenu lorsqu’un objectif de prix est atteint ;
   - un tap demande les autorisations alerte et son via `UNUserNotificationCenter` ;
   - le texte de bénéfice est affiché dans KARA avant le dialogue, car le corps du dialogue système n’est pas personnalisable.
3. **Verrouillage biométrique**
   - bénéfice : protéger l’ouverture du coffre KARA ;
   - un tap appelle `AppLockController.requestEnable()` ;
   - une authentification réussie active le verrouillage ;
   - l’intitulé utilise Face ID ou Touch ID selon la capacité détectée, avec le code de l’appareil comme solution système de secours.

Les cases sont des indicateurs d’accomplissement, pas des toggles prétendant révoquer une autorisation système.

États possibles pour chaque ligne :

- disponible, non demandé ;
- demande en cours ;
- autorisé ou activé ;
- refusé ;
- indisponible ;
- erreur récupérable.

Comportement :

- un seul dialogue peut être demandé à la fois ;
- pendant une demande, les trois actions sont temporairement désactivées ;
- après succès, la ligne devient cochée et affiche « Activé » ;
- après refus, elle affiche « Non autorisé » ;
- lorsqu’iOS ne permet plus de réafficher un dialogue, le tap propose d’ouvrir les Réglages système de KARA ;
- une indisponibilité matérielle affiche un état non interactif ;
- « Continuer » reste toujours disponible ;
- activer le verrouillage ne verrouille pas KARA immédiatement à la sortie de l’onboarding.

Lors du rejeu depuis les Réglages, les états actuels sont chargés au lieu de repartir de zéro.

### Page 5 — Suggestions facultatives

But : expliquer l’analyse assistée et obtenir le consentement nécessaire avant tout envoi à un tiers.

- Montrer une facture d’exemple et trois champs suggérés.
- Expliquer que KARA peut proposer des champs à partir d’une photo ou d’une facture choisie.
- Conserver un contrôle indépendant « Suggestions automatiques ».
- Le contrôle est désactivé par défaut sur une première installation.
- Expliquer de manière lisible :
  - le média est choisi volontairement par l’utilisateur ;
  - il transite via KARA vers OpenAI ;
  - OpenAI peut conserver des journaux de surveillance des abus jusqu’à 30 jours ;
  - KARA ne conserve pas une copie serveur du média ;
  - une connexion internet est requise ;
  - l’utilisateur valide toujours les champs avant enregistrement.
- Action finale : « Ouvrir mon coffre ».

L’action ouvre le tableau de bord. Elle ne lance pas automatiquement la création d’un actif.

## Navigation et abandon

`OnboardingStep` contient exactement cinq étapes :

1. `revelation`
2. `inventory`
3. `valuation`
4. `permissions`
5. `intelligence`

Le bouton principal et le swipe horizontal écrivent dans la même sélection. La progression affiche cinq positions et reste annoncée à VoiceOver sous la forme « Étape n sur 5 ».

« Passer » est visible sur toutes les pages :

- en première installation, il termine l’onboarding et laisse les suggestions automatiques désactivées ;
- lors d’un rejeu, il retourne aux Réglages sans modifier les choix existants.

Le CTA final appelle le flux de fin actuel. Le tableau de bord vide reste la première destination et son bouton « Ajouter un actif » demeure le point d’entrée vers la création.

## Modèle des autorisations

`OnboardingPermissionsModel` est un type `@MainActor @Observable` détenu par `OnboardingView` avec `@State`.

Il dépend de frontières injectables :

- `CameraAuthorizationProviding` pour lire et demander l’accès caméra ;
- `UserNotificationCenterProviding`, déjà présent, pour lire et demander l’accès aux notifications ;
- `AppLockController`, déjà présent dans l’environnement, pour l’authentification et le verrouillage ;
- une action injectée d’ouverture des Réglages système.

Le modèle :

- charge les trois états lorsque la page 4 devient active ;
- recharge caméra et notifications quand l’application redevient active après un passage dans Réglages ;
- sérialise les demandes avec un unique identifiant de demande active ;
- transforme les statuts des frameworks en états de présentation stables ;
- n’écrit aucune préférence caméra ou notification parallèle aux statuts système ;
- s’appuie sur `AppLockPreferences` comme source de vérité pour le verrouillage.

Si l’utilisateur passe l’onboarding sans demander un accès :

- UIKit peut toujours demander la caméra lors de la première capture ;
- le flux de création d’alerte peut toujours demander les notifications ;
- le verrouillage peut toujours être activé depuis Réglages.

## Gestion des erreurs

- Annulation d’un dialogue ou d’une authentification : retour à l’état non activé, sans alerte bloquante.
- Refus caméra ou notifications : état explicite et possibilité d’ouvrir Réglages.
- Caméra absente ou restreinte : « Indisponible sur cet appareil ».
- Biométrie ou code appareil indisponible : message inline et possibilité de continuer.
- Erreur de lecture d’un statut : état réessayable, sans empêcher la navigation.
- Une autorisation accordée mais modifiée ensuite dans Réglages est reflétée au prochain retour dans l’application.

Les erreurs de permissions utilisent des messages inline. Elles ne nécessitent pas de dialogue de confirmation.

## Direction visuelle

- Page 1 : photographie du lingot existante, conservée sans nouvelle image générée.
- Pages 2 à 5 : fond `KaraVoid`, surfaces nettes, lumière cobalt instrumentale et or réservé à la matière ou à l’action importante.
- Les exemples reprennent les composants, illustrations et densités du produit sans reproduire un écran entier au pixel près.
- Les montants utilisent des chiffres tabulaires.
- Les transitions sont directionnelles et sobres, sans rebond :
  - apparition de la fiche sur la page 2 ;
  - tracé ou révélation de la courbe sur la page 3 ;
  - changement d’état des cases sur la page 4 ;
  - passage facture → suggestions sur la page 5.
- Avec Réduire les animations, tous les visuels apparaissent directement dans leur état final.
- Avec Réduire la transparence, les surfaces deviennent opaques.
- Le contraste renforcé augmente bordures et contraste des états sans remplacer le cobalt par le gold.

## Accessibilité

- Support complet de Dynamic Type, y compris les tailles d’accessibilité.
- Scroll vertical par page si le contenu ne tient plus.
- Cibles interactives d’au moins 44 × 44 points.
- « Passer », progression, action principale et lignes d’autorisation ont des identifiants d’accessibilité stables.
- Chaque ligne d’autorisation annonce son bénéfice et son état.
- Une case cochée n’est jamais la seule indication de succès : le texte « Activé » est également annoncé et visible.
- Les illustrations décoratives sont cachées à VoiceOver ; leurs conclusions sont décrites par le texte de la page.
- Les couleurs positives ou négatives sont accompagnées de signes et de libellés.
- Le pager reste pilotable au swipe et au bouton.

## Localisation

Toutes les nouvelles chaînes sont ajoutées à `Localizable.xcstrings` en français et en anglais.

Les textes français de cette spécification sont la base éditoriale. La version anglaise doit être idiomatique et conserver le sens, sans traduction mot à mot obligatoire. Les textes système restent contrôlés par iOS et par les clés d’usage d’`InfoPlist.xcstrings`.

## Tests

### Tests unitaires

- Le flux traverse exactement cinq étapes.
- Swipe et bouton partagent la même sélection.
- La fin de la cinquième étape ouvre la destination attendue.
- Les profils de mouvement réduit produisent des durées courtes et des états statiques.
- Chaque statut caméra est correctement transformé en état de présentation.
- Chaque statut notification est correctement transformé en état de présentation.
- Une seule demande d’autorisation peut être active.
- Autorisation, refus, annulation, indisponibilité et erreur produisent l’état attendu.
- Une authentification réussie active le verrouillage sans verrouillage immédiat.
- Passer une première installation désactive l’analyse assistée.
- Passer un rejeu ne modifie aucune préférence.

### Tests d’interface

- Les cinq pages et leurs actions françaises sont accessibles.
- La localisation anglaise ne tronque pas les titres et actions.
- Le swipe met à jour l’action et la progression.
- « Passer » termine une première installation.
- « Passer » quitte correctement un rejeu.
- Les trois lignes d’autorisation exposent leurs états.
- Les dialogues réels sont remplacés par des frontières simulées dans les tests déterministes.
- Le CTA « Ouvrir mon coffre » mène au tableau de bord et n’ouvre pas la création d’actif.
- Dynamic Type d’accessibilité permet d’atteindre tout le contenu et le CTA.

### Vérification manuelle

- Vérifier les trois dialogues sur un appareil ou simulateur remis à zéro.
- Vérifier refus puis retour depuis Réglages.
- Vérifier l’activation Face ID et le retour au tableau de bord sans verrouillage immédiat.
- Vérifier l’absence de nouvelles lignes SwiftData ou CloudKit après l’onboarding.
- Vérifier les deux bords du pager horizontal.
- Vérifier Réduire les animations, Réduire la transparence et contraste renforcé.

## Critères d’acceptation

- Cinq pages distinctes montrent la promesse, l’inventaire, la valeur, les accès et les suggestions.
- Les corps de texte sont réellement rendus.
- L’image actuelle du lingot reste la scène principale de la première page.
- Les pages suivantes montrent des exemples produit lisibles.
- Appareil photo, notifications et verrouillage biométrique peuvent être activés depuis la page 4.
- Les demandes sont individuelles et jamais lancées automatiquement en série.
- Le résultat de chaque demande est visible.
- Aucun refus ne bloque l’accès à KARA.
- Le consentement IA reste séparé et désactivé par défaut.
- Aucun actif d’exemple n’est persisté.
- La sortie mène au tableau de bord vide.
- Le parcours fonctionne en français, en anglais, avec VoiceOver, Dynamic Type et Réduire les animations.
