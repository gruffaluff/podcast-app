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
    /// The episode opened up to show its keys (one at a time).
    @State private var expanded: String?
    /// Search within this show's episodes (titles and notes).
    @State private var search = ""

    var body: some View {
        let allEpisodes = show.episodes.sorted { $0.published > $1.published }
        let unplayedCount = allEpisodes.filter { !$0.played }.count
        let term = search.trimmingCharacters(in: .whitespaces)
        let filtered = showAll || !term.isEmpty ? allEpisodes : allEpisodes.filter { !$0.played }
        let episodes = term.isEmpty ? filtered : filtered.filter {
            $0.title.localizedCaseInsensitiveContains(term) || $0.summary.localizedCaseInsensitiveContains(term)
        }

        List(selection: $selection) {
            Section {
                header
                    .listRowBackground(Theme.background)
                    .listRowSeparator(.hidden)
                DeckSwitch(options: [(label: "Unplayed \(unplayedCount)", value: false), (label: "All \(allEpisodes.count)", value: true)], selection: $showAll)
                    .listRowBackground(Theme.background)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 6, trailing: 16))
                    .selectionDisabled()
                if episodes.isEmpty {
                    Text(!term.isEmpty ? "No episodes match “\(term)”." : showAll ? "No episodes yet." : "You're all caught up. Switch to All to see played episodes.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .listRowBackground(Theme.background)
                        .listRowSeparator(.hidden)
                        .selectionDisabled()
                }
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
            }
        }
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search this show")
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
                        let chosen = allEpisodes.filter { selection.contains($0.episodeID) }
                        store.undoable("Marked \(chosen.count) played", episodes: chosen) { store.markPlayed(chosen) }
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
        .alert("Mark all \(show.episodes.count) episodes as played?", isPresented: $confirmingMarkAll) {
            Button("Mark all as played") {
                let all = show.episodes
                store.undoable("Marked \(all.count) played", episodes: all) { store.markPlayed(all) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They leave Up Next and stop showing as unplayed. You can undo this with Mark all as unplayed.")
        }
        .alert("Unfollow \(show.title)?", isPresented: $confirmingUnfollow) {
            Button("Cancel", role: .cancel) {}
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

    /// Tap a row to open it (full notes and keys); tap again to close.
    private func episodeButton(_ episode: PodcastEpisode, allEpisodes: [PodcastEpisode]) -> some View {
        let isOpen = expanded == episode.episodeID
        return VStack(alignment: .leading, spacing: 10) {
            EpisodeRow(episode: episode, isPlaying: player.nowPlaying?.episodeID == episode.episodeID, isQueued: store.isQueued(episode))
                .onTapGesture {
                    // No animation: List resizing rows animates jerkily.
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { expanded = isOpen ? nil : episode.episodeID }
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(isOpen ? "Hides the actions" : "Shows play, download, notes and more")
            if isOpen {
                EpisodeActions(episode: episode, showsNotesKey: true)
                    .padding(.bottom, 6)
            }
        }
        .contextMenu {
            EpisodeMenuItems(episode: episode)
            Button("Mark this and older as played", systemImage: "text.badge.checkmark") {
                let older = allEpisodes.filter { $0.published <= episode.published }
                store.undoable("Marked \(older.count) played", episodes: older) { store.markPlayed(older) }
            }
        }
        .swipeActions(edge: .trailing) {
            if episode.played {
                Button("Unplayed") { store.markUnplayed(episode) }.tint(Theme.muted)
            } else {
                Button("Played") {
                    store.undoable("Marked played", episodes: [episode]) { store.markPlayed(episode.episodeID) }
                }.tint(Theme.accentFill)
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
                    HStack(spacing: 6) {
                        Button { confirmingUnfollow = true } label: {
                            HStack(spacing: 5) {
                                LED(on: true, color: Theme.accentFill)
                                Text("FOLLOWING").font(Theme.mono(11, .bold))
                            }
                            .padding(.horizontal, 10)
                            .frame(minHeight: 36)
                        }
                        .buttonStyle(KeyButtonStyle(kind: .dark, radius: 8))
                        .accessibilityLabel("Following. Tap to unfollow")
                        Button { showingSettings = true } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "slider.horizontal.3")
                                Text(modeName).font(Theme.mono(11, .bold))
                            }
                            .padding(.horizontal, 10)
                            .frame(minHeight: 36)
                        }
                        .buttonStyle(KeyButtonStyle(radius: 8))
                        .accessibilityLabel("Show settings. New episodes: \(modeName)")
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 3)
                }
            }
            if !show.summary.isEmpty {
                Text(show.summary)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(4)
            }
        }
        .padding(.top, 8)
    }

    private var modeName: String {
        switch show.autoAdd {
        case .off: return "OFF"
        case .top: return "TOP"
        case .bottom: return "BOTTOM"
        }
    }
}

/// The keys under an opened episode row (and on the episode page).
struct EpisodeActions: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(DownloadManager.self) private var downloads
    @Environment(TranscriptService.self) private var transcripts
    let episode: PodcastEpisode
    /// A NOTES key that opens the episode page (in lists, not on that page).
    var showsNotesKey = false

    var body: some View {
        let queued = store.isQueued(episode)
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                key(episode.position > 30 && !episode.played ? "▶ RESUME" : "▶ PLAY", dark: true) { player.play(episode) }
                key("PLAY NEXT") { store.playNext(episode) }
                key(queued ? "IN UP NEXT" : "PLAY LAST") { store.playLast(episode) }
                    .disabled(queued)
            }
            HStack(spacing: 8) {
                if downloads.progress[episode.episodeID] != nil {
                    key("STOP DL") { store.removeDownload(episode) }
                } else if episode.downloadFile != nil {
                    key("DEL DL") { store.removeDownload(episode) }
                } else {
                    key("↓ DL") { downloads.download(episode) }
                }
                if transcripts.canTranscribeNow(episode) {
                    key("TX") { transcripts.transcribeNow(episode) }
                        .accessibilityLabel("Transcribe now")
                }
                if episode.played {
                    key("UNPLAYED") { store.markUnplayed(episode) }
                } else {
                    key("✓ PLAYED") {
                        store.undoable("Marked played", episodes: [episode]) { store.markPlayed(episode.episodeID) }
                    }
                }
                if showsNotesKey {
                    key("NOTES") { store.notesEpisode = episode }
                }
            }
        }
        .padding(.bottom, 3)
    }

    private func key(_ title: String, dark: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.mono(11, .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 38)
        }
        .buttonStyle(KeyButtonStyle(kind: dark ? .dark : .plain, radius: 8))
    }
}

private struct EpisodeRow: View {
    @Environment(DownloadManager.self) private var downloads
    let episode: PodcastEpisode
    let isPlaying: Bool
    let isQueued: Bool
    var expanded = false

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
                    .font(expanded ? .subheadline : .caption)
                    .foregroundStyle(expanded ? Theme.ink : Theme.muted)
                    .lineLimit(expanded ? nil : 2)
            }
            HStack(spacing: 10) {
                EpisodeLights(episode: episode)
                Text(meta.uppercased())
                    .font(Theme.mono(10))
                    .foregroundStyle(isPlaying ? Theme.accentText : Theme.muted)
            }
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
