# Évaluer l'extraction de tickets de caisse avec Foundation Models et Evaluations

Ce projet mesure la qualité avec laquelle le modèle on-device d'Apple (framework **Foundation Models**) lit des photos de tickets de caisse : magasin, date et articles. La mesure passe par le framework **Evaluations** livré avec Xcode 27. Des vérifications en code et un modèle juge comparent chaque extraction à une transcription humaine, sur 21 photos.

## Prérequis

- Xcode 27 (testé avec la 27.0 RC, build 27A266a) et macOS 27.
- Un Mac avec Apple Intelligence activé. Sans lui, le test d'évaluation est ignoré et l'app affiche « Model Unavailable ».
- Aucune dépendance externe.

## Organisation

```
EvaluateMultiModalFoundationsModels.xcodeproj
├─ EvaluateMultiModalFoundationsModels   app démo SwiftUI, liée à ReceiptKit
└─ ReceiptEvaluations                    target de tests hébergée par l'app

EvaluateMultiModalFoundationsModels/     sources de l'app + Assets.xcassets (photos 000 à 020)
ReceiptKit/                              package Swift local : la fonctionnalité
ReceiptEvaluations/                      l'évaluation, le rapport et references.json
```

Le découpage reprend celui du sample Apple BookTracker : la fonctionnalité vit dans du code livrable (`ReceiptKit`), l'évaluation dans une target de tests. `Evaluations` est en effet un framework de développement fourni par Xcode, pas par l'OS.

## La fonctionnalité : `ReceiptKit`

- **`Receipt` et `ReceiptItem`** : types `@Generable` (guided generation). Chaque champ est décrit par un `@Guide`, et une regex impose le format de date `YYYY-MM-DD`.
- **`ReceiptExtractor.extract(from:orientation:)`** : ouvre une `LanguageModelSession` et envoie le prompt plus `Attachment(image, orientation:)` dans le `PromptBuilder`. Il utilise `GenerationOptions(samplingMode: .greedy)` pour que deux runs identiques donnent le même résultat.
- **`ReceiptImages.load(named:in:)`** : cherche d'abord un fichier `.jpg`, `.jpeg`, `.png` ou `.heic` dans le bundle, puis l'image de même nom dans l'asset catalog. L'orientation EXIF d'un fichier est lue et transmise à `Attachment`. Aucune des 21 photos n'en a.

## L'app démo

Elle affiche la liste des 21 tickets avec leur vignette. Un tap ouvre la photo, puis le magasin, la date et les articles extraits par le modèle.

## L'évaluation : `ReceiptEvaluations`

### Données

`references.json` est à placer dans `ReceiptEvaluations/` ; son format est donné par `references.example.json`. Il contient une entrée par photo, sous les clés `"000"` à `"020"` :

```json
{
  "000": {
    "group": "clean",
    "store": "NOM DU MAGASIN TEL QU'IMPRIMÉ",
    "date": "2019-01-23",
    "items": [{ "name": "LIBELLÉ TEL QU'IMPRIMÉ", "price": 20.0 }]
  }
}
```

`group` vaut `clean`, `crumpled` ou `non-FR`. Les photos sont lues dans l'asset catalog de l'app hôte. S'il manque le fichier, une entrée ou une image, le test échoue et liste ce qui manque.

### Métriques

| Métrique | Type | Règle |
|---|---|---|
| Store | réussite / échec | Noms égaux une fois normalisés (casse, accents, espaces, ponctuation), ou l'un contient l'autre (au moins 4 caractères) |
| Date | réussite / échec | Égalité exacte au format `YYYY-MM-DD` |
| Items | score de 0 à 1 | F1 : un article compte si son libellé normalisé **et** son prix (à ±0,01) correspondent |
| Faithfulness | juge, de 1 à 4 | `ModelJudgeEvaluator` compare l'extraction à la référence |

Le juge note sur une échelle de 4 niveaux, chacun décrit par des critères observables. `ModelJudgePrompt` lui transmet l'extraction mise en texte (`evaluationTarget`) et la transcription humaine (`reference`). Il ne voit jamais la photo. Il utilise le modèle on-device avec `guardrails: .permissiveContentTransformations`, car les guardrails par défaut refusaient de noter certains tickets.

### Rapport

Le test affiche le rapport et l'attache au rapport de test Xcode sous le nom `receipts.md`. Il contient un tableau par ticket, puis les moyennes par groupe (clean, crumpled, non-FR, All). `MarkdownReport` calcule ces moyennes à partir de `result.detailed`, car `MetricsAggregator.group` regroupe des métriques mais ne filtre pas les échantillons.

Format (valeurs fictives) :

| Sample | Group | Store | Date | Items (F1) | Judge (1–4) |
|---|---|:-:|:-:|:-:|:-:|
| 007 | crumpled | ✅ | ✅ | 0.67 | 3 |

