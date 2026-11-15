import SwiftUI
import PodcastCore

// Save for later (Paul, 15 Nov 2026): a list of episodes kept aside, apart
// from Up next. Saved from the Deck episode page (bookmark key) or a show
// page episode's menu; reached from the Shows tab ("Saved for later · 4")
// and Settings → Your listening. Kept as episode IDs, newest first, in the
// synced setting "savedForLater" (iCloud key-value storage via
// SettingsSync), so it comes back on a new iPhone. An episode played to
// the end leaves the list (`LibraryStore.markPlayed`).

/// The saved episode IDs, one per line (episode IDs are "feed|guid", so a
/// comma could be part of one; a line break can't).
enum SaveForLater {
    static let key = "savedForLater"
    static let limit = 300

    /// IDs from the stored text, newest first.
    static func ids(_ raw: String) -> [String] {
        raw.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    static var current: [String] {
        ids(UserDefaults.standard.string(forKey: key) ?? "")
    }

    static func isSaved(_ episodeID: String, in raw: String) -> Bool {
        ids(raw).contains(episodeID)
    }

    static func isSaved(_ episodeID: String) -> Bool {
        current.contains(episodeID)
    }

    /// Saves it (at the top) or, if already saved, takes it off.
    static func toggle(_ episodeID: String) {
        var list: [String] = current
        if let index = list.firstIndex(of: episodeID) {
            list.remove(at: index)
        } else {
            list.insert(episodeID, at: 0)
        }
        store(list)
    }

    static func remove(_ episodeID: String) {
        let list: [String] = current
        guard list.contains(episodeID) else { return }
        store(list.filter { $0 != episodeID })
    }

    /// Takes off several at once (played or gone episodes).
    static func remove(_ episodeIDs: Set<String>) {
        let list: [String] = current
        let kept: [String] = list.filter { !episodeIDs.contains($0) }
        guard kept.count != list.count else { return }
        store(kept)
    }

    private static func store(_ list: [String]) {
        let capped: [String] = Array(list.prefix(limit))
        UserDefaults.standard.set(capped.joined(separator: "\n"), forKey: key)
    }
}

// MARK: - Entry points

/// The episode page's bookmark key: hollow when not saved, filled when it is.
struct DeckSaveForLaterKey: View {
    let episode: PodcastEpisode
    @AppStorage(SaveForLater.key) private var raw: String = ""

    var body: some View {
        let saved: Bool = SaveForLater.isSaved(episode.episodeID, in: raw)
        return Button {
            SaveForLater.toggle(episode.episodeID)
        } label: {
            Image(systemName: saved ? "bookmark.fill" : "bookmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(saved ? Theme.background : Theme.ink)
                .frame(width: 50, height: 50)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(saved ? Theme.ink : Theme.background))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(saved ? "Saved for later" : "Save for later")
        .accessibilityHint(saved ? "Takes it off the Saved for later list" : "Keeps it aside, apart from Up next")
    }
}

/// "Save for later" / "Remove from Saved for later" for an episode's menu.
struct DeckSaveForLaterMenuItem: View {
    let episode: PodcastEpisode
    @AppStorage(SaveForLater.key) private var raw: String = ""

    var body: some View {
        let saved: Bool = SaveForLater.isSaved(episode.episodeID, in: raw)
        Button(saved ? "Remove from Saved for later" : "Save for later",
               systemImage: saved ? "bookmark.slash" : "bookmark") {
            SaveForLater.toggle(episode.episodeID)
        }
    }
}

/// On the Shows tab, near Carry on: "Saved for later · 4 ›" (only when
/// something is saved).
struct DeckSavedForLaterLink: View {
    @AppStorage(SaveForLater.key) private var raw: String = ""

    var body: some View {
        let count: Int = SaveForLater.ids(raw).count
        Group {
            if count > 0 {
                NavigationLink { DeckSavedForLaterView() } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 17))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 24)
                        Text("Saved for later")
                            .font(Theme.outfit(15, .bold))
                            .foregroundStyle(Theme.ink)
                        Spacer(minLength: 8)
                        Text("\(count)")
                            .font(Theme.outfit(14, .medium))
                            .monospacedDigit()
                            .foregroundStyle(Theme.muted)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.faint)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .contentShape(Rectangle())
                    .deckPlainCard(radius: 20)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .accessibilityLabel("Saved for later, \(count)")
            }
        }
    }
}

