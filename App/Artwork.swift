import SwiftUI

/// Show or episode artwork, with a calm coloured tile and initials while it
/// loads or if there is none.
struct ArtworkView: View {
    let url: URL?
    let title: String
    var size: CGFloat = 52
    var radius: CGFloat = 10

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius))
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Theme.placeholderColor(for: title)
            .overlay(
                Text(Theme.initials(for: title))
                    .font(.system(size: size * 0.34, design: .serif))
                    .foregroundStyle(Theme.background)
            )
    }
}
