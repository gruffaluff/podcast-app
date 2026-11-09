import SwiftUI

/// "Marked played · UNDO" for a few seconds after a change that can be undone.
struct UndoBar: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        if let action = store.undoAction {
            HStack(spacing: 10) {
                Text(action.label.uppercased())
                    .font(Theme.mono(12, .semibold))
                    .foregroundStyle(Theme.displayText)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button { action.restore() } label: {
                    Text("UNDO")
                        .font(Theme.mono(12, .bold))
                        .padding(.horizontal, 12)
                        .frame(minHeight: 34)
                }
                .buttonStyle(KeyButtonStyle(kind: .accent, radius: 8))
            }
            .padding(.leading, 14)
            .padding(.trailing, 8)
            .padding(.vertical, 6)
            .background(Theme.display, in: RoundedRectangle(cornerRadius: 12))
            .task(id: action.id) {
                // Only a full 6 seconds clears it. There's an Undo bar on
                // every tab and in the player; when one leaves the screen its
                // wait is cancelled, and that used to clear the Undo at once
                // (the bar flashed and vanished, Paul's recording, build 127).
                do { try await Task.sleep(for: .seconds(6)) } catch { return }
                if store.undoAction?.id == action.id { store.undoAction = nil }
            }
        }
    }
}
