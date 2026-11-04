import SwiftUI
import PodcastCore

/// An episode's notes (its description from the feed), with play and the
/// download / transcript lights. Opened from "Episode notes" in episode menus.
struct EpisodeNotesView: View {
    @Environment(\.dismiss) private var dismiss
    let episode: PodcastEpisode

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 14) {
                        ArtworkView(url: episode.artwork, title: episode.podcast?.title ?? episode.title, size: 96, radius: 10)
                        VStack(alignment: .leading, spacing: 6) {
                            Text((episode.podcast?.title ?? "").uppercased())
                                .font(Theme.mono(11))
                                .foregroundStyle(Theme.muted)
                            Text(episode.title)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            EpisodeLights(episode: episode)
                        }
                    }
                    EpisodeActions(episode: episode)
                    EpisodeNotesText(episode: episode)
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("EPISODE NOTES")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
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
                    .tint(Theme.accentText)
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
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
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
