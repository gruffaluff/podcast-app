import SwiftUI

/// "Marked played · UNDO" for a few seconds after a change that can be undone.
struct UndoBar: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        // Slides up and away instead of popping in and out.
        ZStack {
            if let action = store.undoAction {
                deckBar(action)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.3), value: store.undoAction?.id)
    }

    /// The label, and under it the note when there is one.
    private func deckWords(_ action: UndoAction) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(action.label)
                .font(Theme.outfit(15, .semibold))
                .foregroundStyle(Color.white)
                .lineLimit(1)
            if let note = action.note {
                Text(note)
                    .font(Theme.outfit(12, .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .lineLimit(2)
            }
        }
    }

    /// Deck (Paul, 15 Nov 2026: it was "the same colour as the background
    /// so gets lost"): a near-black bar with white words and a white Undo
    /// pill, a soft shadow, on the cards' 16 pt edges.
    private func deckBar(_ action: UndoAction) -> some View {
        HStack(spacing: 12) {
            deckWords(action)
            Spacer(minLength: 8)
            Button { action.restore() } label: {
                Text("Undo")
                    .font(Theme.outfit(15, .bold))
                    .foregroundStyle(Color(hex: 0x2A2826))
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(Capsule().fill(Color.white))
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .padding(.vertical, action.note == nil ? 0 : 8)
        .frame(minHeight: 52)
        .background { deckBarBackground }
        .compositingGroup()
        .shadow(color: .black.opacity(0.38), radius: 18, y: 8)
        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        .task(id: action.id) {
            do { try await Task.sleep(for: .seconds(6)) } catch { return }
            if store.undoAction?.id == action.id { store.undoAction = nil }
        }
    }

    /// Paul, 16 Nov 2026: the near-black bar got "a bit lost on dark
    /// background" (full-colour tab cards, dark artwork). A slightly lighter
    /// ink with a fine light edge, so it shows on dark art as well as on
    /// the light page.
    private var deckBarBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return shape
            .fill(Color(hex: 0x2A2826))
            .overlay(shape.strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
    }
}
