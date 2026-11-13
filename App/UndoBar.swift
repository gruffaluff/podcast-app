import SwiftUI

/// "Marked played · UNDO" for a few seconds after a change that can be undone.
struct UndoBar: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        // Slides up and away instead of popping in and out.
        ZStack {
            if let action = store.undoAction {
                Group {
                    if Theme.isHaar { toast(action) } else { bar(action) }
                }
                .transition(.move(edge: Theme.isHaar ? .top : .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.3), value: store.undoAction?.id)
    }

    /// Haar (prototype): a dark toast near the top, "Marked played  Undo".
    private func toast(_ action: UndoAction) -> some View {
        HStack(spacing: 12) {
            Text(action.label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: 0xF4F2EE))
                .lineLimit(1)
            Spacer(minLength: 8)
            Button { action.restore() } label: {
                Text("Undo")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: 0xF4F2EE))
                    .underline()
                    .frame(minHeight: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
        .background(Color(hex: 0x1F2328), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
        .task(id: action.id) {
            do { try await Task.sleep(for: .seconds(6)) } catch { return }
            if store.undoAction?.id == action.id { store.undoAction = nil }
        }
    }

    private func bar(_ action: UndoAction) -> some View {
        Group {
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
