import ReceiptKit
import SwiftUI

/// Shows one receipt photo and what the on-device model extracts from it.
struct ReceiptDetailView: View {
    /// Receipt photos in the asset catalog.
    static let names = (0...20).map { String(format: "%03d", $0) }

    let name: String
    @State private var extraction: Result<Receipt, any Error>?

    var body: some View {
        List {
            Section {
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 320)
            }
            switch extraction {
            case nil:
                ProgressView("Reading receipt…")
            case .failure(let error):
                Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
            case .success(let receipt):
                Section("Store") {
                    Text(receipt.store)
                }
                Section("Date") {
                    Text(receipt.date)
                }
                Section("Items") {
                    ForEach(receipt.items.indices, id: \.self) { index in
                        let item = receipt.items[index]
                        LabeledContent(item.name) {
                            Text(item.price, format: .number.precision(.fractionLength(2)))
                        }
                    }
                }
            }
        }
        .navigationTitle("Receipt \(name)")
        .task(id: name) {
            await extract()
        }
    }

    private func extract() async {
        extraction = nil
        do {
            let (image, orientation) = try ReceiptImages.load(named: name, in: .main)
            extraction = .success(try await ReceiptExtractor.extract(from: image, orientation: orientation))
        } catch {
            extraction = .failure(error)
        }
    }
}
