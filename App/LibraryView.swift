import SwiftUI
import SwiftData
import PodcastCore

struct LibraryView: View {
    @Environment(LibraryStore.self) private var store
    @Query(sort: \Podcast.title) private var shows: [Podcast]
    @Query(LibraryView.newEpisodesQuery) private var newEpisodes: [PodcastEpisode]
    @State private var addingShow = false

    private static var newEpisodesQuery: FetchDescriptor<PodcastEpisode> {
        var descriptor = FetchDescriptor<PodcastEpisode>(
            predicate: #Predicate { $0.played == false },
            sortBy: [SortDescriptor(\.published, order: .reverse)]
        )
        descriptor.fetchLimit = 12
        return descriptor
    }

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if shows.isEmpty {
                        emptyState
                    } else {
                        if !newEpisodes.isEmpty {
                            sectionTitle("NEW EPISODES", detail: "\(newEpisodes.count) UNPLAYED")
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 14) {
                                    ForEach(newEpisodes) { episode in
                                        EpisodeCard(episode: episode)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        sectionTitle("YOUR SHOWS", detail: "\(shows.count) FOLLOWED")
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                            ForEach(shows) { show in
                                NavigationLink(value: show) {
                                    ShowTile(show: show)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 12)
            }
            .background(Theme.background)
            .refreshable { await store.refreshAll() }
            .navigationTitle("LIBRARY")
            .navigationDestination(for: Podcast.self) { ShowView(show: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { addingShow = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add a show")
                }
            }
            .sheet(isPresented: $addingShow) { AddShowView() }
        }
    }

    private func sectionTitle(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Theme.mono(15, .bold))
                .foregroundStyle(Theme.ink)
            Spacer()
            Text(detail)
                .font(Theme.mono(11))
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 20)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("NO SHOWS YET")
                .font(Theme.mono(15, .bold))
                .foregroundStyle(Theme.ink)
            Text("Search Apple's podcast directory by name, or paste a link from Apple Podcasts or a show's RSS feed.")
                .foregroundStyle(Theme.muted)
            Button { addingShow = true } label: {
                Text("+ ADD A SHOW").font(Theme.mono(13, .bold)).padding(.horizontal, 18).frame(minHeight: 48)
            }
            .buttonStyle(.accentKey)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}

/// A card in the New Episodes carousel, like a cassette: artwork, a label
/// strip in the show's own colour, then the details and keys.
private struct EpisodeCard: View {
    @Environment(PlayerModel.self) private var player
    let episode: PodcastEpisode

    var body: some View {
        let strip = ArtworkColors.shared.background(for: episode.artwork) ?? Theme.placeholderColor(for: episode.podcast?.title ?? "")

        VStack(alignment: .leading, spacing: 0) {
            ArtworkView(url: episode.artwork, title: episode.podcast?.title ?? episode.title, size: 236, radius: 10)
                .padding(12)
            HStack {
                Text((episode.podcast?.title ?? "").uppercased()).lineLimit(1)
                Spacer(minLength: 8)
                Text(TimeFormat.ago(episode.published).uppercased())
            }
            .font(Theme.mono(10, .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 26)
            .background(strip)
            VStack(alignment: .leading, spacing: 8) {
                Text(episode.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2, reservesSpace: true)
                Text(episode.summary)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Button { player.play(episode) } label: {
                        Text("▶ \(playLabel)")
                            .font(Theme.mono(12, .bold))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 40)
                    }
                    .buttonStyle(.darkKey)
                    .accessibilityLabel("Play, \(playLabel)")
                    Spacer()
                    DownloadButton(episode: episode)
                    Menu {
                        EpisodeMenuItems(episode: episode)
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(width: 44, height: 44)
                            .foregroundStyle(Theme.ink)
                    }
                    .accessibilityLabel("More")
                }
            }
            .padding(12)
        }
        .frame(width: 260)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Theme.controlBorder, radius: 0, x: 0, y: 3)
        .task(id: episode.artwork) { await ArtworkColors.shared.load(episode.artwork) }
    }

    private var playLabel: String {
        guard let left = episode.timeLeft, left > 0 else { return "PLAY" }
        return TimeFormat.clock(left)
    }
}

private struct ShowTile: View {
    let show: Podcast

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                ArtworkView(url: show.artworkURL, title: show.title, size: proxy.size.width, radius: 10)
            }
            .aspectRatio(1, contentMode: .fit)
            Text(show.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            HStack(spacing: 6) {
                DeckTag(text: tag)
                Text("\(unplayed) NEW")
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var tag: String {
        switch show.autoAdd {
        case .top: return "TOP"
        case .bottom: return "BTM"
        case .off: return "OFF"
        }
    }

    private var unplayed: Int { show.episodes.filter { !$0.played }.count }
}

/// Play next / Play last / played actions, shared by cards and lists.
struct EpisodeMenuItems: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(DownloadManager.self) private var downloads
    @Environment(TranscriptService.self) private var transcripts
    let episode: PodcastEpisode

    var body: some View {
        Button("Play", systemImage: "play") { player.play(episode) }
        Button("Play next", systemImage: "text.line.first.and.arrowtriangle.forward") { store.playNext(episode) }
        Button("Play last", systemImage: "text.line.last.and.arrowtriangle.forward") { store.playLast(episode) }
        if downloads.progress[episode.episodeID] != nil {
            Button("Stop download", systemImage: "xmark.circle") { store.removeDownload(episode) }
        } else if episode.downloadFile != nil {
            Button("Remove download", systemImage: "trash", role: .destructive) { store.removeDownload(episode) }
        } else {
            Button("Download", systemImage: "arrow.down.circle") { downloads.download(episode) }
        }
        if transcripts.canTranscribeNow(episode) {
            Button("Transcribe now", systemImage: "text.quote") { transcripts.transcribeNow(episode) }
        }
        if episode.played {
            Button("Mark as unplayed", systemImage: "circle") { store.markUnplayed(episode) }
        } else {
            Button("Mark as played", systemImage: "checkmark.circle") { store.markPlayed(episode.episodeID) }
        }
    }
}

/// Download / progress / downloaded, for the New Episodes cards.
struct DownloadButton: View {
    @Environment(LibraryStore.self) private var store
    @Environment(DownloadManager.self) private var downloads
    let episode: PodcastEpisode
    var tint: Color = Theme.ink

    var body: some View {
        Group {
            if let fraction = downloads.progress[episode.episodeID] {
                Button { store.removeDownload(episode) } label: {
                    ZStack {
                        Circle().stroke(tint.opacity(0.3), lineWidth: 2)
                        Circle().trim(from: 0, to: max(0.03, fraction))
                            .stroke(tint == Theme.ink ? Theme.accentFill : tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: "stop.fill").font(.system(size: 8))
                    }
                    .frame(width: 22, height: 22)
                }
                .accessibilityLabel("Stop download, \(Int(fraction * 100)) percent done")
            } else if episode.downloadFile != nil {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(tint == Theme.ink ? Theme.accentText : tint)
                    .accessibilityLabel("Downloaded")
            } else {
                Button { downloads.download(episode) } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .accessibilityLabel("Download")
            }
        }
        .font(.title3)
        .foregroundStyle(tint)
        .frame(width: 44, height: 44)
    }
}
