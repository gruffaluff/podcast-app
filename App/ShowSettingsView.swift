import SwiftUI
import SwiftData
import PodcastCore

/// A show's settings. Opens straight after following a show, and from the
/// show page. Top show priority is on its own screen, linked last.
struct ShowSettingsView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(\.dismiss) private var dismiss
    let show: Podcast
    /// True when shown right after following ("Following …" heading).
    var justFollowed = false
    @State private var olderUnplayed = true
    @State private var addedAll = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        ArtworkView(url: show.artworkURL, title: show.title, size: 64, radius: 10)
                        VStack(alignment: .leading, spacing: 4) {
                            if justFollowed {
                                Text("NOW FOLLOWING")
                                    .font(Theme.mono(10, .semibold))
                                    .foregroundStyle(Theme.muted)
                            }
                            Text(show.title.uppercased())
                                .font(Theme.mono(17, .bold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(2)
                        }
                    }
                }
                .listRowBackground(Theme.background)

                Section {
                    DeckSwitch(options: [(label: "Off", value: AutoAddMode.off), (label: "Top", value: .top), (label: "Bottom", value: .bottom)], selection: autoAdd)
                } header: {
                    DeckHeader(title: "New episodes go to Up Next")
                } footer: {
                    Text(autoAddExplanation)
                }
                .listRowBackground(Theme.background)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

                Section {
                    Toggle("Download new episodes", isOn: binding(\.autoDownload))
                    Toggle("Notify me of new episodes", isOn: Binding(get: { show.notify }, set: { on in
                        show.notify = on
                        store.save()
                        if on { Task { await NewEpisodeAlerts.requestPermission() } }
                    }))
                    DeckPicker(title: "Keep downloads",
                               options: [(label: "All", value: 0)] + [1, 2, 3, 5, 10].map { (label: "Latest \($0)", value: $0) },
                               selection: Binding(get: { show.downloadLimit }, set: { store.setDownloadLimit($0, for: show) }))
                } footer: {
                    Text("Downloads follow your Wi-Fi only setting. Keep downloads deletes this show's older downloads beyond the newest few. Alerts say where the episode went in Up Next.")
                }
                .listRowBackground(Theme.surface)
                .tint(Theme.accentFill)

                Section {
                    DeckPicker(title: "Speed", options: Self.speedChoices, selection: Binding(get: { show.speedOverride }, set: { value in
                        show.speedOverride = value
                        store.save()
                        player.showSettingsChanged(show)
                    }))
                    DeckPicker(title: "Skip intro", options: Self.skipOptions, selection: secondsBinding(\.skipIntro))
                    DeckPicker(title: "Skip outro", options: Self.skipOptions, selection: secondsBinding(\.skipOutro))
                } header: {
                    DeckHeader(title: "Playback for this show")
                } footer: {
                    Text("Skip intro starts episodes this far in (only from the beginning). Skip outro moves on this long before the end.")
                }
                .listRowBackground(Theme.surface)

                // Older episodes as ordinary rows in the paper panel, like
                // the rest of this sheet (Paul, build 127: the black and white
                // keys matched nothing). Add all is here every time the sheet
                // opens, not only right after following (Paul, 9 Nov 2026).
                Section {
                    if justFollowed {
                        Button {
                            let latest = store.latestEpisode(of: show)
                            let older = show.episodes.filter { $0.episodeID != latest?.episodeID }
                            if olderUnplayed { store.markPlayed(older) } else { store.markUnplayed(older) }
                            olderUnplayed.toggle()
                        } label: {
                            olderRow(olderUnplayed ? "Mark older episodes as played" : "Keep older episodes unplayed",
                                     symbol: olderUnplayed ? "checkmark.circle" : "arrow.uturn.backward")
                        }
                    }
                    if olderUnplayed {
                        Button {
                            store.addBackCatalogue(of: show)
                            addedAll = true
                        } label: {
                            olderRow(addedAll ? "Added to Up Next" : "Add all to Up Next, oldest first",
                                     symbol: addedAll ? "checkmark" : "text.append")
                        }
                        .disabled(addedAll)
                    }
                } header: {
                    DeckHeader(title: "Older episodes")
                } footer: {
                    Text(olderUnplayed
                         ? "Add all puts every unplayed episode at the end of Up Next, oldest first, for listening from the very start. It's also in the show page's ⋯ menu."
                         : "The other \(max(0, show.episodes.count - 1)) are marked as played, so only new ones show as unplayed.")
                }
                .listRowBackground(Theme.surface)

                if show.autoAdd == .top {
                    Section {
                        NavigationLink {
                            TopPriorityView()
                        } label: {
                            LabeledContent("Top show priority", value: rankLabel)
                        }
                    } footer: {
                        Text("Choose which Top show comes first in Up Next.")
                    }
                    .listRowBackground(Theme.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("SHOW SETTINGS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var autoAdd: Binding<AutoAddMode> {
        Binding(get: { show.autoAdd }, set: { store.setAutoAdd($0, for: show) })
    }

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

    /// One row in the Older episodes section: the action and its icon.
    private func olderRow(_ title: String, symbol: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accentText)
        }
        .contentShape(Rectangle())
    }

    private func secondsBinding(_ keyPath: ReferenceWritableKeyPath<Podcast, Double>) -> Binding<Double> {
        Binding(get: { show[keyPath: keyPath] }, set: { value in
            show[keyPath: keyPath] = value
            store.save()
            player.showSettingsChanged(show)
        })
    }

    private func binding(_ keyPath: ReferenceWritableKeyPath<Podcast, Bool>) -> Binding<Bool> {
        Binding(get: { show[keyPath: keyPath] }, set: { show[keyPath: keyPath] = $0; store.save() })
    }

    private var rankLabel: String {
        guard let index = store.topShows.firstIndex(where: { $0.feedURL == show.feedURL }) else { return "" }
        return "#\(index + 1) of \(store.topShows.count)"
    }

    private var autoAddExplanation: String {
        switch show.autoAdd {
        case .off: return "New episodes stay on the show page until you add them."
        case .top: return "New episodes go near the top of Up Next, by show priority, each show oldest first."
        case .bottom: return "New episodes go to the end of Up Next, each show oldest first."
        }
    }
}

