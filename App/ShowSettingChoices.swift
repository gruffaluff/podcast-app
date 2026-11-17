import SwiftUI
import PodcastCore

/// The choices for a show's own speed and intro / outro skips (Deck show
/// settings).
enum ShowSettingChoices {
    static let skipChoices: [Double] = [0, 10, 15, 20, 30, 45, 60, 90, 120]
    static var skipOptions: [(label: String, value: Double)] {
        skipChoices.map { (label: skipLabel($0), value: $0) }
    }
    static var speedChoices: [(label: String, value: Double)] {
        [(label: "Same as everything", value: 0.0)] + PlayerOptions.speeds.map { (label: PlayerOptions.speedLabel($0), value: $0) }
    }

    static func skipLabel(_ seconds: Double) -> String {
        let whole = Int(seconds)
        if whole == 0 { return "Off" }
        if whole < 60 { return "\(whole)s" }
        let rest = whole % 60
        return rest == 0 ? "\(whole / 60)m" : "\(whole / 60)m \(rest)s"
    }
}

/// Account, sync and alerts status lines for the iCloud section, so a
/// problem is visible instead of silent.
struct ICloudStatusRows: View {
    @State private var account = "checking…"
    @State private var status = CloudSync.status

    var body: some View {
        Group {
            line("ACCOUNT", account, bad: account != "available")
            line("SYNC", status["Sync"] ?? "nothing yet", bad: status["Sync"]?.hasPrefix("PROBLEM") ?? false)
            if RealtimeAlerts.isKnownNonOwner {
                line("ALERTS", RealtimeAlerts.nonOwnerNote, bad: false)
            } else {
                line("ALERTS", status["Alerts"] ?? "nothing yet (pull down on Up Next)", bad: status["Alerts"]?.hasPrefix("PROBLEM") ?? false)
            }
        }
        .task {
            account = await CloudSync.accountDescription()
            status = CloudSync.status
        }
    }

    private func line(_ title: String, _ text: String, bad: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(Theme.mono(10, .bold)).foregroundStyle(bad ? Theme.accentText : Theme.muted)
            Text(text).font(Theme.text(12)).foregroundStyle(Theme.ink).textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }
}
