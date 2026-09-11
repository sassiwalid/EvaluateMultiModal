import FoundationModels

/// Fields read from a photo of a store receipt.
@Generable(description: "Fields read from a photo of a store receipt")
public struct Receipt: Codable, Equatable, Sendable {
    @Guide(description: "Store or merchant name exactly as printed at the top of the receipt")
    public var store: String

    @Guide(description: "Purchase date in ISO 8601 format (YYYY-MM-DD)", #/\d{4}-\d{2}-\d{2}/#)
    public var date: String

    // Bounded so that a model looping on an unreadable receipt can't fill the 4,096-token
    // context; the longest receipt in the dataset has 9 items.
    @Guide(description: "Purchased line items, in the order they are printed", .maximumCount(40))
    public var items: [ReceiptItem]
}

@Generable
public struct ReceiptItem: Codable, Equatable, Sendable {
    @Guide(description: "Item label exactly as printed, in its original language")
    public var name: String

    @Guide(description: "Line total for this item, in the receipt's currency")
    public var price: Double
}
