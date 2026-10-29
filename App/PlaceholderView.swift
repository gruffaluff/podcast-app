import SwiftUI

struct PlaceholderView: View {
    let title: String
    let note: String

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(note)
                    .foregroundStyle(Theme.muted)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Theme.background)
            .navigationTitle(title)
        }
    }
}
