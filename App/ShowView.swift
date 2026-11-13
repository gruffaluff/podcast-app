import SwiftUI
import PodcastCore

/// One show: its details, its Up Next setting and its episodes, newest first.
struct ShowView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(\.dismiss) private var dismiss
    /// Inside the Haar show sheet: open its Settings page instead.
    @Environment(\.openShowSettings) private var openShowSettings
    let show: Podcast
    /// The page's colour, fixed when it opens so nothing changes colour
    /// while it's on screen (Paul, 11 Nov 2026). Unknown = neutral for
    /// this visit; it's measured for next time.
    @State private var pageColour: Color?

    init(show: Podcast) {
        self.show = show
        _pageColour = State(initialValue: ArtworkColors.shared.background(for: show.artworkURL))
    }
    @State private var confirmingUnfollow = false
    @State private var showingSettings = false
    /// Show only unplayed episodes (default), or every episode.
    @State private var showAll = false
    @State private var confirmingAddAll = false
    @State private var confirmingMarkAll = false
    /// Select mode: tick episodes (or Select All), then mark them played/unplayed.
    @State private var selecting = false
    @State private var selection: Set<String> = []
    /// The episode opened up to show its keys (one at a time).
    @State private var expanded: String?
    /// Search within this show's episodes (titles and notes).
    @State private var search = ""

    /// Worked out when the menu item is tapped, not on every redraw.
    @State private var addAllTitle = ""

    private func openSettings() {
        if let openShowSettings { openShowSettings() } else { showingSettings = true }
    }

    private func askAddAll() {
        let count = store.backCatalogue(of: show).count
        addAllTitle = count == 0 ? "Every unplayed episode is already in Up Next" : "Add \(count) episode\(count == 1 ? "" : "s") to Up Next?"
        confirmingAddAll = true
    }

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
                    .listRowBackground(Theme.rowBackground)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .selectionDisabled()
                // Search this show.
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                    TextField("Search this show", text: $search)
                        .textInputAutocapitalization(.never)
                        .foregroundStyle(Theme.ink)
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted) }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 40)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                .listRowBackground(Theme.rowBackground)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 4, trailing: 16))
                .selectionDisabled()
                DeckSwitch(options: [(label: "Unplayed \(unplayedCount)", value: false), (label: "All \(allEpisodes.count)", value: true)], selection: $showAll)
                    .listRowBackground(Theme.rowBackground)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 6, trailing: 16))
                    .selectionDisabled()
                if episodes.isEmpty {
                    Text(!term.isEmpty ? "No episodes match “\(term)”." : showAll ? "No episodes yet." : "You're all caught up. Switch to All to see played episodes.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .listRowBackground(Theme.rowBackground)
                        .listRowSeparator(.hidden)
                        .selectionDisabled()
                }
                ForEach(Array(episodes.enumerated()), id: \.element.episodeID) { index, episode in
                    Group {
                        if selecting {
                            row(episode)
                        } else {
                            episodeButton(episode, allEpisodes: allEpisodes)
                        }
                    }
                    .tag(episode.episodeID)
                    .modifier(ShowEpisodeCard(url: show.artworkURL, title: show.title,
                                              playing: player.nowPlaying?.episodeID == episode.episodeID))
                    .posterSwipe(leading: leadingSwipe(episode), trailing: trailingSwipe(episode), enabled: !selecting)
                }
            }
        }
        .environment(\.editMode, .constant(selecting ? .active : .inactive))
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .haarPage()
        .environment(\.showColour, pageColour)
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
                        Button("Show settings", systemImage: "slider.horizontal.3") { openSettings() }
                        Button("Select episodes", systemImage: "checkmark.circle") { selecting = true }
                        // The whole back catalogue, oldest first (Paul, 9 Nov 2026).
                        Button("Add all to Up Next, oldest first", systemImage: "text.append") { askAddAll() }
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
        .alert(addAllTitle, isPresented: $confirmingAddAll) {
            Button("Add to Up Next") { store.addBackCatalogue(of: show) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They go at the end of Up Next, oldest first, so you can listen from the very first episode. Nothing extra downloads: each one streams or downloads as usual when it comes up.")
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
    }

    /// Full-row swipes (poster look): right to play next, left played (or
    /// unplayed). Put on outside the row's card, so the whole card slides
    /// over the action (inside it, only the words moved and slid over the
    /// coloured block; Paul's recording, 13 Nov 2026).
    private func leadingSwipe(_ episode: PodcastEpisode) -> PosterSwipeAction {
        PosterSwipeAction(title: "Play next", icon: "text.line.first.and.arrowtriangle.forward", colour: Poster.swipeAdd) { store.playNext(episode) }
    }

    private func trailingSwipe(_ episode: PodcastEpisode) -> PosterSwipeAction {
        if episode.played {
            return PosterSwipeAction(title: "Unplayed", icon: "circle", colour: Theme.muted) { store.markUnplayed(episode) }
        }
        return PosterSwipeAction(title: "Played", icon: "checkmark", colour: Poster.swipePlayed) {
            store.undoable("Marked played", episodes: [episode]) { store.markPlayed(episode.episodeID) }
        }
    }

    /// The show's header, plain on the warm page (Paul, 12 Nov 2026: the
    /// printed block left a gap above it when the list was pulled down):
    /// artwork and name, publisher · episodes · auto download, then
    /// Following, settings (where new episodes go) and the alerts bell, and
    /// the description. Keys that are on take the show's colour.
    private var header: some View {
        let accent: Color = Theme.showAccentFill(pageColour)
        let onAccent: Color = Theme.showOnAccent(pageColour)
        let details: String = [show.author, "\(show.episodes.count) episodes", show.autoDownload ? "auto download" : nil]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: " · ")
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                ArtworkView(url: show.artworkURL, title: show.title, size: 96, radius: 12)
                VStack(alignment: .leading, spacing: 5) {
                    Text(show.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                        .accessibilityAddTraits(.isHeader)
                    Text(details)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(2)
                }
            }
            HStack(spacing: 8) {
                Button { confirmingUnfollow = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy))
                        Text("Following").font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(onAccent)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(accent, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Following. Tap to unfollow")
                Button { openSettings() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "slider.horizontal.3")
                        Text(modeName).font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Theme.plate, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show settings. New episodes: \(modeName)")
                Button { toggleAlerts() } label: {
                    Image(systemName: show.notify ? "bell.fill" : "bell.slash")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(show.notify ? onAccent : Theme.ink)
                        .frame(width: 44, height: 44)
                        .background(show.notify ? accent : Theme.plate, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(show.notify ? "New episode alerts on" : "New episode alerts off")
                .accessibilityHint("Turns alerts for this show on or off")
            }
            if !show.summary.isEmpty {
                Text(show.summary)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: show.artworkURL) { await ArtworkColors.shared.load(show.artworkURL) }
    }

    /// The bell: alerts when this show has a new episode.
    private func toggleAlerts() {
        show.notify.toggle()
        store.save()
        if show.notify { Task { await NewEpisodeAlerts.requestPermission() } }
        Task { await RealtimeAlerts.publishFollows(store: store) }
    }

    private var modeName: String {
        switch show.autoAdd {
        case .off: return "Off"
        case .top: return "Top"
        case .bottom: return "Bottom"
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
    @Environment(\.showColour) private var showColour
    /// A NOTES key that opens the episode page (in lists, not on that page).
    var showsNotesKey = false
    /// Set when the keys sit on the show's printed colour (the episode
    /// page): the play key is then paper with the colour as its text.
    var onShowColour = false

    var body: some View {
        let queued = store.isQueued(episode)
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                playKey
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
                if transcripts.isQueued(episode) {
                    key(transcripts.progress[episode.episodeID].map { "STOP TX · \(Int($0 * 100))%" } ?? "STOP TX") { transcripts.stop(episode) }
                        .accessibilityLabel("Stop transcribing")
                } else if transcripts.canTranscribeNow(episode) {
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

    /// The play key in the show's own colour (Paul, 11 Nov 2026: the main
    /// "do it" key follows the artwork; the other keys stay neutral).
    private var playKey: some View {
        let colour = showColour ?? Theme.ink
        return Button { player.play(episode) } label: {
            Text(episode.position > 30 && !episode.played ? "▶ RESUME" : "▶ PLAY")
                .font(Theme.mono(11, .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 38)
        }
        .buttonStyle(ColourKeyStyle(fill: onShowColour ? Poster.paper : colour,
                                    text: onShowColour ? colour : Poster.paper))
    }

    private func key(_ title: String, dark: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.mono(11, .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 38)
        }
        // Sand keys, so they show on the paper rows (Paul, build 139: paper
        // keys on a paper card were lost).
        .buttonStyle(KeyButtonStyle(kind: dark ? .dark : .sand, radius: 8))
    }
}

/// A key in a given colour (the play key in the show's colour).
private struct ColourKeyStyle: ButtonStyle {
    let fill: Color
    let text: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(text)
            .background(RoundedRectangle(cornerRadius: 8).fill(fill))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
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
            // A poster row: when, how long and its state on the label line
            // ("● NEW" unplayed, "✓ PLAYED" faded), then the title big.
            PosterRowText(label: label, title: episode.title, titleSize: 18, lines: 2, dim: episode.played && !isPlaying, onColour: isPlaying)
            // Every line is always there (blank when there's nothing to
            // show), so all the rows are one size (Paul, 13 Nov 2026).
            Text(episode.summary.isEmpty ? " " : episode.summary)
                .font(expanded ? .subheadline : .caption)
                .foregroundStyle(isPlaying ? Poster.paper.opacity(0.8) : (expanded ? Theme.ink : Theme.muted))
                .lineLimit(expanded ? nil : 1)
            EpisodeLights(episode: episode, onDark: isPlaying)
                .opacity(!episode.played || isPlaying ? 1 : 0)
                .accessibilityHidden(episode.played && !isPlaying)
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var label: String {
        let date = episode.published.formatted(date: .abbreviated, time: .omitted)
        let state = isPlaying ? "▶ Playing" : (episode.played ? "✓ Played" : "● New")
        return ([date, state] + [meta].filter { !$0.isEmpty }).joined(separator: " · ")
    }

    private var meta: String {
        var parts: [String] = []
        if !episode.played, let left = episode.timeLeft, left > 0 {
            parts.append(episode.position > 30 ? "\(TimeFormat.length(left)) left" : TimeFormat.length(left))
        }
        if isQueued { parts.append("In Up Next") }
        if !episode.played, let download = downloads.status(for: episode) { parts.append(download) }
        return parts.joined(separator: " · ")
    }
}

/// Behind a show's header (show page and Discover preview): the artwork
/// filling the card from the top, fading into its colour so the white text
/// below stays readable.
struct ShowHeroBackground: View {
    let url: URL?
    let tint: Color

    var body: some View {
        // Printed in the show's colour (poster look, Paul 11 Nov 2026).
        ZStack(alignment: .top) {
            tint
            GeometryReader { geometry in
                PrintedArtwork(url: url, colour: tint, strength: 0.7, dots: false)
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .mask(LinearGradient(stops: [.init(color: .black, location: 0),
                                                 .init(color: .black, location: 0.5),
                                                 .init(color: .black.opacity(0), location: 1)],
                                         startPoint: .top, endPoint: .bottom))
            }
            Halftone()
        }
        .accessibilityHidden(true)
    }
}

/// A show page row: a box with the show's colour band, or the dark playing
/// card for the episode that's on (Deck 0: the same everywhere).
private struct ShowEpisodeCard: ViewModifier {
    let url: URL?
    let title: String
    let playing: Bool

    func body(content: Content) -> some View {
        if playing {
            content.playingCard().deckCardRow()
        } else {
            content.showRow(url, title: title)
        }
    }
}
