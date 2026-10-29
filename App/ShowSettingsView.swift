import SwiftUI
import SwiftData
import PodcastCore

/// A show's settings. Opens straight after following a show, and from the
/// show page. Top show priority is on its own screen, linked last.
struct ShowSettingsView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let show: Podcast
    /// True when shown right after following ("Following …" heading).
    var justFollowed = false
    @State private var olderUnplayed = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        ArtworkView(url: show.artworkURL, title: show.title, size: 64, radius: 10)
                        VStack(alignment: .leading, spacing: 4) {
                            if justFollowed {
                                Text("Now following")
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                            }
                            Text(show.title)
                                .font(Theme.screenTitle(20))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(2)
                        }
                    }
                }
                .listRowBackground(Theme.background)

                Section {
                    Picker("New episodes go to Up Next", selection: autoAdd) {
                        Text("Off").tag(AutoAddMode.off)
                        Text("Top").tag(AutoAddMode.top)
                        Text("Bottom").tag(AutoAddMode.bottom)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                } header: {
                    Text("New episodes go to Up Next")
                } footer: {
                    Text(autoAddExplanation)
                }
                .listRowBackground(Theme.surface)

                Section {
                    Toggle("Download new episodes", isOn: binding(\.autoDownload))
                    Toggle("Notify me of new episodes", isOn: Binding(get: { show.notify }, set: { on in
                        show.notify = on
                        store.save()
                        if on { Task { await NewEpisodeAlerts.requestPermission() } }
                    }))
                } footer: {
                    Text("Downloads follow your Wi-Fi only setting. Alerts say where the episode went in Up Next.")
                }
                .listRowBackground(Theme.surface)
                .tint(Theme.accentFill)

                if justFollowed {
                    Section {
                        Button(olderUnplayed ? "Mark older episodes as played" : "Keep older episodes unplayed") {
                            let latest = store.latestEpisode(of: show)
                            let older = show.episodes.filter { $0.episodeID != latest?.episodeID }
                            if olderUnplayed { store.markPlayed(older) } else { store.markUnplayed(older) }
                            olderUnplayed.toggle()
                        }
                        .foregroundStyle(Theme.accentText)
                    } header: {
                        Text("Older episodes")
                    } footer: {
                        Text(olderUnplayed
                             ? "All \(show.episodes.count) episodes are unplayed."
                             : "The newest episode is downloading. The other \(max(0, show.episodes.count - 1)) are marked as played, so only new ones show as unplayed.")
                    }
                    .listRowBackground(Theme.surface)
                }

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
            .navigationTitle("Show settings")
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
    @State private var shows: [Podcast] = []
    @State private var checkHours = BackgroundRefresh.intervalHours
    @State private var labelSpeakers = SpeakerSeparation.isEnabled

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
                        Text("\(index + 1)")
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(Theme.accentText)
                            .frame(width: 22)
                        ArtworkView(url: show.artworkURL, title: show.title, size: 40, radius: 8)
                        Text(show.title)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                    }
                }
                .onMove { from, to in
                    shows.move(fromOffsets: from, toOffset: to)
                    store.setTopOrder(shows)
                }
            } header: {
                Text("Top, in priority order")
            } footer: {
                Text("Your favourite goes first. Its new episodes always land above lower-ranked Top shows, whenever they arrive.")
            }
            .listRowBackground(Theme.background)

            Section {
                ForEach(allShows) { show in
                    AllShowsRow(show: show) { shows = store.topShows }
                }
            } header: {
                Text("All shows")
            } footer: {
                Text("The bell sends an alert when a new episode arrives, saying where it went in Up Next.")
            }
            .listRowBackground(Theme.background)

            Section {
                Picker("Check for new episodes", selection: $checkHours) {
                    Text("Hourly").tag(1)
                    Text("Every 3 hours").tag(3)
                    Text("Every 6 hours").tag(6)
                }
                .pickerStyle(.segmented)
                .onChange(of: checkHours) { _, hours in
                    BackgroundRefresh.intervalHours = hours
                    BackgroundRefresh.schedule()
                }
            } header: {
                Text("Checking for new episodes")
            } footer: {
                Text("iOS decides the exact moment, so checks can run a little late. Pull down on Up Next to check now.")
            }
            .listRowBackground(Theme.background)

            Section {
                skipPicker("Back", selection: Binding(get: { player.skipBackSeconds }, set: { player.setSkipBack($0) }))
                skipPicker("Forward", selection: Binding(get: { player.skipForwardSeconds }, set: { player.setSkipForward($0) }))
            } header: {
                Text("Skip buttons")
            } footer: {
                Text("Seconds skipped by the back and forward buttons, lock screen and headphones. You can also touch and hold a skip button in the player to change it.")
            }
            .listRowBackground(Theme.background)

            Section {
                Toggle("Skip ads automatically", isOn: Binding(get: { player.skipAds }, set: { player.setSkipAds($0) }))
                    .tint(Theme.accentFill)
            } header: {
                Text("Ads")
            } footer: {
                Text("Ad breaks are found in each downloaded episode's transcript on your iPhone. Skipped breaks are marked on the scrubber; tap Play ad or Not an ad to correct one.")
            }
            .listRowBackground(Theme.background)

            Section {
                Toggle("Keep each show in order", isOn: $store.keepShowOrder)
                    .tint(Theme.accentFill)
            } footer: {
                Text("Play next and Play last never put an episode before an older one from the same show.")
            }
            .listRowBackground(Theme.background)

            Section {
                // A menu picker, as this screen's list stays in edit mode for dragging.
                Picker("Transcribe", selection: $transcripts.schedule) {
                    ForEach(TranscriptService.Schedule.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.menu)
                Toggle("Label speakers", isOn: $labelSpeakers)
                    .onChange(of: labelSpeakers) { _, on in SpeakerSeparation.isEnabled = on }
                Button("Transcribe Up Next now") { transcripts.transcribeUpNextNow() }
                    .foregroundStyle(Theme.accentText)
            } header: {
                Text("Transcripts")
            } footer: {
                Text(transcripts.schedule.explanation + " Shows that publish their own transcripts don't need transcribing. Any episode can be transcribed straight away with Transcribe now. Label speakers works out who is talking (Speaker 1, Speaker 2…); it downloads a small model once.")
            }
            .listRowBackground(Theme.background)
            .tint(Theme.accentFill)

            Section {
                Toggle("Download on Wi-Fi only", isOn: $downloads.wifiOnly)
                    .tint(Theme.accentFill)
                Toggle("Keep played downloads for 24 hours", isOn: $store.keepPlayedDownloads)
                    .tint(Theme.accentFill)
            } header: {
                Text("Downloads")
            } footer: {
                Text("New episodes download automatically for shows with downloads on. Played episodes' downloads are deleted straight away to save space, unless you keep them for 24 hours. Downloads you start yourself go straight away.")
            }
            .listRowBackground(Theme.background)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Shows")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { shows = store.topShows }
    }

    private func skipPicker(_ title: String, selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
            Picker(title, selection: selection) {
                ForEach(PlayerOptions.skipLengths, id: \.self) { Text("\($0)s").tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
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
                Text(show.autoAdd.rawValue.capitalized)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10)
                    .frame(minWidth: 64, minHeight: 32)
                    .background(Theme.surface, in: Capsule())
            }
            .accessibilityLabel("New episodes go to: \(show.autoAdd.rawValue)")
        }
    }
}