// MARK: - The list

struct DeckSavedForLaterView: View {
    @Environment(LibraryStore.self) private var store
    @AppStorage(SaveForLater.key) private var raw: String = ""
    @State private var episodes: [PodcastEpisode] = []
    /// The episode page, shown from here (this list can sit inside the
    /// Settings sheet, where the app's own episode sheet can't show).
    @State private var opened: PodcastEpisode?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(summary)
                    .font(Theme.outfit(13, .medium))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 4)
                if episodes.isEmpty {
                    empty
                } else {
                    ForEach(episodes, id: \.episodeID) { episode in
                        DeckSavedRow(episode: episode, open: { opened = episode })
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .deckPage()
        .navigationTitle("Saved for later")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
        .onChange(of: raw) { _, _ in reload() }
        .sheet(item: $opened) { episode in EpisodeNotesView(episode: episode) }
    }

    private var summary: String {
        let count: Int = episodes.count
        let words: String = count == 1 ? "1 episode" : "\(count) episodes"
        return words + " kept aside, apart from Up next"
    }

    private var empty: some View {
        Text("Nothing saved. Tap the bookmark on an episode's page, or touch and hold an episode on a show page, to keep it here for later.")
            .font(Theme.outfit(14, .medium))
            .foregroundStyle(Theme.muted)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .deckPlainCard(radius: 20)
    }

    /// Saved episodes still to hear, in saved order. Played or gone ones
    /// are dropped from the list as well.
    private func reload() {
        let ids: [String] = SaveForLater.ids(raw)
        let found: [String: PodcastEpisode] = store.episodes(ids)
        let shown: [PodcastEpisode] = ids.compactMap { found[$0] }.filter { !$0.played }
        episodes = shown
        let keep: Set<String> = Set(shown.map(\.episodeID))
        let drop: Set<String> = Set(ids.filter { !keep.contains($0) })
        if !drop.isEmpty {
            // After this redraw, not during it.
            DispatchQueue.main.async { SaveForLater.remove(drop) }
        }
    }
}

/// A saved episode: artwork, title, show · length; + adds it to Up next
/// (and takes it off this list), × takes it off. Tap for the episode page.
private struct DeckSavedRow: View {
    @Environment(LibraryStore.self) private var store
    let episode: PodcastEpisode
    let open: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: open) { words }
                .buttonStyle(.plain)
            key("plus", label: "Add to Up next", filled: true, action: add)
            key("xmark", label: "Remove from Saved for later", filled: false) {
                withAnimation(LibraryStore.listChange) { SaveForLater.remove(episode.episodeID) }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .deckPlainCard(radius: 20)
        .contextMenu {
            Button("Add to Up next", systemImage: "text.append", action: add)
            Button("Play next", systemImage: "text.line.first.and.arrowtriangle.forward") {
                store.undoable("Plays next", episodes: []) { store.playNext(episode) }
                SaveForLater.remove(episode.episodeID)
            }
            Button("Remove from Saved for later", systemImage: "bookmark.slash") {
                SaveForLater.remove(episode.episodeID)
            }
        }
    }

    private var words: some View {
        HStack(spacing: 12) {
            ArtworkView(url: episode.artwork, title: episode.showTitle, size: 44, radius: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(episode.title)
                    .font(Theme.outfit(15, .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                Text(DeckSuggestionWords.detail(episode))
                    .font(Theme.outfit(12, .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the episode page")
    }

    /// Adds it to the end of Up next by the usual rules, with Undo; the
    /// saved list lets it go (it's in Up next now).
    private func add() {
        store.undoable("Added to Up next", episodes: []) { store.playLast(episode) }
        SaveForLater.remove(episode.episodeID)
    }

    private func key(_ icon: String, label: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(filled ? Theme.background : Theme.ink)
                .frame(width: 36, height: 36)
                .background(Circle().fill(filled ? Theme.ink : Theme.background))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
