import SwiftUI
import PodcastCore

/// One show: its details, its Up Next setting and its episodes, newest first.
struct ShowView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(\.dismiss) private var dismiss
    let show: Podcast
    @State private var confirmingUnfollow = false
    @State private var showingSettings = false

    var body: some View {
        let episodes = show.episodes.sorted { $0.published > $1.published }

        List {
            Section {
                header
                    .listRowBackground(Theme.background)
                    .listRowSeparator(.hidden)
            }
            Section {
                ForEach(episodes) { episode in
                    Button { player.play(episode) } label: {
                        EpisodeRow(episode: episode, isPlaying: player.nowPlaying?.episodeID == episode.episodeID, isQueued: store.isQueued(episode))
                    }
                    .buttonStyle(.plain)
                    .contextMenu { EpisodeMenuItems(episode: episode) }
                    .swipeActions(edge: .leading) {
                        Button("Play next") { store.playNext(episode) }
                            .tint(Theme.accentFill)
                        Button("Play last") { store.playLast(episode) }
                            .tint(Theme.ink)
                    }
                }
                .listRowBackground(Theme.background)
                .listRowSeparatorTint(Theme.hairline)
            } header: {
                Text("\(episodes.count) episodes")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .textCase(nil)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Show settings", systemImage: "slider.horizontal.3") { showingSettings = true }
                    Button("Unfollow", systemImage: "minus.circle", role: .destructive) { confirmingUnfollow = true }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("More")
            }
        }
        .sheet(isPresented: $showingSettings) { ShowSettingsView(show: show) }
        .confirmationDialog("Unfollow \(show.title)?", isPresented: $confirmingUnfollow, titleVisibility: .visible) {
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                ArtworkView(url: show.artworkURL, title: show.title, size: 110, radius: 14)
                VStack(alignment: .leading, spacing: 6) {
                    Text(show.title)
                        .font(Theme.screenTitle(24))
                        .foregroundStyle(Theme.ink)
                    if !show.author.isEmpty {
                        Text(show.author)
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
            if !show.summary.isEmpty {
                Text(show.summary)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(4)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("New episodes go to Up Next")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.ink)
                Picker("New episodes go to Up Next", selection: autoAdd) {
                    Text("Off").tag(AutoAddMode.off)
                    Text("Top").tag(AutoAddMode.top)
                    Text("Bottom").tag(AutoAddMode.bottom)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text(autoAddExplanation)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.vertical, 8)
    }

    private var autoAdd: Binding<AutoAddMode> {
        Binding(get: { show.autoAdd }, set: { store.setAutoAdd($0, for: show) })
    }

    private var autoAddExplanation: String {
        switch show.autoAdd {
        case .off: return "New episodes stay here until you add them."
        case .top: return "New episodes go near the top of Up Next, always in order, oldest first."
        case .bottom: return "New episodes go to the end of Up Next, always in order, oldest first."
        }
    }
}

private struct EpisodeRow: View {
    let episode: PodcastEpisode
    let isPlaying: Bool
    let isQueued: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(episode.published.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Text(episode.title)
                .font(.body.weight(.medium))
                .foregroundStyle(episode.played ? Theme.muted : Theme.ink)
                .lineLimit(2)
            if !episode.summary.isEmpty {
                Text(episode.summary)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
            }
            Text(meta)
                .font(.caption)
                .foregroundStyle(isPlaying ? Theme.accentText : Theme.muted)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var meta: String {
        var parts: [String] = []
        if isPlaying { parts.append("Playing") }
        if episode.played {
            parts.append("Played")
        } else if let left = episode.timeLeft, left > 0 {
            parts.append(episode.position > 30 ? "\(TimeFormat.length(left)) left" : TimeFormat.length(left))
        }
        if isQueued { parts.append("In Up Next") }
        return parts.joined(separator: " · ")
    }
}
