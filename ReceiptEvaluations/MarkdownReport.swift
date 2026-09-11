import Evaluations
import Foundation
import TabularData

/// Renders an evaluation run as markdown: one row per receipt, then means per group.
enum MarkdownReport {
    private struct Row {
        let key: String
        let group: ReceiptGroup
        let store: Double?
        let date: Double?
        let items: Double?
        let judge: Double?
    }

    static func render(_ result: EvaluationResult, of evaluation: ReceiptEvaluation) -> String {
        let rows = rows(from: result.detailed, of: evaluation)
        var lines = [
            "## Receipts",
            "",
            "| Sample | Group | Store | Date | Items (F1) | Judge (1–4) |",
            "|---|---|:-:|:-:|:-:|:-:|",
        ]
        for row in rows {
            lines.append("| \(row.key) | \(row.group.rawValue) | \(check(row.store)) | \(check(row.date)) | \(number(row.items)) | \(number(row.judge, digits: 0)) |")
        }

        lines += [
            "",
            "## Means per group",
            "",
            "| Group | n | Store | Date | Items (F1) | Judge (1–4) |",
            "|---|:-:|:-:|:-:|:-:|:-:|",
        ]
        let groups = ReceiptGroup.allCases.map { group in (group.rawValue, rows.filter { $0.group == group }) }
        for (name, members) in groups + [("**All**", rows)] {
            lines.append("| \(name) | \(members.count) | \(percent(mean(members.map(\.store)))) | \(percent(mean(members.map(\.date)))) | \(number(mean(members.map(\.items)))) | \(number(mean(members.map(\.judge)))) |")
        }

        if result.errors.hasFailures {
            lines += [
                "",
                "> ⚠️ \(result.errors.inferenceFailureCount) inference failure(s), \(result.errors.evaluatorFailureCount) evaluator failure(s); missing values show as —.",
            ]
        }
        return lines.joined(separator: "\n")
    }

    private static func rows(from frame: DataFrame, of evaluation: ReceiptEvaluation) -> [Row] {
        let samples = frame[evaluation.inputColumn]
        let store = values(of: evaluation.store, in: frame)
        let date = values(of: evaluation.date, in: frame)
        let items = values(of: evaluation.items, in: frame)
        let judge = values(of: evaluation.judge, in: frame)
        return frame.rows.indices.compactMap { index in
            guard let sample = samples[index] else { return nil }
            return Row(
                key: sample.key,
                group: sample.group,
                store: store[index],
                date: date[index],
                items: items[index],
                judge: judge[index]
            )
        }
        .sorted { $0.key < $1.key }
    }

    /// Numeric value of `metric` for each row; all nil when no row produced it (such as a judge
    /// that failed on every sample), since the frame then has no column for it.
    private static func values(of metric: Metric, in frame: DataFrame) -> [Double?] {
        guard frame.columns.contains(where: { $0.name == metric.name }) else {
            return Array(repeating: nil, count: frame.rows.count)
        }
        return frame[metric: metric].map { metric in
            switch metric?.value {
            case .passing: 1
            case .failing: 0
            case .scoring(let value): value
            case .ignore, nil: nil
            @unknown default: nil
            }
        }
    }

    private static func mean(_ values: [Double?]) -> Double? {
        let present = values.compactMap { $0 }
        return present.isEmpty ? nil : present.reduce(0, +) / Double(present.count)
    }

    private static func check(_ value: Double?) -> String {
        value.map { $0 == 1 ? "✅" : "❌" } ?? "—"
    }

    private static func percent(_ value: Double?) -> String {
        value.map { String(format: "%.0f%%", $0 * 100) } ?? "—"
    }

    private static func number(_ value: Double?, digits: Int = 2) -> String {
        value.map { String(format: "%.\(digits)f", $0) } ?? "—"
    }
}
