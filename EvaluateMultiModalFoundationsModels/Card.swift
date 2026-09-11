import SwiftUI

extension View {
    /// Rounded surface on the grouped background, as in the Stitch mockups.
    func card(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: .rect(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}

/// Small uppercase label above a card, like an inset-grouped section header.
struct SectionHeader: View {
    let title: LocalizedStringKey
    var trailing: LocalizedStringKey?

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if let trailing {
                Text(trailing)
            }
        }
        .font(.caption)
        .textCase(.uppercase)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
    }
}
