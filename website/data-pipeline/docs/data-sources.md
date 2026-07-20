# Sources, transformations et droits de réutilisation

Ce document décrit la provenance et la transformation des données publiées par
`kara-metals-data`. Il complète le contrat technique du [README](../README.md).

## Sources amont

### Prix des métaux : FMI

Source : [International Monetary Fund, Primary Commodity Prices](https://www.imf.org/en/research/commodity-prices).

Le générateur télécharge le classeur mensuel publié par le FMI et utilise les
séries suivantes, exprimées en dollars américains par once troy :

| Métal publié | Code ISO | Série FMI |
| --- | --- | --- |
| Or | `XAU` | `PGOLD` |
| Argent | `XAG` | `PSILVER` |
| Platine | `XPT` | `PPLAT` |
| Palladium | `XPD` | `PPALLA` |

Attribution publiée dans le snapshot :

> Source: International Monetary Fund, Primary Commodity Prices; transformed by Kara.

L'URL officielle du fichier est la valeur par défaut du générateur et peut être
remplacée explicitement par `IMF_SOURCE_URL` pour une reprise contrôlée. Aucun
scraping de prix depuis une page HTML et aucune API payante ne sont nécessaires.

Au 20 juillet 2026, le lien exposé par la page FMI est
[`external-data.xlsx`](https://www.imf.org/-/media/files/research/commodityprices/monthly/external-data.xlsx).
La feuille `External` place les codes des séries sur la première ligne, puis
l'unité et la fréquence sur les lignes d'en-tête suivantes. Le parseur recherche
les codes, valide l'unité `USD` et la fréquence `Monthly`, et ne dépend pas des
lettres de colonnes, qui peuvent changer lors d'une publication ultérieure. Les
périodes FMI de la forme `1980M1` sont normalisées en `1980-01`.

### Taux de change : Eurostat

Source : [Eurostat, `ert_bil_eur_m` — Euro/ECU exchange rates, monthly data](https://ec.europa.eu/eurostat/databrowser/view/ert_bil_eur_m/default/table).

Le générateur télécharge ce jeu au format SDMX-CSV en sélectionnant :

- la fréquence mensuelle ;
- la statistique `AVG`, c'est-à-dire la moyenne de la période ;
- les devises `USD`, `CHF` et `GBP`.

Les valeurs représentent le nombre d'unités de la devise concernée pour une
unité d'EUR à partir de janvier 1999, ou pour une unité d'ECU jusqu'en décembre
1998. La [métadonnée Eurostat](https://ec.europa.eu/eurostat/cache/metadata/en/ert_bil_eur_esms.htm)
précise cette frontière et le remplacement de l'ECU par l'euro au taux de 1:1.

Attribution publiée dans le snapshot :

> Source: Eurostat, ert_bil_eur_m; transformed by Kara.

`EUROSTAT_SOURCE_URL` permet de remplacer l'URL SDMX-CSV pour une reprise
contrôlée ou un test, sans contourner les validations.

La requête de référence est :

```text
https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/data/ert_bil_eur_m/M.AVG.NAC.CHF+GBP+USD?startPeriod=1980-01&format=SDMX-CSV
```

Le parseur valide notamment le dataflow `ESTAT:ERT_BIL_EUR_M(1.0)`, `freq=M`,
`statinfo=AVG`, `unit=NAC`, la devise et la période `YYYY-MM`, au lieu de se
fonder uniquement sur la position des colonnes CSV.

### Lacune palladium constatée

Le classeur FMI consulté le 20 juillet 2026 ne contient aucune valeur `PPALLA`
avant `1987M1`, alors que `PGOLD`, `PSILVER` et `PPLAT` couvrent janvier 1980.
Avec les seules sources approuvées ci-dessus, la couverture commune complète des
quatre métaux commence donc en janvier 1987.

Cette lacune rend impossible l'objectif initial d'une couverture commune dès
`1980-01`. La v1 implémentée commence donc explicitement à `1987-01`. Elle ne
doit jamais être comblée par `0`, interpolation ou extrapolation silencieuse.
Si une source autorisée et méthodologiquement compatible est validée plus tard,
la couverture pourra être étendue en amont sans changer la forme du contrat v1 ;
sa provenance et la règle de raccordement devront alors être ajoutées au
snapshot.

## Transformation

Pour un mois donné, avec :

- `Pusd` : prix mensuel FMI en USD par once troy ;
- `USDfx` : USD pour 1 EUR/ECU ;
- `CHFfx` : CHF pour 1 EUR/ECU ;
- `GBPfx` : GBP pour 1 EUR/ECU ;

les prix publiés sont calculés ainsi :

```text
EUR ou XEU = Pusd / USDfx
CHF        = Pusd × CHFfx / USDfx
GBP        = Pusd × GBPfx / USDfx
USD        = Pusd
```

Les calculs utilisent une arithmétique décimale, puis un arrondi à six décimales
en mode *round half to even*. Les résultats sont sérialisés comme chaînes JSON.

`XEU` désigne l'ECU historique et n'est publié que jusqu'en décembre 1998. `EUR`
est publié à partir de janvier 1999, y compris pendant la période où l'euro était
principalement scriptural avant l'arrivée des billets et pièces en 2002. Aucune
valeur antérieure à 1999 n'est étiquetée comme EUR.

## Contrôles de couverture et de qualité

À chaque exécution, tout l'historique est régénéré afin d'intégrer les révisions
rétroactives des sources. La publication est limitée à l'intersection continue
et complète des quatre séries de métaux et des trois séries FX. Le début attendu
est `1987-01`, première observation palladium disponible dans le classeur FMI.

Le générateur refuse notamment :

- une date ou un nombre impossible à décoder ;
- une valeur nulle, négative, nulle au sens numérique ou non finie ;
- un mois manquant ou dupliqué ;
- une série de métal ou de devise absente ;
- le mois civil en cours ;
- une couverture plus courte que celle déjà publiée.

Les copies exactes des entrées téléchargées sont conservées comme artefacts
GitHub pendant 90 jours avec les fichiers générés. Elles permettent d'expliquer
une version donnée même si une source corrige ensuite son historique.

## Limites méthodologiques

- Il s'agit de moyennes mensuelles, pas de clôtures, maxima, minima, cours
  journaliers ou cotations en temps réel.
- Les conversions sont des ratios de moyennes mensuelles. Elles ne sont pas la
  moyenne exacte des conversions de chaque séance.
- Les prix restent nominaux : aucune correction d'inflation n'est appliquée.
- La référence porte sur le métal brut par once troy. Elle ne mesure pas la
  prime d'une pièce ou d'un lingot, un spread vendeur/acheteur, la fiscalité, les
  frais de fabrication, la pureté, l'état ou la valeur artistique d'un objet.
- La conversion par gramme et la pondération par le titre de métal fin doivent
  être réalisées dans l'application cliente.
- Les sources peuvent corriger l'historique ; `dataVersion` peut donc changer
  sans que la couverture gagne un nouveau mois.

Le jeu de données est fourni comme indicateur informatif, sans garantie de prix
exécutable et sans constituer un conseil financier, juridique ou fiscal.

## Réutilisation et attribution

Les pages à examiner sont :

- [FMI — Copyright and Usage](https://www.imf.org/en/about/copyright-and-terms) ;
- [Eurostat — Copyright notice and free re-use of data](https://ec.europa.eu/eurostat/help/copyright-notice).

Les conditions du FMI demandent une attribution fidèle, l'identification des
transformations et, pour une réutilisation commerciale potentielle, une prise de
contact avec `copyright@imf.org`. Les principes Eurostat autorisent en général la
réutilisation avec attribution, y compris commerciale, mais prévoient des
exceptions, notamment pour certaines données attribuées à des tiers ou relatives
à des pays hors UE/AELE.

Cette synthèse est opérationnelle et ne remplace pas un avis juridique. Les
conditions peuvent évoluer ; conserver la date de consultation et la réponse
écrite éventuelle avec les documents du projet.

## Jalon obligatoire avant diffusion commerciale

La génération locale, les tests et la validation technique peuvent précéder ce
jalon. En revanche, la publication publique destinée à une application
commerciale doit rester bloquée jusqu'à ce que les points suivants soient
documentés :

1. demander au FMI une confirmation écrite couvrant le téléchargement
   systématique, la transformation et la redistribution des séries `PGOLD`,
   `PSILVER`, `PPLAT` et `PPALLA` dans Kara ;
2. confirmer que le jeu Eurostat `ert_bil_eur_m`, y compris les taux USD, CHF et
   GBP utilisés pour les transformations, n'entre pas dans une exception à la
   réutilisation commerciale ;
3. enregistrer les conditions applicables, la date de consultation, les
   interlocuteurs et les formulations d'attribution acceptées ;
4. vérifier que les attributions intégrées au snapshot et visibles dans la
   documentation de Kara respectent ces réponses ;
5. seulement ensuite activer la publication automatique des JSON dans le dépôt
   public GitHub.

Si une source refuse l'usage prévu, la publication doit rester bloquée. Son
adaptateur pourra être remplacé par une source autorisée, sans modifier le
contrat JSON v1 tant que la fréquence, l'unité, la sémantique et la qualité des
données restent identiques.
