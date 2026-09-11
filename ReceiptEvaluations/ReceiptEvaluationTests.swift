import Evaluations
import Foundation
import FoundationModels
import ReceiptKit
import Testing

@Suite("Receipt Evaluations")
struct ReceiptEvaluationTests {
    /// Photos come from the host app's asset catalog; `references.json` ships with this test bundle.
    static let evaluation = ReceiptEvaluation(images: .main, references: #bundle)

    static let evaluationInfo = [
        "Feature": "Receipt extraction from photos",
        "ModelName": "SystemLanguageModel",
        "Prompt": ReceiptExtractor.instructions,
    ]

    @Test(
        "Receipt extraction",
        .enabled(if: SystemLanguageModel.default.isAvailable, "Requires Apple Intelligence"),
        .evaluates(evaluation, info: evaluationInfo)
    )
    func receiptExtraction() throws {
        let result = EvaluationContext.current.result
        let report = MarkdownReport.render(result, of: Self.evaluation)
        print(report)
        Testing.Attachment.record(report, named: "receipts.md")

        // Every receipt must be extracted. A judge that refuses a sample (guardrails) isn't a
        // failure of the feature: it shows as "—" in the report.
        #expect(
            result.errors.inferenceFailureCount == 0,
            "\(result.errors.inferenceFailureCount) receipt(s) couldn't be extracted"
        )
    }
}
