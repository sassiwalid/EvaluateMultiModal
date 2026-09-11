# Evaluating Receipt Extraction with Foundation Models and Evaluations

This project measures how well Apple's on-device model (the **Foundation Models** framework) reads photos of store receipts: store name, date, and line items. It uses the **Evaluations** framework that ships with Xcode 27. Code-based checks and a model judge compare each extraction with a human-style transcription, across 21 photos.

## Requirements

- Xcode 27 (tested with 27.0 RC, build 27A266a) and macOS 27.
- A Mac with Apple Intelligence turned on. Without it, the evaluation test is skipped and the app shows "Model Unavailable".
- No external dependencies.

## Project Layout

```
EvaluateMultiModalFoundationsModels.xcodeproj
├─ EvaluateMultiModalFoundationsModels   SwiftUI demo app, linked to ReceiptKit
└─ ReceiptEvaluations                    test target hosted by the app

EvaluateMultiModalFoundationsModels/     app sources + Assets.xcassets (photos 000 to 020)
ReceiptKit/                              local Swift package: the feature
ReceiptEvaluations/                      the evaluation, the report, and references.json
```

The split follows Apple's BookTracker sample: the feature lives in shippable code (`ReceiptKit`), and the evaluation lives in a test target, because `Evaluations` is a developer framework that ships with Xcode, not with the OS.

## The Feature: `ReceiptKit`

- **`Receipt` and `ReceiptItem`**: `@Generable` types (guided generation). Each field has a `@Guide` description, and a regex constrains the date to `YYYY-MM-DD`.
- **`ReceiptExtractor.extract(from:orientation:)`**: opens a `LanguageModelSession` and sends the prompt plus `Attachment(image, orientation:)` through the `PromptBuilder`. It uses `GenerationOptions(samplingMode: .greedy)` so that identical runs return identical results.
- **`ReceiptImages.load(named:in:)`**: looks for a `.jpg`, `.jpeg`, `.png`, or `.heic` file in the bundle first, then for the image with the same name in the asset catalog. A file's EXIF orientation is read and passed to `Attachment`. None of the 21 photos has one.

## The Demo App

- **Receipts screen**: a grid of cards showing the top of each photo, where the store name is printed. If Apple Intelligence is unavailable, a `ContentUnavailableView` explains why (unsupported device, turned off, or model still downloading).
- **Receipt screen**: the photo with a zoom button, then one of three states: placeholders with "Reading receipt…" during extraction, an error card with "Try Again", or the Store, Date, and Items sections with right-aligned prices.

The layout follows mockups generated with Stitch; they're in `.stitch/designs/`. Colors come from system styles, so dark mode works on iOS, macOS, and visionOS.

## The Evaluation: `ReceiptEvaluations`

### Data

`references.json` holds one entry per photo, keyed `"000"` to `"020"`; `references.example.json` shows the format:

```json
{
  "007": {
    "group": "clean",
    "store": "S.H.H. MOTOR (SUNGAI RENGIT) SDN. BHD.",
    "date": "2019-01-23",
    "items": [{ "name": "CROCS 300X17 TUBES", "price": 20.0 }]
  }
}
```

`group` describes the photo's condition, not the receipt's language: `clean` for a flat, legible receipt, `crumpled` when the paper is visibly deformed (creases, curls, waves). Each item's `price` is the line total as printed. The photos are read from the host app's asset catalog. If the file, an entry, or an image is missing, the test fails and lists what's missing.

The references were transcribed from the photos (21 receipts, 58 items). Every mismatch from the first run was checked against its photo; all of them came from the model, not from the transcription. A few entries are judgment calls:

- **009**: the store is the company printed at the top, "Gerbang Alaf Restaurants Sdn Bhd"; the model returns the outlet, "McDonald's BHP Taman Melawati". "L Coke" has no printed price, so its price is 0.00.
- **014**: two labels are partial ("LIME 50G", "LEMON DRINK 500ML") because a punch hole or faded ink hides part of the text. Matching accepts a label that contains the other, so a full extraction still matches.
- **017**: the "REFER" line is a credit-note reference, not an item, so it's excluded.

### Metrics

| Metric | Type | Rule |
|---|---|---|
| Store | pass / fail | Names are equal once normalized (case, accents, spaces, punctuation), or one contains the other (at least 4 characters) |
| Date | pass / fail | Exact match in `YYYY-MM-DD` format |
| Items | score from 0 to 1 | F1: an item counts when its normalized label **and** its price (within ±0.01) match |
| Faithfulness | judge, from 1 to 4 | `ModelJudgeEvaluator` compares the extraction with the reference |

The judge scores on a 4-level scale, each level described by observable criteria. `ModelJudgePrompt` gives it the extraction as text (`evaluationTarget`) and the transcription (`reference`); it never sees the photo. It uses the on-device model with `guardrails: .permissiveContentTransformations`, because the default guardrails refused to score some receipts.

The test passes when every receipt is extracted. If the judge refuses a sample (its guardrails still trigger occasionally), that sample shows "—" in the report and a warning line notes it; it isn't counted as a failure of the feature.

### Report

The test prints the report and attaches it to the Xcode test report as `receipts.md`: one table row per receipt, then means per group (clean, crumpled, All). `MarkdownReport` computes the group means from `result.detailed`, because `MetricsAggregator.group` groups metrics but doesn't filter samples.

