import SwiftUI
import PodcastCore

/// One show: its details, its Up Next setting and its episodes, newest first.
struct ShowView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(\.dismiss) private var dismiss
    let show: Podcast
    @State private var confirmingUnfollow = false
    @State private var showingSettings = false
    /// Show only unplayed episodes (default), or every episode.
    @State private var showAll = false
    @State private var confirmingMarkAll = false
    /// Select mode: tick episodes (or Select All), then mark them played/unplayed.
    @State private var selecting = false
    @State private var selection: Set<String> = []

    var body: some View {
        let allEpisodes = show.episodes.sorted { $0.published > $1.published }
        let unplayedCount = allEpisodes.filter { !$0.played }.count
        let episodes = showAll ? allEpisodes : allEpisodes.filter { !$0.played }

        List(selection: $selection) {
            Section {
                header
                    .listRowBackground(Theme.background)
                    .listRowSeparator(.hidden)
            }
            Section {
                ForEach(episodes) { episode in
                    Group {
                        if selecting {
                            row(episode)
                        } else {
                            episodeButton(episode, allEpisodes: allEpisodes)
                        }
                    }
                    .tag(episode.episodeID)
                }
                .listRowBackground(Theme.background)
                .listRowSeparatorTint(Theme.hairline)
            } header: {
                DeckSwitch(options: [(label: "Unplayed \(unplayedCount)", value: false), (label: "All \(allEpisodes.count)", value: true)], selection: $showAll)
                    .textCase(nil)
                    .padding(.vertical, 6)
                    .background(Theme.background)
            } footer: {
                if episodes.isEmpty {
                    Text(showAll ? "No episodes yet." : "You're all caught up. Switch to All to see played episodes.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .environment(\.editMode, .constant(selecting ? .active : .inactive))
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(selecting)
        .toolbar {
            if selecting {
                ToolbarItem(placement: .topBarLeading) {
                    let allSelected = !episodes.isEmpty && selection.count == episodes.count
                    Button(allSelected ? "Deselect All" : "Select All") {
                        selection = allSelected ? [] : Set(episodes.map(\.episodeID))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { endSelecting() }.fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Mark as played") {
                        store.markPlayed(allEpisodes.filter { selection.contains($0.episodeID) })
                        endSelecting()
                    }
                    .disabled(selection.isEmpty)
                    Spacer()
                    Text(selection.isEmpty ? "None selected" : "\(selection.count) selected")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Button("Mark as unplayed") {
                        store.markUnplayed(allEpisodes.filter { selection.contains($0.episodeID) })
                        endSelecting()
                    }
                    .disabled(selection.isEmpty)
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Select") { selecting = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Show settings", systemImage: "slider.horizontal.3") { showingSettings = true }
                        Button("Select episodes", systemImage: "checkmark.circle") { selecting = true }
                        Button("Mark all as played", systemImage: "checkmark.circle.fill") { confirmingMarkAll = true }
                        Button("Mark all as unplayed", systemImage: "circle") { store.markUnplayed(show.episodes) }
                        Button("Unfollow", systemImage: "minus.circle", role: .destructive) { confirmingUnfollow = true }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("More")
                }
            }
        }
        .sheet(isPresented: $showingSettings) { ShowSettingsView(show: show) }
        .confirmationDialog("Mark all \(show.episodes.count) episodes as played?", isPresented: $confirmingMarkAll, titleVisibility: .visible) {
            Button("Mark all as played") { store.markPlayed(show.episodes) }
        } message: {
            Text("They leave Up Next and stop showing as unplayed. You can undo this with Mark all as unplayed.")
        }
        .confirmationDialog("Unfollow \(show.title)?", isPresented: $confirmingUnfollow, titleVisibility: .visible) {
            Button("Unfollow", role: .destructive) {
                player.stopIfPlaying(showFeedURL: show.feedURL)
                dismiss()
                // Delete once this screen has closed, so it never shows a removed show.
                let show = show
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    store.unfollow(show)
                }
            }
        } message: {
            Text("Its episodes leave Up Next and your library.")
        }
    }

    private func endSelecting() {
        selecting = false
        selection = []
    }

    private func row(_ episode: PodcastEpisode) -> some View {
        EpisodeRow(episode: episode, isPlaying: player.nowPlaying?.episodeID == episode.episodeID, isQueued: store.isQueued(episode))
    }

    private func episodeButton(_ episode: PodcastEpisode, allEpisodes: [PodcastEpisode]) -> some View {
        Button { player.play(episode) } label: {
            row(episode)
        }
        .buttonStyle(.plain)
        .contextMenu {
            EpisodeMenuItems(episode: episode)
            Button("Mark this and older as played", systemImage: "text.badge.checkmark") {
                store.markPlayed(allEpisodes.filter { $0.published <= episode.published })
            }
        }
        .swipeActions(edge: .trailing) {
            if episode.played {
                Button("Unplayed") { store.markUnplayed(episode) }.tint(Theme.muted)
            } else {
                Button("Played") { store.markPlayed(episode.episodeID) }.tint(Theme.accentFill)
            }
        }
        .swipeActions(edge: .leading) {
            Button("Play next") { store.playNext(episode) }
                .tint(Theme.accentFill)
            Button("Play last") { store.playLast(episode) }
                .tint(Theme.ink)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                ArtworkView(url: show.artworkURL, title: show.title, size: 110, radius: 10)
                VStack(alignment: .leading, spacing: 6) {
                    Text(show.title.uppercased())
                        .font(Theme.mono(19, .bold))
                        .foregroundStyle(Theme.ink)
                    if !show.author.isEmpty {
                        Text(show.author.uppercased())
                            .font(Theme.mono(11))
                            .foregroundStyle(Theme.muted)
                    }
                    HStack(spacing: 6) {
                        DeckTag(text: "\(show.episodes.count) EPS")
                        if show.notify { DeckTag(text: "BELL") }
                        if show.autoDownload { DeckTag(text: "AUTO DL") }
                    }
                    .padding(.top, 2)
                }
            }
            if !show.summary.isEmpty {
                Text(show.summary)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(4)
            }
            VStack(alignment: .leading, spacing: 6) {
                DeckHeader(title: "New episodes → Up Next")
                DeckSwitch(options: [(label: "Off", value: AutoAddMode.off), (label: "Top", value: .top), (label: "Bottom", value: .bottom)], selection: autoAdd)
                Text(autoAddExplanation)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.vertical, 8)
    }

    private var autoAdd: Binding<AutoAddMode> {
        Binding(get: { show.autoAdd }, set: { store.setAutoAdd($0, for: show) })
    }

    private var autoAddExplanation: String {
        switch show.autoAdd {
        case .off: return "New episodes stay here until you add them."
        case .top: return "New episodes go near the top of Up Next, always in order, oldest first."
        case .bottom: return "New episodes go to the end of Up Next, always in order, oldest first."
        }
    }
}

private struct EpisodeRow: View {
    @Environment(DownloadManager.self) private var downloads
    let episode: PodcastEpisode
    let isPlaying: Bool
    let isQueued: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if isPlaying { LED(on: true, color: Theme.accentFill) }
                Text(episode.published.formatted(date: .abbreviated, time: .omitted).uppercased())
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.muted)
            }
            Text(episode.title)
                .font(.body.weight(.medium))
                .foregroundStyle(episode.played ? Theme.muted : Theme.ink)
                .lineLimit(2)
            if !episode.summary.isEmpty {
                Text(episode.summary)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
            }
            Text(meta.uppercased())
                .font(Theme.mono(10))
                .foregroundStyle(isPlaying ? Theme.accentText : Theme.muted)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var meta: String {
        var parts: [String] = []
        if isPlaying { parts.append("Playing") }
        if episode.played {
            parts.append("Played")
        } else if let left = episode.timeLeft, left > 0 {
            parts.append(episode.position > 30 ? "\(TimeFormat.length(left)) left" : TimeFormat.length(left))
        }
        if isQueued { parts.append("In Up Next") }
        if !episode.played, let download = downloads.status(for: episode) { parts.append(download) }
        return parts.joined(separator: " · ")
    }
}
