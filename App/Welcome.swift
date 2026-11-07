import Network
import SwiftUI

/// Whether the iPhone can reach the internet right now, for the
/// "No internet" bar (Paul, 7 Nov 2026: say so clearly rather than leave
/// lists spinning).
@MainActor @Observable
final class NetworkStatus {
    static let shared = NetworkStatus()

    private(set) var online = true
    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { path in
            let online = path.status == .satisfied
            Task { @MainActor in NetworkStatus.shared.online = online }
        }
        monitor.start(queue: DispatchQueue(label: "network-status"))
    }
}

/// A small bar above the mini player while there's no internet.
struct OfflineBar: View {
    private var network = NetworkStatus.shared

    var body: some View {
        if !network.online {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                Text("NO INTERNET · DOWNLOADS STILL PLAY")
                    .font(Theme.mono(11, .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.displayText)
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .background(Theme.display, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("No internet. Downloaded episodes still play.")
        }
    }
}

/// First open, with nothing followed yet: what Poddeck is and where to
/// start. Shown once.
struct WelcomeView: View {
    static let seenKey = "welcomeSeen"

    /// Goes to Discover.
    let findShows: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("PODDECK")
                    .font(Theme.big(52))
                    .foregroundStyle(Theme.ink)
                Text("A podcast app that runs on your iPhone. No account, no subscription, no adverts.")
                    .font(.title3)
                    .foregroundStyle(Theme.ink)
                VStack(alignment: .leading, spacing: 16) {
                    point("list.bullet", "Up Next fills itself", "Set each show to Top or Bottom and new episodes go in the right place, oldest first.")
                    point("text.quote", "Transcripts on your phone", "Made on the iPhone when you ask. Nothing leaves it.")
                    point("icloud", "Backed up to your iCloud", "Shows, Up Next and progress come back on a new phone.")
                }
                VStack(spacing: 10) {
                    Button {
                        dismiss()
                        findShows()
                    } label: {
                        Text("FIND SHOWS")
                            .font(Theme.mono(14, .bold))
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(KeyButtonStyle(kind: .dark))
                    Button { dismiss() } label: {
                        Text("LOOK AROUND FIRST")
                            .font(Theme.mono(13, .bold))
                            .frame(maxWidth: .infinity, minHeight: 46)
                    }
                    .buttonStyle(KeyButtonStyle(kind: .plain))
                }
                Text("Moving from another app? Up Next → sliders → Import & export reads its OPML file.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
            .padding(24)
            .padding(.top, 20)
        }
        .background(Theme.background)
        .onDisappear { UserDefaults.standard.set(true, forKey: Self.seenKey) }
    }

    private func point(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.accentText)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(Theme.ink)
                Text(detail).font(.subheadline).foregroundStyle(Theme.muted)
            }
        }
    }
}
