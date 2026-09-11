import CoreGraphics
import FoundationModels
import ImageIO

/// Reads a receipt photo with the on-device model.
public enum ReceiptExtractor {
    public static let instructions = """
        You read photos of store receipts. Copy the store name and item labels exactly as \
        printed, in their original language; never translate them. Write the purchase date \
        as YYYY-MM-DD. List every purchased item once with its line total; skip subtotals, \
        taxes, payments, and change.
        """

    public static let prompt = Prompt("Extract the store, the purchase date, and the purchased items from this receipt.")

    public static func extract(
        from image: CGImage,
        orientation: CGImagePropertyOrientation? = nil,
        prompt: Prompt = prompt
    ) async throws -> Receipt {
        let session = LanguageModelSession(instructions: instructions)
        // Greedy sampling makes runs reproducible, so score changes come from prompt changes.
        let response = try await session.respond(
            generating: Receipt.self,
            options: GenerationOptions(samplingMode: .greedy)
        ) {
            prompt
            Attachment(image, orientation: orientation)
        }
        return response.content
    }
}
