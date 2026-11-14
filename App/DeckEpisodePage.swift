import SwiftUI
import PodcastCore

// Deck (Paul, 14 Nov 2026): an episode's page (prototype renderEpisode),
// shown by EpisodeNotesView when the Deck look is on. A white card with
// the show (artwork, "Show ›", when · length), the title, DL / TX, a wide
// Play / Resume · 34m left key in the show's colour with Play next and
// Played beside it; then a card of status rows (place in Up next,
// download, transcript); then the notes.

struct DeckEpisodePage: View {
    let episode: PodcastEpisode
    /// The show's colour, fixed by EpisodeNotesView when the page opened.
    let colour: Color?
    let openShow: () -> Void

    private var tint: Color {
        colour ?? Theme.placeholderColor(for: episode.showTitle.isEmpty ? episode.title : episode.showTitle)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            top
            DeckEpisodeStatusCard(episode: episode)
            EpisodeNotesText(episode: episode)
                .padding(.top, 8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 24)
        .task(id: episode.showArtwork) { await ArtworkColors.shared.load(episode.showArtwork) }
    }

    private var top: some View {
        VStack(alignment: .leading, spacing: 0) {
            showButton
            Text(episode.title)
                .font(Theme.outfit(24, .heavy))
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
                .padding(.bottom, 6)
                .accessibilityAddTraits(.isHeader)
            EpisodeLights(episode: episode)
            DeckEpisodeKeys(episode: episode, tint: tint)
                .padding(.top, 16)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .deckPlainCard(radius: 28)
    }

    private var showButton: some View {
        Button(action: openShow) {
            HStack(spacing: 10) {
                ArtworkView(url: episode.artwork, title: episode.showTitle.isEmpty ? episode.title : episode.showTitle,
                            size: 56, radius: 14)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 3) {
                        Text(episode.showTitle)
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .font(Theme.outfit(14, .bold))
                    .foregroundStyle(showText)
                    Text(details)
                        .font(Theme.outfit(12, .medium))
                        .foregroundStyle(Theme.muted)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(episode.showTitle)")
    }

    /// The show's colour as text; Deck night keeps ink (dark show colours
    /// vanish on the dark page).
    private var showText: Color {
        ColourScheme.current.isDark ? Theme.ink : DeckShowColour.dark(tint)
    }

    private var details: String {
        var parts: [String] = [TimeFormat.ago(episode.published)]
        if let duration = episode.duration, duration > 0 { parts.append(TimeFormat.length(duration)) }
        return parts.joined(separator: " · ")
    }
}

/// Play / Resume · 34m left (Pause while it's on) in the show's colour,
/// then Play next and Played.
private struct DeckEpisodeKeys: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    let episode: PodcastEpisode
    let tint: Color

    private var isThis: Bool { player.nowPlaying?.episodeID == episode.episodeID }

    var body: some View {
        HStack(spacing: 8) {
            playButton
            square("plus", label: "Play next", on: false) { store.playNext(episode) }
            square("checkmark", label: episode.played ? "Mark unplayed" : "Mark played", on: episode.played) { togglePlayed() }
        }
    }

    private var playTitle: String {
        if isThis && player.isPlaying { return "Pause" }
        if episode.position > 30 && !episode.played, let left = episode.timeLeft, left > 0 {
            return "Resume · \(TimeFormat.length(left)) left"
        }
        return "Play"
    }

    private var playButton: some View {
        let on: Bool = isThis && player.isPlaying
        return Button {
            if isThis { player.togglePlayPause() } else { player.play(episode) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: on ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .bold))
                Text(playTitle)
                    .font(Theme.outfit(16, .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(tint))
        }
        .buttonStyle(.plain)
    }

    private func togglePlayed() {
        if episode.played {
            store.markUnplayed(episode)
        } else {
            store.undoable("Marked played", episodes: [episode]) { store.markPlayed(episode.episodeID) }
        }
    }

    private func square(_ icon: String, label: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(on ? Theme.background : Theme.ink)
                .frame(width: 50, height: 50)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(on ? Theme.ink : Theme.background))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Place in Up next (tap to go there, or Add), the download (progress,
/// stop, remove) and the transcript (Transcribe now, progress, Read), as
/// rows in one white card.
private struct DeckEpisodeStatusCard: View {
    @Environment(LibraryStore.self) private var store
    @Environment(DownloadManager.self) private var downloads
    @Environment(TranscriptService.self) private var transcripts
    @Environment(\.dismiss) private var dismiss
    let episode: PodcastEpisode
    @State private var showingTranscript = false
    @State private var confirmRemove = false

    var body: some View {
        VStack(spacing: 0) {
            upNextRow
            Rectangle().fill(Theme.cardLine).frame(height: 1)
            downloadRow
            Rectangle().fill(Theme.cardLine).frame(height: 1)
            transcriptRow
        }
        .deckPlainCard(radius: 22)
        .sheet(isPresented: $showingTranscript) { TranscriptView(episode: episode) }
        .alert("Remove the download?", isPresented: $confirmRemove) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) { store.removeDownload(episode) }
        } message: {
            Text("It will stream instead, or you can download it again.")
        }
    }

    private var upNextRow: some View {
        let index: Int? = store.queue.firstIndex { $0.episode.id == episode.episodeID }
        let title: String = index.map { $0 == 0 ? "Top of Up next" : "\(EpisodeStatusRows.ordinal($0 + 1)) in Up next" } ?? "Not in Up next"
        return DeckEpisodeStatusRow(icon: "rectangle.stack", title: title, action: index == nil ? "Add" : "Show",
                                    chevron: index != nil) {
            if index == nil {
                withAnimation(LibraryStore.listChange) { store.playLast(episode) }
            } else {
                store.revealInUpNext = episode.episodeID
                dismiss()
            }
        }
    }

    @ViewBuilder private var downloadRow: some View {
        if let fraction = downloads.progress[episode.episodeID] {
            DeckEpisodeStatusRow(icon: "arrow.down.circle", title: "Downloading · \(Int(fraction * 100))%", action: "Stop") {
                store.removeDownload(episode)
            }
        } else if episode.downloadFile != nil {
            DeckEpisodeStatusRow(icon: "checkmark.circle", title: "Downloaded", action: "Remove") { confirmRemove = true }
        } else {
            DeckEpisodeStatusRow(icon: "arrow.down.circle", title: "Not downloaded", action: "Download") {
                downloads.download(episode)
            }
        }
    }

    @ViewBuilder private var transcriptRow: some View {
        let id: String = episode.episodeID
        if episode.transcriptState == .ready {
            DeckEpisodeStatusRow(icon: "text.quote", title: "Transcript ready", action: "Read") { showingTranscript = true }
        } else if transcripts.isQueued(episode) {
            DeckEpisodeStatusRow(icon: "waveform", title: transcriptProgress(id), action: "Stop") { transcripts.stop(episode) }
        } else {
            DeckEpisodeStatusRow(icon: "text.quote", title: "No transcript yet", action: "Transcribe now") {
                transcripts.transcribeNow(episode)
            }
        }
    }

    private func transcriptProgress(_ id: String) -> String {
        if episode.transcriptState == .transcribing {
            return "Transcribing on this iPhone · \(Int((transcripts.progress[id] ?? 0) * 100))%"
        }
        if let fraction = downloads.progress[id] {
            return "Downloading first · \(Int(fraction * 100))%"
        }
        return "Waiting to transcribe"
    }
}

/// One status row: icon, what's true now, and what tapping does.
private struct DeckEpisodeStatusRow: View {
    let icon: String
    let title: String
    let action: String
    var chevron = false
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 24)
                Text(title)
                    .font(Theme.outfit(15, .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                trailing
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(action)
    }

    private var trailing: some View {
        HStack(spacing: 3) {
            Text(action)
            if chevron {
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
            }
        }
        .font(Theme.outfit(14, .semibold))
        .foregroundStyle(Theme.muted)
    }
}
