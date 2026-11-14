import SwiftUI
import PodcastCore

// Deck (Paul, 14 Nov 2026): the episodes on a show page (prototype
// renderShowPage). A search box, Unplayed / All, Mark all played, then one
// card per episode: a dot in the show's colour (unplayed) or a tick
// (played), "5h ago · 42m · 3rd in Up next", the title and DL / TX. Tap a
// card for its keys; swipe left Played, right a little Play next, right
// far Play last. The episode playing is the ink card.

struct DeckShowEpisodeList: View {
    let show: Podcast
    let colour: Color
    let markAll: () -> Void
    @State private var showAll = false
    @State private var query = ""
    /// The episode opened up to show its keys (one at a time).
    @State private var expanded: String?

    var body: some View {
        let episodes: [PodcastEpisode] = visible()
        VStack(alignment: .leading, spacing: 8) {
            DeckShowSearchBox(query: $query, count: show.episodes.count)
            filterRow
                .padding(.top, 6)
            if episodes.isEmpty {
                empty
            }
            LazyVStack(spacing: 8) {
                ForEach(episodes, id: \.episodeID) { episode in
                    DeckShowEpisodeCard(episode: episode, colour: colour, expanded: $expanded)
                }
            }
        }
    }

    /// Newest first; unplayed only unless All is on or something's typed
    /// (every word typed, in the title or notes).
    private func visible() -> [PodcastEpisode] {
        let all: [PodcastEpisode] = show.episodes.sorted { $0.published > $1.published }
        let words: [String] = query.lowercased().split(separator: " ").map(String.init)
        if !words.isEmpty {
            return all.filter { episode in
                let text: String = (episode.title + " " + episode.summary).lowercased()
                return words.allSatisfy { text.contains($0) }
            }
        }
        return showAll ? all : all.filter { !$0.played }
    }

    private var filterRow: some View {
        HStack(spacing: 6) {
            DeckShowLabel(text: "Episodes")
            Spacer(minLength: 8)
            filter("Unplayed", on: !showAll) { showAll = false }
            filter("All", on: showAll) { showAll = true }
            Button(action: markAll) {
                Text("Mark all played")
                    .font(Theme.outfit(13, .semibold))
                    .foregroundStyle(Theme.muted)
                    .frame(minHeight: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
        .padding(.horizontal, 6)
    }

    private func filter(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(LibraryStore.listChange) { action() }
        } label: {
            DeckShowPill(title: title, on: on, height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }

    private var empty: some View {
        let text: String = query.isEmpty
            ? (show.episodes.isEmpty ? "No episodes yet." : "You're all caught up. All has the rest.")
            : "Nothing matches “\(query)”."
        return Text(text)
            .font(Theme.outfit(14, .medium))
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
    }
}

/// Search this show's episodes (titles and notes).
private struct DeckShowSearchBox: View {
    @Binding var query: String
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.muted)
            TextField("Search \(count) episodes", text: $query)
                .font(Theme.outfit(15, .medium))
                .foregroundStyle(Theme.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.cardEdge, lineWidth: 1))
    }
}

/// One episode card, with its keys when opened.
struct DeckShowEpisodeCard: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    let episode: PodcastEpisode
    let colour: Color
    @Binding var expanded: String?

    var body: some View {
        let playing: Bool = player.nowPlaying?.episodeID == episode.episodeID
        let open: Bool = expanded == episode.episodeID
        VStack(alignment: .leading, spacing: 0) {
            Button { toggle(open) } label: { DeckShowEpisodeText(episode: episode, colour: colour, playing: playing) }
                .buttonStyle(.plain)
                .accessibilityHint(open ? "Hides the keys" : "Shows play, download and more")
            if open {
                DeckShowEpisodeKeys(episode: episode, colour: colour, playing: playing)
                    .padding(.top, 12)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(cardShape(playing))
        .contextMenu { EpisodeMenuItems(episode: episode) }
        .deckShowSwipe(leading: playNext, leadingFar: playLast, trailing: played)
    }

    private func toggle(_ open: Bool) {
        withAnimation(.snappy(duration: 0.25)) { expanded = open ? nil : episode.episodeID }
    }

    private func cardShape(_ playing: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return shape.fill(playing ? Theme.playingCard : Theme.surface)
            .overlay(shape.strokeBorder(playing ? Theme.playingCard : Theme.cardEdge, lineWidth: 1))
    }

    private var playNext: PosterSwipeAction {
        PosterSwipeAction(title: "Play next", icon: "text.line.first.and.arrowtriangle.forward", colour: colour) {
            store.playNext(episode)
        }
    }

    private var playLast: PosterSwipeAction {
        PosterSwipeAction(title: "Play last", icon: "text.line.last.and.arrowtriangle.forward", colour: DeckShowColour.dark(colour)) {
            store.playLast(episode)
        }
    }

    private var played: PosterSwipeAction {
        if episode.played {
            return PosterSwipeAction(title: "Unplayed", icon: "circle", colour: Theme.muted) { store.markUnplayed(episode) }
        }
        return PosterSwipeAction(title: "Played", icon: "checkmark", colour: Theme.ink) {
            store.undoable("Marked played", episodes: [episode]) { store.markPlayed(episode.episodeID) }
        }
    }
}

/// The card's words: dot or tick, the meta line, title, DL / TX.
private struct DeckShowEpisodeText: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    let episode: PodcastEpisode
    let colour: Color
    let playing: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            mark
                .frame(width: 10)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) {
                Text(meta)
                    .font(Theme.outfit(12, .medium))
                    .monospacedDigit()
                    .foregroundStyle(playing ? Color.white.opacity(0.7) : Theme.muted)
                    .lineLimit(1)
                Text(episode.title)
                    .font(Theme.outfit(16, episode.played ? .medium : .bold))
                    .foregroundStyle(titleColour)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                EpisodeLights(episode: episode, onDark: playing)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
    }