/// Top shows in priority order. Drag to re-order; Up Next re-sorts to match.
struct TopPriorityView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(DownloadManager.self) private var downloads
    @Environment(PlayerModel.self) private var player
    @Environment(TranscriptService.self) private var transcripts
    @Query(sort: \Podcast.title) private var allShows: [Podcast]
    @AppStorage("afterEpisode") private var afterEpisode = "top"  // PlayerModel.afterEpisodeKey
    @AppStorage("downloadCapGB") private var downloadCapGB = 0  // LibraryStore.downloadCapKey
    @AppStorage("bedtimeSleepTimer") private var bedtimeTimer = false  // PlayerModel.bedtimeKey
    @State private var shows: [Podcast] = []
    @State private var checkHours = BackgroundRefresh.intervalHours
    @State private var findAds = AdScanner.isEnabled
    @State private var showingStorage = false

    var body: some View {
        @Bindable var store = store
        @Bindable var downloads = downloads
        @Bindable var transcripts = transcripts
        List {
            Section {
                if shows.isEmpty {
                    Text("No shows are set to Top yet. Set a show to Top in its settings.")
                        .foregroundStyle(Theme.muted)
                }
                ForEach(Array(shows.enumerated()), id: \.element.feedURL) { index, show in
                    HStack(spacing: 14) {
                        Text(String(format: "%02d", index + 1))
                            .font(Theme.mono(15, .bold))
                            .foregroundStyle(Theme.accentText)
                            .frame(width: 26)
                        ArtworkView(url: show.artworkURL, title: show.title, size: 40, radius: 8)
                        Text(show.title)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                    }
                    // A lifted row keeps rounded corners (it showed white
                    // square corners while dragging).
                    .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 12))
                }
                .onMove { from, to in
                    shows.move(fromOffsets: from, toOffset: to)
                    store.setTopOrder(shows)
                }
            } header: {
                DeckHeader(title: "Top, in priority order")
            } footer: {
                Text("Your favourite goes first. Its new episodes always land above lower-ranked Top shows, whenever they arrive.")
            }
            .listRowBackground(Theme.surface)

            Section {
                ForEach(allShows) { show in
                    AllShowsRow(show: show) { shows = store.topShows }
                }
            } header: {
                DeckHeader(title: "All shows")
            } footer: {
                Text("The bell sends an alert when a new episode arrives, saying where it went in Up Next.")
            }
            .listRowBackground(Theme.surface)

            Section {
                DeckSwitch(options: [(label: "Hourly", value: 1), (label: "3 hours", value: 3), (label: "6 hours", value: 6)],
                           selection: $checkHours)
                .onChange(of: checkHours) { _, hours in
                    BackgroundRefresh.intervalHours = hours
                    BackgroundRefresh.schedule()
                }
            } header: {
                DeckHeader(title: "Checking for new episodes")
            } footer: {
                Text("iOS decides the exact moment, so checks can run a little late. Pull down on Up Next to check now.")
            }
            .listRowBackground(Theme.surface)

            Section {
                skipPicker("Back", selection: Binding(get: { player.skipBackSeconds }, set: { player.setSkipBack($0) }))
                skipPicker("Forward", selection: Binding(get: { player.skipForwardSeconds }, set: { player.setSkipForward($0) }))
            } header: {
                DeckHeader(title: "Skip buttons")
            } footer: {
                Text("Seconds skipped by the back and forward buttons, lock screen and headphones. You can also touch and hold a skip button in the player to change it.")
            }
            .listRowBackground(Theme.surface)

            Section {
                Toggle("Find ads while listening", isOn: $findAds)
                    .onChange(of: findAds) { _, on in AdScanner.isEnabled = on }
                    .tint(Theme.accentFill)
                Toggle("Skip ads automatically", isOn: Binding(get: { player.skipAds }, set: { player.setSkipAds($0) }))
                    .tint(Theme.accentFill)
            } header: {
                DeckHeader(title: "Ads")
            } footer: {
                Text("While a downloaded episode plays, Poddeck checks the next few minutes for sponsor reads on your iPhone. When an ad starts, a Skip ad button appears (or it skips by itself if you turn that on). Breaks are marked on the scrubber; tap Not an ad to correct one.")
            }
            .listRowBackground(Theme.surface)

            Section {
                Toggle("Keep each show in order", isOn: $store.keepShowOrder)
                    .tint(Theme.accentFill)
            } footer: {
                Text("Play next and Play last never put an episode before an older one from the same show.")
            }
            .listRowBackground(Theme.surface)

            Section {
                Toggle("Bedtime sleep timer", isOn: $bedtimeTimer)
                    .tint(Theme.accentFill)
            } footer: {
                Text("Starting an episode between 10pm and 5am sets the sleep timer to the one you last chose (end of episode at first).")
            }
            .listRowBackground(Theme.surface)

            Section {
                DeckPicker(title: "After an episode, play",
                           options: [(label: "Top of Up Next", value: "top"), (label: "Next in the list", value: "next")],
                           selection: $afterEpisode)
            } footer: {
                Text(afterEpisode == "next" ? "Carries on with the episode that was below it in Up Next." : "Always goes back to the top of Up Next.")
            }
            .listRowBackground(Theme.surface)

            Section {
                // A menu picker, as this screen's list stays in edit mode for dragging.
                DeckPicker(title: "Transcribe",
                           options: TranscriptService.Schedule.allCases.map { (label: $0.label, value: $0) },
                           selection: $transcripts.schedule)
                DeckActionRow(title: "Up Next", key: "Transcribe now", main: true) { transcripts.transcribeUpNextNow() }
                if transcripts.isBusy {
                    // Not red: stopping can be undone with Transcribe now.
                    DeckActionRow(title: "Transcribing", key: "Stop all") { transcripts.stopAll() }
                }
            } header: {
                DeckHeader(title: "Transcripts")
            } footer: {
                Text(transcripts.schedule.explanation + " Shows that publish their own transcripts don't need transcribing. Any episode can be transcribed straight away with Transcribe now.")
            }
            .listRowBackground(Theme.surface)
            .tint(Theme.accentFill)

            // Its own little section (Paul: it isn't about transcripts).
            Section {
                DeckActionRow(title: "Artwork", key: "Refresh") {
                    ArtworkImageCache.shared.clear()
                    ArtworkColors.shared.clear()
                }
            } header: {
                DeckHeader(title: "Artwork")
            } footer: {
                Text("Fetches every show's artwork and colours again, if one looks wrong or out of date.")
            }
            .listRowBackground(Theme.surface)

            Section {
                Toggle("Download on Wi-Fi only", isOn: $downloads.wifiOnly)
                    .tint(Theme.accentFill)
                Toggle("Keep played downloads for 24 hours", isOn: $store.keepPlayedDownloads)
                    .tint(Theme.accentFill)
                DeckPicker(title: "Keep downloads under",
                           options: [(label: "No limit", value: 0)] + [2, 5, 10, 20].map { (label: "\($0) GB", value: $0) },
                           selection: $downloadCapGB)
                .onChange(of: downloadCapGB) { store.applyStorageCap() }
            } header: {
                DeckHeader(title: "Downloads")
            } footer: {
                Text("New episodes download automatically for shows with downloads on. Played episodes' downloads are deleted straight away to save space, unless you keep them for 24 hours. Downloads you start yourself go straight away. Over the limit, the oldest go first: played ones, then ones not in Up Next, then the end of Up Next (never what's playing).")
            }
            .listRowBackground(Theme.surface)

            Section {
                // A button (this list stays in edit mode, where links can't be tapped).
                Button { showingStorage = true } label: {
                    Label("Storage", systemImage: "internaldrive")
                        .foregroundStyle(Theme.ink)
                }
            } footer: {
                Text("How much space downloads take, per show, with delete and \"keep latest\" limits.")
            }
            .listRowBackground(Theme.surface)

            ImportExportSection()

            Section {
                HStack(spacing: 8) {
                    LED(on: CloudSync.isSignedIn, color: Theme.accentFill)
                    Text(CloudSync.isSignedIn ? "SYNCING WITH ICLOUD" : "ICLOUD OFF")
                        .font(Theme.mono(12, .bold))
                        .foregroundStyle(Theme.ink)
                }
                .accessibilityElement(children: .combine)
                ICloudStatusRows()
            } header: {
                DeckHeader(title: "iCloud")
            } footer: {
                Text(CloudSync.isSignedIn
                     ? "Your shows, Up Next, progress, bookmarks and settings are saved to your iCloud, so they come back if you reinstall Poddeck or get a new iPhone. Downloads and transcripts stay on this iPhone; downloads come back by themselves."
                     : "Sign in to iCloud in the Settings app to keep your shows, Up Next and progress safe if you reinstall Poddeck. Everything is still saved on this iPhone.")
            }
            .listRowBackground(Theme.surface)

            DiagnosticsSection()
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .environment(\.editMode, .constant(.active))
        .navigationTitle("SHOWS")
        .navigationDestination(isPresented: $showingStorage) { StorageView() }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { shows = store.topShows }
    }

    private func skipPicker(_ title: String, selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(Theme.mono(11, .semibold))
                .foregroundStyle(Theme.muted)
            DeckSwitch(options: PlayerOptions.skipLengths.map { (label: "\($0)s", value: $0) }, selection: selection)
        }
        .padding(.vertical, 4)
    }
}

