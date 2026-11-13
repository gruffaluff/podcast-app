import SwiftUI
import UIKit
import PodcastCore

/// Haar: a show opens as a sheet over whatever you're on, with Episodes /
/// Settings as two words at the top (Paul, 13 Nov 2026: "let's work the
/// show page"). Swipe it down or tap Done to go back where you were.
/// Episodes is the usual show page (`ShowView`, kept alive so it keeps its
/// place); Settings is the show's settings (`ShowSettingsView`, embedded).
struct HaarShowSheet: View {
    @Environment(LibraryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let show: Podcast
    @State private var onSettings = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 22) {
                pageWord("Episodes", on: !onSettings) { onSettings = false }
                pageWord("Settings", on: onSettings) { onSettings = true }
                Spacer(minLength: 8)
                Button("Done") { dismiss() }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 6)
            ZStack {
                NavigationStack { ShowView(show: show) }
                    .opacity(onSettings ? 0 : 1)
                    .allowsHitTesting(!onSettings)
                    .accessibilityHidden(onSettings)
                if onSettings {
                    ShowSettingsView(show: show, embedded: true)
                }
            }
        }
        .haarPage()
        .environment(\.openShowSettings, { withAnimation(.easeOut(duration: 0.2)) { onSettings = true } })
        // An episode page opened from here sits over this sheet (the root
        // view can't show one while this is up).
        .sheet(item: Binding(get: { store.notesEpisode }, set: { store.notesEpisode = $0 })) { episode in
            EpisodeNotesView(episode: episode)
        }
        .presentationDragIndicator(.visible)
    }

    private func pageWord(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { action() }
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: on ? .semibold : .regular))
                    .foregroundStyle(on ? Theme.ink : Theme.muted)
                Capsule()
                    .fill(on ? Theme.ink : Color.clear)
                    .frame(width: 18, height: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

private struct OpenShowSettingsKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

private struct HaarGoHomeKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// Set inside the Haar show sheet: the show page's settings key and
    /// "Show settings" menu item switch to its Settings page instead of
    /// opening another sheet.
    var openShowSettings: (() -> Void)? {
        get { self[OpenShowSettingsKey.self] }
        set { self[OpenShowSettingsKey.self] = newValue }
    }

    /// Set on Haar's Library layer: a swipe right on Library's first page
    /// goes back to Now.
    var haarGoHome: (() -> Void)? {
        get { self[HaarGoHomeKey.self] }
        set { self[HaarGoHomeKey.self] = newValue }
    }
}

/// A swipe to the right (only begins when the finger moves sideways, so
/// scrolling up and down isn't touched). Fires once it has gone 80 points
/// or is flicked.
struct SwipeRight: UIGestureRecognizerRepresentable {
    var isEnabled = true
    let action: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        pan.isEnabled = isEnabled
        return pan
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        guard recognizer.state == .ended else { return }
        let moved: CGFloat = recognizer.translation(in: nil).x
        let speed: CGFloat = recognizer.velocity(in: nil).x
        if moved > 80 || (moved > 30 && speed > 600) {
            action()
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity: CGPoint = pan.velocity(in: nil)
            return velocity.x > 0 && velocity.x > abs(velocity.y) * 1.5
        }
    }
}
