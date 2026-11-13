import SwiftUI
import PodcastCore

/// An episode's notes (its description from the feed), with play and the
/// download / transcript lights. Opened from "Episode notes" in episode menus.
struct EpisodeNotesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LibraryStore.self) private var store
    let episode: PodcastEpisode
    /// The page's colour, fixed when it opens so nothing changes colour
    /// while it's on screen (Paul, 11 Nov 2026). Unknown = neutral for
    /// this visit; it's measured for next time.
    @State private var pageColour: Color?

    init(episode: PodcastEpisode) {
        self.episode = episode
        _pageColour = State(initialValue: ArtworkColors.shared.background(for: episode.showArtwork))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    poster
                    VStack(alignment: .leading, spacing: 14) {
                        EpisodeStatusRows(episode: episode)
                        EpisodeNotesText(episode: episode)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 16)
            }
            .haarPage()
            .environment(\.showColour, pageColour)
            .navigationTitle("Episode notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .transcribeExplainer()
    }

    /// The top of the page on the warm page (Paul, 12 Nov 2026: the printed
    /// block with a huge title and six keys looked off and repeated the
    /// status rows below): artwork, "Show ›" and date · length, the title
    /// as the feed writes it, DL / TX, then one Play / Resume key in the
    /// episode's colour with small Play next and Played keys. Download,
    /// transcript and the place in Up Next are only the rows below.
    private var poster: some View {
        let art = episode.showArtwork
        let details = [episode.published.formatted(date: .abbreviated, time: .omitted),
                       episode.duration.map { TimeFormat.length($0) }].compactMap { $0 }.joined(separator: " · ")
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button(action: openShow) {
                    ArtworkView(url: episode.artwork, title: episode.showTitle.isEmpty ? episode.title : episode.showTitle, size: 64, radius: 10)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(episode.podcast?.title ?? "the show")")
                VStack(alignment: .leading, spacing: 3) {
                    Button(action: openShow) {
                        HStack(spacing: 4) {
                            Text(episode.showTitle)
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.showAccentText(pageColour))
                        .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    Text(details)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                }
            }
            Text(episode.title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            EpisodeLights(episode: episode)
            EpisodePageKeys(episode: episode, colour: pageColour)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: art) { await ArtworkColors.shared.load(art) }
    }

    private func openShow() {
        guard let show = episode.podcast else { return }
        store.revealShow = show
        dismiss()
    }
}

/// The episode page's keys: one wide Play / Resume (Pause while it's on)
/// in the episode's colour, and small Play next and Played beside it.
private struct EpisodePageKeys: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    let episode: PodcastEpisode
    let colour: Color?

    private var isThis: Bool { player.nowPlaying?.episodeID == episode.episodeID }

    private var playTitle: String {
        if isThis && player.isPlaying { return "Pause" }
        return episode.position > 30 && !episode.played ? "Resume" : "Play"
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                if isThis { player.togglePlayPause() } else { player.play(episode) }
            } label: {
                Label(playTitle, systemImage: isThis && player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.showOnAccent(colour))
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(Theme.showAccentFill(colour), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            smallKey("text.line.first.and.arrowtriangle.forward", label: "Play next") { store.playNext(episode) }
            if episode.played {
                smallKey("arrow.uturn.backward", label: "Mark unplayed") { store.markUnplayed(episode) }
            } else {
                smallKey("checkmark", label: "Mark played") {
                    store.undoable("Marked played", episodes: [episode]) { store.markPlayed(episode.episodeID) }
                }
            }
        }
    }

    private func smallKey(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 52, height: 46)
                .background(Theme.plate, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// The notes panel itself, shared with the player: paragraphs as the show
/// wrote them, web links tappable, and timestamps ("12:34") that play the
/// episode from that moment.
struct EpisodeNotesText: View {
    @Environment(PlayerModel.self) private var player
    @Environment(\.showColour) private var showColour
    let episode: PodcastEpisode

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DeckHeader(title: "Episode notes", detail: detail)
            if episode.summary.isEmpty {
                Text("This episode has no notes.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            } else {
                Text(Self.linked(episode.summary))
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .tint(Theme.showAccentText(showColour))
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.openURL, OpenURLAction { url in
                        guard url.scheme == "poddeck-seek", let seconds = TimeInterval(url.host() ?? "") else { return .systemAction }
                        if player.nowPlaying?.episodeID != episode.episodeID { player.play(episode) }
                        player.seek(to: seconds)
                        return .handled
                    })
            }
        }
        .padding(14)
        .deckCard()
    }

    private var detail: String {
        var parts = [episode.published.formatted(date: .abbreviated, time: .omitted)]
        if let duration = episode.duration, duration > 0 { parts.append(TimeFormat.clock(duration)) }
        return parts.joined(separator: " · ")
    }

    /// Links for web addresses and timestamps.
    static func linked(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        let whole = NSRange(text.startIndex..., in: text)
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            for match in detector.matches(in: text, range: whole) {
                guard let url = match.url, let range = Range(match.range, in: text),
                      let attributed = Range(range, in: result) else { continue }
                result[attributed].link = url
                result[attributed].underlineStyle = .single
            }
        }
        if let stamps = try? NSRegularExpression(pattern: "\\b(?:(\\d{1,2}):)?([0-5]?\\d):([0-5]\\d)\\b") {
            for match in stamps.matches(in: text, range: whole) {
                func number(_ i: Int) -> Int {
                    Range(match.range(at: i), in: text).flatMap { Int(text[$0]) } ?? 0
                }
                let seconds = number(1) * 3600 + number(2) * 60 + number(3)
                guard let range = Range(match.range, in: text), let attributed = Range(range, in: result),
                      result[attributed].link == nil,
                      let url = URL(string: "poddeck-seek://\(seconds)") else { continue }
                result[attributed].link = url
                result[attributed].font = Theme.mono(14, .semibold)
            }
        }
        return result
    }
}
