import SwiftUI
import SwiftData
import PodcastCore

struct LibraryView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @State private var continuing: [PodcastEpisode] = []
    @Query(sort: \Podcast.title) private var shows: [Podcast]
    @Query(LibraryView.newEpisodesQuery) private var newEpisodes: [PodcastEpisode]
    @State private var addingShow = false
    @AppStorage("showsLayout") private var showsLayout = "large"

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
                VStack(alignment: .leading, spacing: 10) {
                    if shows.isEmpty {
                        emptyState
                    } else {
                        HStack(spacing: 8) {
                            NavigationLink { HistoryView() } label: { libraryKey("HISTORY", icon: "clock.arrow.circlepath") }
                            NavigationLink { StatsView() } label: { libraryKey("STATS", icon: "chart.bar") }
                        }
                        .buttonStyle(KeyButtonStyle(radius: 8))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 3)

                        if !continuing.isEmpty {
                            sectionTitle("CONTINUE LISTENING", detail: "\(continuing.count) STARTED")
                            VStack(spacing: 6) {
                                ForEach(continuing) { episode in
                                    Button { player.play(episode) } label: { HistoryRow(episode: episode) }
                                        .buttonStyle(.plain)
                                        .contextMenu { EpisodeMenuItems(episode: episode) }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                        }

                        if !newEpisodes.isEmpty {
                            sectionTitle("NEW EPISODES", detail: "\(newEpisodes.count) UNPLAYED")
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 12) {
                                    ForEach(newEpisodes) { episode in
                                        EpisodeCard(episode: episode)
                                    }
                                }
                                .scrollTargetLayout()
                                .padding(.horizontal, 20)
                            }
                            // Settles on a card after a swipe, like Apple Podcasts.
                            .scrollTargetBehavior(.viewAligned)
                        }

                        HStack(alignment: .center) {
                            sectionTitle("YOUR SHOWS", detail: "\(shows.count) FOLLOWED")
                            showsLayoutSwitch
                                .padding(.trailing, 20)
                        }
                        .padding(.top, 14)
                        yourShows
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 12)
            }
            .background(Theme.background)
            .refreshable { await store.refreshAll() }
            .onAppear { continuing = store.continueListening(excluding: player.nowPlaying?.episodeID, limit: 3) }
            .onChange(of: player.nowPlaying?.episodeID) { _, id in continuing = store.continueListening(excluding: id, limit: 3) }
            .tabTitle("LIBRARY")
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

    /// Large artwork tiles, small card + description, or description only
    /// (Paul's choice, remembered and synced).
    @ViewBuilder private var yourShows: some View {
        switch showsLayout {
        case "card":
            VStack(spacing: 6) {
                ForEach(shows) { show in
                    NavigationLink(value: show) {
                        HStack(spacing: 12) {
                            ArtworkView(url: show.artworkURL, title: show.title, size: 52, radius: 10)
                            showText(show)
                            Spacer(minLength: 0)
                        }
                        .padding(8)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        case "list":
            VStack(spacing: 0) {
                ForEach(shows) { show in
                    NavigationLink(value: show) {
                        showText(show)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                            .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 1) }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        default:
            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
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

    private func showText(_ show: Podcast) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(show.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            if !show.summary.isEmpty {
                Text(show.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    private var showsLayoutSwitch: some View {
        HStack(spacing: 2) {
            layoutKey("large", icon: "square.grid.2x2.fill", label: "Large cards")
            layoutKey("card", icon: "list.bullet.below.rectangle", label: "Small cards with description")
            layoutKey("list", icon: "text.alignleft", label: "Description only")
        }
        .padding(3)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func layoutKey(_ value: String, icon: String, label: String) -> some View {
        let on = showsLayout == value
        return Button { showsLayout = value } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(on ? Theme.onAccent : Theme.ink)
                .frame(width: 38, height: 32)
                .background(on ? Theme.accentFill : .clear, in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func libraryKey(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title).font(Theme.mono(12, .bold))
        }
        .frame(maxWidth: .infinity, minHeight: 40)
    }

    private func sectionTitle(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Theme.mono(11, .bold))
                .tracking(1.4)
                .foregroundStyle(Theme.muted)
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

/// A card in the New Episodes carousel, like Apple Podcasts': the artwork
/// fills the card and fades into its own colour, with the time ago, title,
/// description and keys in white over the colour.
private struct EpisodeCard: View {
    @Environment(PlayerModel.self) private var player
    @Environment(LibraryStore.self) private var store
    let episode: PodcastEpisode

    // Option E (Paul, 5 Nov 2026): Apple Podcasts' proportions.
    private static let width: CGFloat = 248
    private static let height: CGFloat = 330

    var body: some View {
        let tint = ArtworkColors.shared.background(for: episode.artwork) ?? Theme.placeholderColor(for: episode.podcast?.title ?? "")

        ZStack(alignment: .bottomLeading) {
            tint
            // The artwork across the top, fading into the colour.
            CachedImage(url: episode.artwork) { Color.clear }
                .frame(width: Self.width, height: Self.width)
                .clipped()
                .frame(maxHeight: .infinity, alignment: .top)
                .accessibilityHidden(true)
            LinearGradient(stops: [.init(color: tint.opacity(0), location: 0.3),
                                   .init(color: tint.opacity(0.85), location: 0.55),
                                   .init(color: tint, location: 0.7)],
                           startPoint: .top, endPoint: .bottom)
            details(tint: tint)
        }
        .frame(width: Self.width, height: Self.height)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .onTapGesture { store.notesEpisode = episode }
        .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
        .padding(.bottom, 6)
        .task(id: episode.artwork) { await ArtworkColors.shared.load(episode.artwork) }
    }

    private func details(tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\((episode.podcast?.title ?? "").uppercased()) · \(TimeFormat.ago(episode.published).uppercased())")
                .font(Theme.mono(10, .bold))
                .tracking(0.6)
                .foregroundStyle(Theme.displayText.opacity(0.75))
                .lineLimit(1)
            Text(episode.title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.displayText)
                .lineLimit(2)
            Text(episode.summary)
                .font(.footnote)
                .foregroundStyle(Theme.displayText.opacity(0.8))
                .lineLimit(1)
            HStack(spacing: 14) {
                Button { player.play(episode) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text(playLabel).monospacedDigit()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.displayText)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .background(.white.opacity(0.22), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play, \(playLabel)")
                Spacer(minLength: 4)
                DownloadButton(episode: episode, tint: Theme.displayText)
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.displayText)
                Menu {
                    EpisodeMenuItems(episode: episode)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.displayText)
                        .frame(width: 32, height: 36)
                }
                .accessibilityLabel("More")
            }
            .padding(.top, 6)
        }
        .padding(16)
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
        Button("Episode notes", systemImage: "doc.text") { store.notesEpisode = episode }
        Button("Play next", systemImage: "text.line.first.and.arrowtriangle.forward") { store.playNext(episode) }
        Button("Play last", systemImage: "text.line.last.and.arrowtriangle.forward") { store.playLast(episode) }
        if downloads.progress[episode.episodeID] != nil {
            Button("Stop download", systemImage: "xmark.circle") { store.removeDownload(episode) }
        } else if episode.downloadFile != nil {
            Button("Remove download", systemImage: "trash", role: .destructive) { store.removeDownload(episode) }
        } else {
            Button("Download", systemImage: "arrow.down.circle") { downloads.download(episode) }
        }
        if transcripts.isQueued(episode) {
            Button("Stop transcribing", systemImage: "stop.circle") { transcripts.stop(episode) }
        } else if transcripts.canTranscribeNow(episode) {
            Button("Transcribe now", systemImage: "text.quote") { transcripts.transcribeNow(episode) }
        }
        if episode.played {
            Button("Mark as unplayed", systemImage: "circle") { store.markUnplayed(episode) }
        } else {
            Button("Mark as played", systemImage: "checkmark.circle") {
                store.undoable("Marked played", episodes: [episode]) { store.markPlayed(episode.episodeID) }
            }
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
