import ReceiptKit
import SwiftUI

/// Shows one receipt photo and what the on-device model extracts from it.
struct ReceiptDetailView: View {
    /// Receipt photos in the asset catalog.
    static let names = (0...20).map { String(format: "%03d", $0) }

    let name: String
    @State private var extraction: Result<Receipt, any Error>?
    /// Incremented by "Try Again" to restart the extraction task.
    @State private var attempt = 0
    @State private var isZoomed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                photo
                switch extraction {
                case nil:
                    loading
                case .failure(let error):
                    failure(error)
                case .success(let receipt):
                    fields(of: receipt)
                }
            }
            .padding(16)
        }
        .background(.background.secondary)
        .navigationTitle("Receipt \(name)")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $isZoomed) {
            ZoomedReceipt(name: name)
        }
        .task(id: attempt) {
            await extract()
        }
    }

    private var photo: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: 360)
            .card(padding: 8)
            .overlay(alignment: .topTrailing) {
                Button("Zoom", systemImage: "plus.magnifyingglass") {
                    isZoomed = true
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .padding(16)
            }
    }

    private func fields(of receipt: Receipt) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Label {
                Text("Extracted on device")
            } icon: {
                Image(systemName: "sparkles")
                    .foregroundStyle(.tint)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            section("Store") {
                Label(receipt.store, systemImage: "storefront")
                    .font(.headline)
            }

            section("Date") {
                HStack {
                    Label("Date", systemImage: "calendar")
                    Spacer()
                    Text(receipt.date)
                        .monospacedDigit()
                }
            }

            section("Items", trailing: "Price") {
                VStack(spacing: 12) {
                    ForEach(receipt.items.indices, id: \.self) { index in
                        let item = receipt.items[index]
                        HStack(alignment: .firstTextBaseline) {
                            Text(item.name)
                            Spacer()
                            Text(item.price, format: .number.precision(.fractionLength(2)))
                                .monospacedDigit()
                        }
                        Divider()
                    }
                    Text("^[\(receipt.items.count) item](inflect: true)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var loading: some View {
        VStack(alignment: .leading, spacing: 24) {
            section("Store") {
                placeholder(width: 0.7)
            }
            section("Date") {
                placeholder(width: 0.3)
            }
            section("Items", trailing: "Price") {
                VStack(spacing: 12) {
                    ForEach([0.55, 0.45], id: \.self) { width in
                        HStack {
                            placeholder(width: width)
                            Spacer()
                            placeholder(width: 0.15)
                        }
                    }
                }
            }
            ProgressView("Reading receipt…")
                .frame(maxWidth: .infinity)
        }
    }

    private func failure(_ error: any Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(.red)
                .padding(16)
                .background(.red.opacity(0.12), in: .circle)
            Text("Couldn't read this receipt")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                attempt += 1
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 24)
    }

    private func section<Content: View>(
        _ title: LocalizedStringKey,
        trailing: LocalizedStringKey? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: title, trailing: trailing)
            content()
                .card()
        }
    }

    /// Gray bar standing in for text while the model reads the receipt.
    private func placeholder(width fraction: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.quaternary)
            .frame(height: 16)
            .containerRelativeFrame(.horizontal) { length, _ in length * fraction }
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

/// The receipt photo at full size, to check what the model had to read.
private struct ZoomedReceipt: View {
    let name: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                Image(name)
            }
            .navigationTitle("Receipt \(name)")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 700)
        #endif
    }
}
