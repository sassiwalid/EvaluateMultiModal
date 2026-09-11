import FoundationModels
import SwiftUI
import Playgrounds

struct ContentView: View {
    var body: some View {
        NavigationStack {
            if case .unavailable(let reason) = SystemLanguageModel.default.availability {
                ContentUnavailableView(
                    "Model Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message(for: reason))
                )
                .navigationTitle("Receipts")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("\(ReceiptDetailView.names.count) photos · On-device extraction")
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                            ForEach(ReceiptDetailView.names, id: \.self) { name in
                                NavigationLink(value: name) {
                                    ReceiptCard(name: name)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                }
                .background(.background.secondary)
                .navigationTitle("Receipts")
                .navigationDestination(for: String.self) { name in
                    ReceiptDetailView(name: name)
                }
            }
        }
    }

    private func message(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            "This device doesn't support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            "Turn on Apple Intelligence in Settings to extract receipts."
        case .modelNotReady:
            "The model is still downloading. Try again in a few minutes."
        @unknown default:
            "Apple Intelligence isn't available right now."
        }
    }
}

/// Grid cell showing the top of the receipt photo, where the store's name is printed.
private struct ReceiptCard: View {
    let name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Color.clear
                .frame(height: 220)
                .overlay(alignment: .top) {
                    Image(name)
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(.rect(cornerRadius: 12))
                .padding(.bottom, 4)
            Text("Receipt \(name)")
                .font(.headline)
            Text("Tap to extract")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .card(padding: 8)
    }
}

#Preview {
    ContentView()
}

#Playground {
    _ = 1 + 2
}
