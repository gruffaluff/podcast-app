import SwiftUI
import PodcastCore

/// A show's settings. Opens straight after following a show, and from the
/// show page. Top show priority is on its own screen, linked last.
struct ShowSettingsView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let show: Podcast
    /// True when shown right after following ("Following …" heading).
    var justFollowed = false

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
                    Toggle("Notify me of new episodes", isOn: binding(\.notify))
                } footer: {
                    Text("Downloads follow your Wi-Fi only setting. Alerts start working in a coming update; your choice is saved.")
                }
                .listRowBackground(Theme.surface)
                .tint(Theme.accentFill)

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
    @State private var shows: [Podcast] = []

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
                skipPicker("Back", selection: Binding(get: { player.skipBackSeconds }, set: { player.setSkipBack($0) }))
                skipPicker("Forward", selection: Binding(get: { player.skipForwardSeconds }, set: { player.setSkipForward($0) }))
            } header: {
                Text("Skip buttons")
            } footer: {
                Text("Seconds skipped by the back and forward buttons, lock screen and headphones. You can also touch and hold a skip button in the player to change it.")
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
                Button("Transcribe Up Next now") { transcripts.transcribeUpNextNow() }
                    .foregroundStyle(Theme.accentText)
            } header: {
                Text("Transcripts")
            } footer: {
                Text(transcripts.schedule.explanation + " Shows that publish their own transcripts don't need transcribing. Any episode can be transcribed straight away with Transcribe now.")
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
