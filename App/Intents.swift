import AppIntents
import Foundation

/// The running app's player and library, for Siri / Shortcuts / the Action
/// button / CarPlay (set when the app starts).
@MainActor
enum AppServices {
    static var player: PlayerModel?
    static var store: LibraryStore?
}

/// "Play Up Next": resumes what's playing, or starts the top of Up Next.
struct PlayUpNextIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Play Up Next"
    static let description = IntentDescription("Resumes Poddeck, or plays the first episode in Up Next.")

    @MainActor
    func perform() async throws -> some IntentResult {
        Self.playUpNext()
        return .result()
    }

    @MainActor
    static func playUpNext() {
        guard let player = AppServices.player, let store = AppServices.store else { return }
        if player.nowPlaying != nil {
            player.resume()
        } else if let first = store.queue.first, let episode = store.episode(first.episode.id) {
            player.play(episode)
        }
    }
}

struct PauseIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Pause"
    static let description = IntentDescription("Pauses Poddeck.")

    @MainActor
    func perform() async throws -> some IntentResult {
        AppServices.player?.pause()
        return .result()
    }
}

struct PlayPauseIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Play or Pause"
    static let description = IntentDescription("Plays or pauses Poddeck (handy for the Action button).")

    @MainActor
    func perform() async throws -> some IntentResult {
        if let player = AppServices.player, player.nowPlaying != nil {
            player.togglePlayPause()
        } else {
            PlayUpNextIntent.playUpNext()
        }
        return .result()
    }
}

struct SkipForwardIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Skip Forward"
    static let description = IntentDescription("Skips forward by your skip length.")

    @MainActor
    func perform() async throws -> some IntentResult {
        AppServices.player?.skipForwardBy()
        return .result()
    }
}

struct SkipBackIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Skip Back"
    static let description = IntentDescription("Skips back by your skip length.")

    @MainActor
    func perform() async throws -> some IntentResult {
        AppServices.player?.skipBackward()
        return .result()
    }
}

struct SleepTimerIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Set Sleep Timer"
    static let description = IntentDescription("Pauses Poddeck after a number of minutes.")

    @Parameter(title: "Minutes", default: 30, inclusiveRange: (1, 180))
    var minutes: Int

    @MainActor
    func perform() async throws -> some IntentResult {
        AppServices.player?.setSleepTimer(.minutes(minutes))
        return .result()
    }
}

/// Phrases Siri knows without any setup, and the actions offered in
/// Shortcuts and for the Action button.
struct PoddeckShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: PlayUpNextIntent(), phrases: [
            "Play Up Next in \(.applicationName)",
            "Resume \(.applicationName)",
            "Play my podcasts in \(.applicationName)",
        ], shortTitle: "Play Up Next", systemImageName: "play.fill")
        AppShortcut(intent: PauseIntent(), phrases: ["Pause \(.applicationName)"],
                    shortTitle: "Pause", systemImageName: "pause.fill")
        AppShortcut(intent: SkipForwardIntent(), phrases: ["Skip forward in \(.applicationName)"],
                    shortTitle: "Skip Forward", systemImageName: "goforward")
        AppShortcut(intent: SkipBackIntent(), phrases: ["Skip back in \(.applicationName)"],
                    shortTitle: "Skip Back", systemImageName: "gobackward")
        AppShortcut(intent: SleepTimerIntent(), phrases: ["Set a sleep timer in \(.applicationName)"],
                    shortTitle: "Sleep Timer", systemImageName: "moon.zzz")
    }
}
