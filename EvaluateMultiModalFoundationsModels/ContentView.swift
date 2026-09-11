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
                    description: Text(String(describing: reason))
                )
            } else {
                List(ReceiptDetailView.names, id: \.self) { name in
                    NavigationLink(value: name) {
                        HStack {
                            Image(name)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 48)
                            Text("Receipt \(name)")
                        }
                    }
                }
                .navigationTitle("Receipts")
                .navigationDestination(for: String.self) { name in
                    ReceiptDetailView(name: name)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

#Playground {
    _ = 1 + 2
}