    private var titleColour: Color {
        if playing { return Color.white }
        return episode.played ? Theme.ink.opacity(0.55) : Theme.ink
    }

    @ViewBuilder private var mark: some View {
        if episode.played {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.faint)
                .accessibilityLabel("Played")
        } else {
            Circle()
                .fill(playing ? Color.white : colour)
                .frame(width: 8, height: 8)
                .accessibilityLabel("Unplayed")
        }
    }

    /// "5h ago · 42m · 3rd in Up next", "· Playing", or "· 12m left".
    private var meta: String {
        var parts: [String] = [TimeFormat.ago(episode.published)]
        if let duration = episode.duration, duration > 0 { parts.append(TimeFormat.length(duration)) }
        if playing {
            parts.append(player.isPlaying ? "Playing" : "Paused")
        } else if let index = store.queue.firstIndex(where: { $0.episode.id == episode.episodeID }) {
            parts.append("\(EpisodeStatusRows.ordinal(index + 1)) in Up next")
        } else if !episode.played, episode.position > 30, let left = episode.timeLeft, left > 0 {
            parts.append(TimeFormat.length(left) + " left")
        }
        return parts.joined(separator: " · ")
    }
}

/// The opened card's keys: Play (the show's colour) / Play next / Play
/// last, Download / Transcribe / Played, then Notes and details.
private struct DeckShowEpisodeKeys: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(DownloadManager.self) private var downloads
    @Environment(TranscriptService.self) private var transcripts
    let episode: PodcastEpisode
    let colour: Color
    let playing: Bool
    @State private var showingTranscript = false

    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        VStack(spacing: 6) {
            LazyVGrid(columns: columns, spacing: 6) {
                playKey
                key("text.line.first.and.arrowtriangle.forward", "Play next") { store.playNext(episode) }
                key("text.line.last.and.arrowtriangle.forward", "Play last") { store.playLast(episode) }
                downloadKey
                transcriptKey
                playedKey
            }
            notesButton
        }
        .sheet(isPresented: $showingTranscript) { TranscriptView(episode: episode) }
    }

    private var playKey: some View {
        let on: Bool = playing && player.isPlaying
        let title: String = on ? "Pause" : (episode.position > 30 && !episode.played ? "Resume" : "Play")
        return key(on ? "pause.fill" : "play.fill", title, fill: colour) {
            if playing { player.togglePlayPause() } else { player.play(episode) }
        }
    }

    @ViewBuilder private var downloadKey: some View {
        if downloads.progress[episode.episodeID] != nil {
            key("stop.circle", "Stop DL") { store.removeDownload(episode) }
        } else if episode.downloadFile != nil {
            key("trash", "Remove DL") { store.removeDownload(episode) }
        } else {
            key("arrow.down.circle", "Download") { downloads.download(episode) }
        }
    }

    @ViewBuilder private var transcriptKey: some View {
        if episode.transcriptState == .ready {
            key("text.quote", "Transcript") { showingTranscript = true }
        } else if transcripts.isQueued(episode) {
            key("stop.circle", "Stop TX") { transcripts.stop(episode) }
        } else {
            key("text.quote", "Transcribe") { transcripts.transcribeNow(episode) }
                .disabled(!transcripts.canTranscribeNow(episode))
        }
    }

    @ViewBuilder private var playedKey: some View {
        if episode.played {
            key("circle", "Unplayed") { store.markUnplayed(episode) }
        } else {
            key("checkmark", "Played") {
                store.undoable("Marked played", episodes: [episode]) { store.markPlayed(episode.episodeID) }
            }
        }
    }

    private var notesButton: some View {
        Button { store.notesEpisode = episode } label: {
            Text("Notes and details")
                .font(Theme.outfit(13, .semibold))
                .foregroundStyle(playing ? Color.white : Theme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(keyFill))
        }
        .buttonStyle(.plain)
    }

    private var keyFill: Color {
        playing ? Color.white.opacity(0.12) : Theme.background
    }

    private func key(_ icon: String, _ title: String, fill: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(Theme.outfit(11, .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(fill != nil || playing ? Color.white : Theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill ?? keyFill))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