/// A show in the Shows screen's "All shows" list: bell and Off / Top / Bottom.
private struct AllShowsRow: View {
    @Environment(LibraryStore.self) private var store
    let show: Podcast
    /// Called after the mode changes (the Top list may need refreshing).
    let changed: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: show.artworkURL, title: show.title, size: 36, radius: 6)
            Text(show.title)
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Spacer(minLength: 4)
            Button {
                show.notify.toggle()
                store.save()
                if show.notify { Task { await NewEpisodeAlerts.requestPermission() } }
            } label: {
                Image(systemName: show.notify ? "bell.fill" : "bell")
                    .foregroundStyle(show.notify ? Theme.accentText : Theme.muted)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(show.notify ? "Alerts on" : "Alerts off")
            Menu {
                Picker("New episodes", selection: Binding(get: { show.autoAdd }, set: { store.setAutoAdd($0, for: show); changed() })) {
                    Text("Off").tag(AutoAddMode.off)
                    Text("Top").tag(AutoAddMode.top)
                    Text("Bottom").tag(AutoAddMode.bottom)
                }
            } label: {
                Text(show.autoAdd == .bottom ? "BTM ▾" : "\(show.autoAdd.rawValue.uppercased()) ▾")
                    .font(Theme.mono(11, .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10)
                    .frame(minWidth: 64, minHeight: 32)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel("New episodes go to: \(show.autoAdd.rawValue)")
        }
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
            line("ALERTS", status["Alerts"] ?? "nothing yet (pull down on Up Next)", bad: status["Alerts"]?.hasPrefix("PROBLEM") ?? false)
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