| Group | n | Store | Date | Items (F1) | Judge (1–4) |
|---|:-:|:-:|:-:|:-:|:-:|
| crumpled | 7 | 86% | 71% | 0.74 | 3.14 |

### Lancer

- **Dans Xcode** : scheme `EvaluateMultiModalFoundationsModels`, destination My Mac, puis ⌘U.
- **En ligne de commande** :
  ```sh
  xcodebuild test -project EvaluateMultiModalFoundationsModels.xcodeproj \
    -scheme EvaluateMultiModalFoundationsModels -destination platform=macOS
  ```
- **Le package seul** : `cd ReceiptKit && swift build`.

Sur le Mac de test, un run complet (21 extractions et 21 notes du juge) prend environ 1 min 45.

## Ce qui a été vérifié

- `swift build` dans `ReceiptKit`, ainsi que le build de l'app pour macOS et iOS Simulator et celui de la target de tests.
- Sans `references.json`, le test échoue avec `references.json not found. Add it to ReceiptEvaluations/ (schema: references.example.json).`
- Avec des références factices placées dans le bundle compilé, les 21 tickets sont traités sans échec d'inférence et le test passe. Les scores de ce run n'ont pas de sens.
- Dans l'app démo, sur le ticket 007, le magasin et la date sont corrects. En revanche, le code article `4132`, imprimé sur sa propre ligne, ressort comme un article séparé.

## Points ouverts

- **Références** : `references.json` reste à écrire. Sans lui, l'évaluation ne produit aucun score.
- **Juge trop indulgent** : il a donné 2 ou 3 sur 4 à des extractions comparées à des références bidon. Avant de se fier à la colonne Judge, il faut le calibrer contre des notes humaines, comme BookTracker le fait avec le kappa de Cohen, ou utiliser `PrivateCloudComputeLanguageModel` comme juge.
- **Codes article** : ils sont pris pour des articles distincts. Une règle dans les instructions de l'extracteur peut corriger ça, mais il faut en mesurer l'effet avec l'évaluation, avant et après le changement.

## Écarts entre la documentation et le SDK

- `GenerationOptions(sampling:)` est déprécié au profit de `samplingMode:`. Pour une génération greedy, on utilise `.greedy`, pas `temperature: 0`.
- `Attachment` accepte un `CGImage`, un `CIImage`, un `CVPixelBuffer` ou une URL via `imageURL:`, avec `orientation: CGImagePropertyOrientation?`. `NSImage` passe par un module AppKit séparé.
- `respond` existe en deux variantes : avec `includeSchemaInPrompt:`, et depuis la 27.0 avec `contextOptions:`. L'appel de la doc `respond(generating:options:) { … }` compile sans ambiguïté.
- `evaluationTarget` et `reference` se configurent sur `ModelJudgePrompt`, sauf en mode pairwise. Comme `judge:` attend un `any LanguageModel`, il faut écrire `SystemLanguageModel.default` en entier.
- `detailed[inputColumn]` s'écrit sans label `column:`, contrairement à `detailed[metric:]`. Les colonnes de métriques portent le nom du `Metric`.
- Quand l'inférence échoue sur un échantillon, ses métriques valent `ignore` et sont exclues des moyennes.
- Avec Swift 6.4, les types associés `Sample` et `Subject` doivent être déclarés explicitement (le compilateur refuse de les déduire via `Evaluators`), et `Metric.Value` exige un `@unknown default`.
- `Evaluations` se trouve dans Xcode (`Platforms/MacOSX.platform/Developer/Library/Frameworks`). Un exécutable hors tests a besoin d'un rpath vers Xcode ; dans une target de tests, Xcode s'en charge.

## Références

- Apple : [Analyzing images with multimodal prompting](https://developer.apple.com/documentation/FoundationModels/analyzing-images-with-multimodal-prompting)
- Apple : [Generating Swift data structures with guided generation](https://developer.apple.com/documentation/FoundationModels/generating-swift-data-structures-with-guided-generation)
- Apple : [Evaluations](https://developer.apple.com/documentation/evaluations) et le sample [BookTracker](https://developer.apple.com/documentation/evaluations/book-tracker-using-evaluations-to-evaluate-an-intelligent-feature)
- Swift Tribune : [Testing the Untestable: A Deep Dive into Apple's Evaluations Framework](https://swifttribune.walidsassi.com/posts/apple-evaluations-framework/)
- Swift Tribune : [When Code Can't Judge Quality: Model-as-Judge Evaluators](https://swifttribune.walidsassi.com/posts/apple-evaluations-model-judge/)
- Swift Tribune : [Two Refinements That Sharpen a Model-as-Judge Evaluator](https://swifttribune.walidsassi.com/posts/apple-evaluations-judge-refinements/)
