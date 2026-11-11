import SwiftUI
import PodcastCore

/// An episode's notes (its description from the feed), with play and the
/// download / transcript lights. Opened from "Episode notes" in episode menus.
struct EpisodeNotesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LibraryStore.self) private var store
    let episode: PodcastEpisode

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
            .background(Theme.background)
            .environment(\.showColour, ArtworkColors.shared.background(for: episode.showArtwork))
            .navigationTitle("Episode notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .transcribeExplainer()
    }

    /// The episode's own poster (Paul's pick, 11 Nov 2026): printed in the
    /// show's colour, the artwork stamp and show (both open the show), the
    /// title in big capitals, then its keys.
    private var poster: some View {
        let art = episode.showArtwork
        let tint = ArtworkColors.shared.background(for: art) ?? Theme.placeholderColor(for: episode.showTitle)
        let details = [episode.published.formatted(date: .abbreviated, time: .omitted),
                       episode.duration.map { TimeFormat.length($0) }].compactMap { $0 }.joined(separator: " · ")
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button(action: openShow) {
                    Stamp(url: episode.artwork, title: episode.showTitle.isEmpty ? episode.title : episode.showTitle, size: 52)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(episode.podcast?.title ?? "the show")")
                VStack(alignment: .leading, spacing: 3) {
                    Button(action: openShow) {
                        HStack(spacing: 4) {
                            Text(episode.showTitle.uppercased())
                            Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                        }
                        .font(Theme.mono(10, .bold))
                        .tracking(0.8)
                        .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    Text(details.uppercased())
                        .font(Theme.mono(10))
                        .tracking(0.8)
                        .foregroundStyle(Poster.paper.opacity(0.8))
                }
            }
            Text(episode.title)
                .font(Theme.big(38))
                .lineLimit(5)
                .minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
            EpisodeLights(episode: episode, onDark: true)
            EpisodeActions(episode: episode, onShowColour: true)
        }
        .foregroundStyle(Poster.paper)
        .padding(18)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { PrintedArtwork(url: episode.artwork, colour: tint, strength: 0.45) }
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 30, bottomTrailingRadius: 30))
        .task(id: art) { await ArtworkColors.shared.load(art) }
    }

    private func openShow() {
        guard let show = episode.podcast else { return }
        store.revealShow = show
        dismiss()
    }
}

/// The notes panel itself, shared with the player: paragraphs as the show
/// wrote them, web links tappable, and timestamps ("12:34") that play the
/// episode from that moment.
struct EpisodeNotesText: View {
    @Environment(PlayerModel.self) private var player
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
                    .tint(Theme.showAccentText(ArtworkColors.shared.background(for: episode.showArtwork)))
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
