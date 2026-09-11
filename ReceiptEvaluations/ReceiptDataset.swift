import Evaluations
import Foundation
import FoundationModels
import ReceiptKit

/// Capture condition of a receipt photo, as labelled in `references.json`.
enum ReceiptGroup: String, Codable, CaseIterable, Sendable {
    case clean
    case crumpled
}

/// One receipt photo, by asset name, paired with its hand-written reference.
struct ReceiptSample: ModelSampleProtocol {
    let key: String
    let group: ReceiptGroup
    let input: ModelSampleInput
    let output: ModelSampleOutput<Receipt, TrajectoryExpectation>

    var expected: Receipt? { output.value }
}

/// Pairs the photos `000`–`020` with `references.json` when the evaluation starts, so a missing
/// or incomplete file fails the test with a message instead of crashing while tests load.
struct ReceiptLoader: Loader {
    /// Image names, paired by key with `references.json`.
    static let keys = (0...20).map { String(format: "%03d", $0) }

    /// Holds the receipt photos: the host app's asset catalog.
    let images: Bundle
    /// Holds `references.json`: this test bundle.
    let references: Bundle

    var stream: any AsyncSequence<ReceiptSample, any Error> {
        AsyncThrowingStream<ReceiptSample, any Error> { continuation in
            do {
                for sample in try samples() {
                    continuation.yield(sample)
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    private func samples() throws -> [ReceiptSample] {
        guard let url = references.url(forResource: "references", withExtension: "json") else {
            throw ReceiptDatasetError.missingReferences
        }
        let entries = try JSONDecoder().decode([String: Reference].self, from: Data(contentsOf: url))

        var samples: [ReceiptSample] = []
        var problems: [String] = []
        for key in Self.keys {
            guard let entry = entries[key] else {
                problems.append("\(key): no entry in references.json")
                continue
            }
            do {
                _ = try ReceiptImages.load(named: key, in: images)
            } catch {
                problems.append("\(key): \(error.localizedDescription)")
                continue
            }
            samples.append(ReceiptSample(
                key: key,
                group: entry.group,
                input: ModelSampleInput(prompt: ReceiptExtractor.prompt),
                output: ModelSampleOutput(value: entry.receipt)
            ))
        }
        guard problems.isEmpty else { throw ReceiptDatasetError.incomplete(problems) }
        return samples
    }
}

/// One entry of `references.json`: the receipt fields plus the sample's group.
private struct Reference: Decodable {
    let group: ReceiptGroup
    let receipt: Receipt

    private enum CodingKeys: String, CodingKey {
        case group
    }

    init(from decoder: any Decoder) throws {
        group = try decoder.container(keyedBy: CodingKeys.self).decode(ReceiptGroup.self, forKey: .group)
        receipt = try Receipt(from: decoder)
    }
}

// Swift Testing reports caught errors with `description`, so both return the same text.
enum ReceiptDatasetError: LocalizedError, CustomStringConvertible {
    case missingReferences
    case incomplete([String])

    var errorDescription: String? { description }

    var description: String {
        switch self {
        case .missingReferences:
            "references.json not found. Add it to ReceiptEvaluations/ (schema: references.example.json)."
        case .incomplete(let problems):
            "Dataset is incomplete:\n" + problems.map { "  - \($0)" }.joined(separator: "\n")
        }
    }
}
