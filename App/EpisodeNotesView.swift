import SwiftUI
import PodcastCore

/// An episode's notes (its description from the feed), with play and the
/// download / transcript lights. Opened from "Episode notes" in episode menus.
struct EpisodeNotesView: View {
    @Environment(PlayerModel.self) private var player
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
                    Button {
                        player.play(episode)
                        dismiss()
                    } label: {
                        Text("▶ PLAY" + (episode.timeLeft.map { " · \(TimeFormat.clock($0))" } ?? ""))
                            .font(Theme.mono(13, .bold))
                            .frame(maxWidth: .infinity, minHeight: 46)
                    }
                    .buttonStyle(.darkKey)
                    .padding(.bottom, 3)
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

/// The notes panel itself, shared with the player.
struct EpisodeNotesText: View {
    let episode: PodcastEpisode

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DeckHeader(title: "Episode notes", detail: detail)
            Text(episode.summary.isEmpty ? "This episode has no notes." : episode.summary)
                .font(.subheadline)
                .foregroundStyle(episode.summary.isEmpty ? Theme.muted : Theme.ink)
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private var detail: String {
        var parts = [episode.published.formatted(date: .abbreviated, time: .omitted)]
        if let duration = episode.duration, duration > 0 { parts.append(TimeFormat.clock(duration)) }
        return parts.joined(separator: " · ")
    }
}
