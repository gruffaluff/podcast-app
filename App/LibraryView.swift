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
                            sectionTitle("New Episodes")
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 14) {
                                    ForEach(newEpisodes) { episode in
                                        EpisodeCard(episode: episode)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        sectionTitle("Your shows")
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
            .navigationTitle("Library")
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

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(Theme.screenTitle(22))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 20)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Follow your first show")
                .font(Theme.screenTitle(22))
                .foregroundStyle(Theme.ink)
            Text("Search Apple's podcast directory by name, or paste a show's RSS feed link.")
                .foregroundStyle(Theme.muted)
            Button("Add a show") { addingShow = true }
                .buttonStyle(.borderedProminent)
                .tint(Theme.ink)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}

/// A large card in the New Episodes carousel.
private struct EpisodeCard: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    let episode: PodcastEpisode

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ArtworkView(url: episode.artwork, title: episode.podcast?.title ?? episode.title, size: 236, radius: 14)
            Text(TimeFormat.ago(episode.published).uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.muted)
            Text(episode.title)
                .font(.system(.headline, design: .serif))
                .foregroundStyle(Theme.ink)
                .lineLimit(2, reservesSpace: true)
            Text(episode.summary)
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
            HStack {
                Button { player.play(episode) } label: {
                    Label(playLabel, systemImage: "play.fill")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(Theme.ink, in: Capsule())
                        .foregroundStyle(Theme.background)
                }
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
        .frame(width: 260)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
    }

    private var playLabel: String {
        let length = TimeFormat.length(episode.timeLeft ?? 0)
        return length.isEmpty ? "Play" : length
    }
}

private struct ShowTile: View {
    let show: Podcast

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                ArtworkView(url: show.artworkURL, title: show.title, size: proxy.size.width, radius: 14)
            }
            .aspectRatio(1, contentMode: .fit)
            Text(show.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Text(autoAddLabel)
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
    }

    private var autoAddLabel: String {
        switch show.autoAdd {
        case .top: return "Auto-add · Top"
        case .bottom: return "Auto-add · Bottom"
        case .off: return "\(show.episodes.count) episodes"
        }
    }
}

/// Play next / Play last / played actions, shared by cards and lists.
struct EpisodeMenuItems: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(DownloadManager.self) private var downloads
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

    var body: some View {
        Group {
            if let fraction = downloads.progress[episode.episodeID] {
                Button { store.removeDownload(episode) } label: {
                    ZStack {
                        Circle().stroke(Theme.controlBorder, lineWidth: 2)
                        Circle().trim(from: 0, to: max(0.03, fraction))
                            .stroke(Theme.accentFill, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: "stop.fill").font(.system(size: 8))
                    }
                    .frame(width: 22, height: 22)
                }
                .accessibilityLabel("Stop download, \(Int(fraction * 100)) percent done")
            } else if episode.downloadFile != nil {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(Theme.accentText)
                    .accessibilityLabel("Downloaded")
            } else {
                Button { downloads.download(episode) } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .accessibilityLabel("Download")
            }
        }
        .font(.title3)
        .foregroundStyle(Theme.ink)
        .frame(width: 44, height: 44)
    }
}
