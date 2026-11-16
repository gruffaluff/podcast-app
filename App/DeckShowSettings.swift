import SwiftUI
import PodcastCore

// Deck (Paul, 15 Nov 2026: "add all 4" of the gaps): a show's own settings
// in the Deck look, from the Settings pill on its page. The same grouped
// white cards as the app's Settings: downloads and alerts, playback for
// this show (speed, skip intro / outro) and older episodes. Where new
// episodes go stays on the page itself (Top / Bottom / Nowhere).

struct DeckShowSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let show: Podcast

    var body: some View {
        NavigationStack {
            ScrollView {
                DeckShowSettingsSections(show: show)
                    .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .deckPage()
            .navigationTitle(show.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Theme.outfit(16, .bold))
                }
            }
        }
        .tint(Theme.ink)
    }
}

/// The show settings' groups (downloads and alerts, playback for this
/// show, older episodes), shared by the sheet above and an episode's tab
/// page ("This show", Paul, 16 Nov 2026: one tab = player + episode page +
/// show settings).
struct DeckShowSettingsSections: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    let show: Podcast
    @State private var addedAll = false
    @State private var markedOlder = false
    /// This show's ad skipping (per-show ad skipping, Paul, 15 Nov 2026).
    @State private var adSkip: ShowAdSkip.Mode = .followSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            downloads
            playback
            older
        }
        .onAppear { adSkip = ShowAdSkip.mode(for: show.feedURL) }
        .onChange(of: show.feedURL) { _, feed in adSkip = ShowAdSkip.mode(for: feed) }
    }

    // MARK: Groups

    private var downloads: some View {
        DeckSetGroup("Downloads and alerts",
                     footer: "Downloads follow your Wi-Fi only setting. Keep downloads deletes this show's older downloads beyond the newest few.") {
            DeckSetToggle(title: "Download new episodes", isOn: autoDownload)
            DeckSetLine()
            DeckSetToggle(title: "Alert me for new episodes", detail: "Says where the episode went in Up next",
                          isOn: alerts)
            DeckSetLine()
            DeckSetChoice(icon: "internaldrive", title: "Keep downloads", options: Self.keepOptions,
                          selection: keep)
        }
    }

    private var playback: some View {
        DeckSetGroup("Playback for this show",
                     footer: playbackFooter) {
            DeckSetChoice(icon: "gauge.with.dots.needle.33percent", title: "Speed",
                          options: ShowSettingsView.speedChoices, selection: speed)
            DeckSetLine()
            DeckSetChoice(icon: "forward.end", title: "Skip intro",
                          options: ShowSettingsView.skipOptions, selection: seconds(\.skipIntro))
            DeckSetLine()
            DeckSetChoice(icon: "backward.end", title: "Skip outro",
                          options: ShowSettingsView.skipOptions, selection: seconds(\.skipOutro))
            DeckSetLine()
            DeckSetChoice(icon: "forward.circle", title: "Skip ads", options: adSkipOptions,
                          selection: adSkipBinding)
        }
    }

    private var playbackFooter: String {
        let global: String = player.skipAds ? "on" : "off"
        return "Skip intro starts episodes this far in (only from the beginning). Skip outro moves on this long before the end. "
            + "Skip ads on Default follows Skip ads automatically in Settings (\(global) now); Always or Never is for this show only."
    }

    /// Default says what the global setting is today.
    private var adSkipOptions: [(label: String, value: ShowAdSkip.Mode)] {
        let defaultLabel: String = player.skipAds ? "Default (on)" : "Default (off)"
        return [
            (label: defaultLabel, value: ShowAdSkip.Mode.followSettings),
            (label: "Always", value: ShowAdSkip.Mode.always),
            (label: "Never", value: ShowAdSkip.Mode.never),
        ]
    }

    private var adSkipBinding: Binding<ShowAdSkip.Mode> {
        Binding(get: { adSkip }, set: { mode in
            adSkip = mode
            ShowAdSkip.set(mode, for: show.feedURL)
        })
    }

    private var older: some View {
        DeckSetGroup("Older episodes",
                     footer: "Add all puts every unplayed episode at the end of Up next, oldest first. Nothing extra downloads.") {
            Button(action: addAll) {
                DeckSetRowLabel(icon: addedAll ? "checkmark" : "text.append",
                                title: addedAll ? "Added to Up next" : "Add all to Up next, oldest first",
                                chevron: nil)
            }
            .buttonStyle(.plain)
            .disabled(addedAll)
            DeckSetLine()
            Button(action: markOlder) {
                DeckSetRowLabel(icon: markedOlder ? "checkmark" : "checkmark.circle",
                                title: markedOlder ? "Older episodes marked played" : "Mark older episodes as played",
                                chevron: nil)
            }
            .buttonStyle(.plain)
            .disabled(markedOlder)
        }
    }

    // MARK: Actions and bindings

    private func addAll() {
        store.addBackCatalogue(of: show)
        addedAll = true
    }

    /// Everything but the newest, with Undo.
    private func markOlder() {
        let latest: PodcastEpisode? = store.latestEpisode(of: show)
        let older: [PodcastEpisode] = show.episodes.filter { $0.episodeID != latest?.episodeID && !$0.played }
        store.undoable("Marked \(older.count) played", episodes: older) { store.markPlayed(older) }
        markedOlder = true
    }

    static let keepOptions: [(label: String, value: Int)] =
        [(label: "All", value: 0)] + [1, 2, 3, 5, 10].map { (label: "Latest \($0)", value: $0) }

    private var autoDownload: Binding<Bool> {
        Binding(get: { show.autoDownload }, set: { show.autoDownload = $0; store.save() })
    }

    private var alerts: Binding<Bool> {
        Binding(get: { show.notify }, set: { on in
            show.notify = on
            store.save()
            if on { Task { await NewEpisodeAlerts.requestPermission() } }
            Task { await RealtimeAlerts.publishFollows(store: store) }
        })
    }

    private var keep: Binding<Int> {
        Binding(get: { show.downloadLimit }, set: { store.setDownloadLimit($0, for: show) })
    }

    private var speed: Binding<Double> {
        Binding(get: { show.speedOverride }, set: { value in
            show.speedOverride = value
            store.save()
            player.showSettingsChanged(show)
        })
    }

    private func seconds(_ keyPath: ReferenceWritableKeyPath<Podcast, Double>) -> Binding<Double> {
        Binding(get: { show[keyPath: keyPath] }, set: { value in
            show[keyPath: keyPath] = value
            store.save()
            player.showSettingsChanged(show)
        })
    }
}