### Running It

- **In Xcode**: scheme `EvaluateMultiModalFoundationsModels`, destination My Mac, then ⌘U.
- **From the command line**:
  ```sh
  xcodebuild test -project EvaluateMultiModalFoundationsModels.xcodeproj \
    -scheme EvaluateMultiModalFoundationsModels -destination platform=macOS
  ```
- **The package alone**: `cd ReceiptKit && swift build`.

On the test Mac, a full run (21 extractions and 21 judge scores) takes about 1 min 45 s.

## Results

First run on the 21 receipts:

| Store | Date | Items (F1) | Judge (1–4) |
|:-:|:-:|:-:|:-:|
| 71% | 81% | 0.52 | 2.75 |

Two consecutive runs returned exactly the same extracted fields, thanks to greedy sampling. The judge varies slightly between runs (2.80, then 2.75) and doesn't always refuse the same receipt.

Typical model errors:

- **Overlaid names**: it takes the "tan woon yann" or "tan chay yee" overlay for the store name (002, 004, 005).
- **Shifted items**: it pairs each description with the price of the neighboring line (006).
- **Dates**: it reads some dates month-first (006: 2019-11-01 instead of January 11) or invents one (004: 2024).
- **Hallucination**: on 008, an A4 scan where the receipt is small, it invents a store and its items.
- **Extra lines**: it lists item codes (007), the litres/pump line (019), or a discount (001) as items.
- **Labels**: it misspells labels ("MAKAHAN", "SETAI") or reports the unit price, or even the total, instead of the line total.

## Verified

- `swift build` in `ReceiptKit`, the app builds for macOS and iOS Simulator, and the test target builds.
- Without `references.json`, the test fails with `references.json not found. Add it to ReceiptEvaluations/ (schema: references.example.json).`
- With `references.json`, the test passes: 21 receipts extracted, no inference failures.
- The Receipts screen renders on an iOS 27 simulator (iPhone 18 Pro).

## Open Points

- **Groups**: none of the 21 photos is truly crumpled. Only 014 and 017, whose paper is visibly waved or curled, are labeled `crumpled`; the other 19 are `clean`. Two samples are too few for a reliable mean: add genuinely crumpled receipts.
- **Duplicates**: 012 and 015 are the same file, and so are 016 and 018. They count twice in the means and should be replaced.
- **Judge calibration**: the judge gave 2 or 3 out of 4 to extractions compared with placeholder references. Before relying on the Judge column, calibrate it against human scores, as BookTracker does with Cohen's kappa, or use `PrivateCloudComputeLanguageModel` as the judge.
- **Item codes**: codes printed on their own line become separate items. A rule in the extractor's instructions could fix this; measure its effect with the evaluation before and after the change.

## Documentation Versus SDK

- `GenerationOptions(sampling:)` is deprecated in favor of `samplingMode:`. Greedy generation uses `.greedy`, not `temperature: 0`.
- `Attachment` accepts a `CGImage`, a `CIImage`, a `CVPixelBuffer`, or a URL through `imageURL:`, with `orientation: CGImagePropertyOrientation?`. `NSImage` goes through a separate AppKit module.
- `respond` comes in two variants: with `includeSchemaInPrompt:` and, since 27.0, with `contextOptions:`. The documentation's `respond(generating:options:) { … }` call compiles without ambiguity.
- `evaluationTarget` and `reference` are set on `ModelJudgePrompt`, except in pairwise mode. Because `judge:` takes an `any LanguageModel`, you need to spell out `SystemLanguageModel.default`.
- `detailed[inputColumn]` has no `column:` label, unlike `detailed[metric:]`. Metric columns are named after the `Metric`.
- When inference fails for a sample, its metrics are `ignore` and are excluded from the means.
- With Swift 6.4, the `Sample` and `Subject` associated types must be declared explicitly (the compiler won't infer them through `Evaluators`), and `Metric.Value` requires an `@unknown default`.
- `Evaluations` lives inside Xcode (`Platforms/MacOSX.platform/Developer/Library/Frameworks`). An executable outside a test target needs an rpath to Xcode; in a test target, Xcode handles it.

## References

- Apple: [Analyzing images with multimodal prompting](https://developer.apple.com/documentation/FoundationModels/analyzing-images-with-multimodal-prompting)
- Apple: [Generating Swift data structures with guided generation](https://developer.apple.com/documentation/FoundationModels/generating-swift-data-structures-with-guided-generation)
- Apple: [Evaluations](https://developer.apple.com/documentation/evaluations) and the [BookTracker](https://developer.apple.com/documentation/evaluations/book-tracker-using-evaluations-to-evaluate-an-intelligent-feature) sample
- Swift Tribune: [Testing the Untestable: A Deep Dive into Apple's Evaluations Framework](https://swifttribune.walidsassi.com/posts/apple-evaluations-framework/)
- Swift Tribune: [When Code Can't Judge Quality: Model-as-Judge Evaluators](https://swifttribune.walidsassi.com/posts/apple-evaluations-model-judge/)
- Swift Tribune: [Two Refinements That Sharpen a Model-as-Judge Evaluator](https://swifttribune.walidsassi.com/posts/apple-evaluations-judge-refinements/)
