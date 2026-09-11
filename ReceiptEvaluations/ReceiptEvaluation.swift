import Evaluations
import Foundation
import FoundationModels
import ReceiptKit

/// Scores `ReceiptExtractor` field by field with code, then overall with a model judge.
struct ReceiptEvaluation: Evaluation {
    // Declared explicitly: inferring them through `Evaluators` is rejected as recursive.
    typealias Sample = ReceiptSample
    typealias Subject = ModelSubject<Receipt>

    let dataset: ReceiptLoader

    let store = Metric("Store")
    let date = Metric("Date")
    let items = Metric("Items")
    let judge = Metric("Faithfulness")

    init(images: Bundle, references: Bundle) {
        dataset = ReceiptLoader(images: images, references: references)
    }

    func subject(from sample: ReceiptSample) async throws -> ModelSubject<Receipt> {
        let (image, orientation) = try ReceiptImages.load(named: sample.key, in: dataset.images)
        let receipt = try await ReceiptExtractor.extract(
            from: image,
            orientation: orientation,
            prompt: sample.input.prompt
        )
        return ModelSubject(value: receipt)
    }

    var evaluators: Evaluators {
        Evaluator { sample, subject in
            guard let expected = sample.expected else { return store.ignore(rationale: "No reference") }
            return ReceiptMatching.sameText(subject.value.store, expected.store)
                ? store.passing()
                : store.failing(rationale: "Got \"\(subject.value.store)\", expected \"\(expected.store)\"")
        }

        Evaluator { sample, subject in
            guard let expected = sample.expected else { return date.ignore(rationale: "No reference") }
            return subject.value.date == expected.date
                ? date.passing()
                : date.failing(rationale: "Got \(subject.value.date), expected \(expected.date)")
        }

        // F1 over line items; an item matches when both its label and its price match.
        Evaluator { sample, subject in
            guard let expected = sample.expected else { return items.ignore(rationale: "No reference") }
            let score = ReceiptMatching.itemsF1(subject.value.items, expected: expected.items)
            return items.scoring(
                score,
                rationale: "\(subject.value.items.count) extracted, \(expected.items.count) expected"
            )
        }

        // The judge only sees text: the extraction and the human reference, not the photo.
        ModelJudgeEvaluator(
            "Faithfulness",
            scale: .numeric([
                4: "Store, date, and every item match the reference, and nothing is invented.",
                3: "Store and date match; at most one item is missing, extra, or mispriced.",
                2: "Store or date is wrong, or several items are missing, extra, or mispriced.",
                1: "The extraction doesn't describe the reference receipt.",
            ]),
            // The judge restates receipt text it's given; default guardrails refused some runs.
            judge: SystemLanguageModel(guardrails: .permissiveContentTransformations),
            prompt: ModelJudgePrompt(
                instructions: """
                    You are grading fields that an app extracted from a photo of a store receipt, \
                    against a human transcription of the same receipt. Treat differences in case, \
                    accents, spacing, and item order as equivalent. Penalize invented items, items \
                    copied from subtotal, tax, or payment lines, translated labels, and wrong prices.
                    """,
                evaluationTarget: { receipt in receipt.judgeDescription },
                reference: { sample, _ in
                    ["Reference receipt": sample.expected?.judgeDescription ?? "No reference"]
                }
            )
        )
    }

    func aggregateMetrics(using aggregator: inout MetricsAggregator) {
        aggregator.group("Fields") { group in
            group.computeMean(of: store)
            group.computeMean(of: date)
            group.computeMean(of: items)
        }
        aggregator.group("Judge") { group in
            group.computeMean(of: judge)
        }
    }
}

extension Receipt {
    /// Plain-text rendering given to the judge for both the extraction and the reference.
    var judgeDescription: String {
        let lines = items.map { "- \($0.name): \(String(format: "%.2f", $0.price))" }
        return (["Store: \(store)", "Date: \(date)", "Items:"] + lines).joined(separator: "\n")
    }
}

enum ReceiptMatching {
    /// Share of the longer label that a contained label must cover, so that a short fragment
    /// such as "OIL" doesn't match "ENGINE OIL".
    static let minimumContainedRatio = 0.6

    /// Compares labels ignoring case, accents, spacing, and punctuation; a label also matches
    /// when the other contains it and it covers at least `minimumContainedRatio` of the other's
    /// length (such as "CARREFOUR" and "Carrefour Market", or "EY20 PLUG CHAMPION").
    static func sameText(_ lhs: String, _ rhs: String) -> Bool {
        let a = normalized(lhs), b = normalized(rhs)
        guard !a.isEmpty, !b.isEmpty else { return a == b }
        if a == b { return true }
        let (short, long) = a.count < b.count ? (a, b) : (b, a)
        return Double(short.count) >= minimumContainedRatio * Double(long.count) && long.contains(short)
    }

    /// Harmonic mean of precision and recall, pairing each expected item with at most one
    /// extracted item.
    static func itemsF1(_ extracted: [ReceiptItem], expected: [ReceiptItem]) -> Double {
        if extracted.isEmpty && expected.isEmpty { return 1 }
        var unmatched = extracted
        var matches = 0
        for item in expected {
            if let index = unmatched.firstIndex(where: {
                sameText($0.name, item.name) && abs($0.price - item.price) < 0.01
            }) {
                unmatched.remove(at: index)
                matches += 1
            }
        }
        guard matches > 0 else { return 0 }
        let precision = Double(matches) / Double(extracted.count)
        let recall = Double(matches) / Double(expected.count)
        return 2 * precision * recall / (precision + recall)
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .filter { $0.isLetter || $0.isNumber }
    }
}
