import SwiftUI
import UIKit
import SwiftData
import PodcastCore

// Deck (Paul, 14 Nov 2026): the New sheet from the Shows tab's "New · n"
// pill (prototype sheet "new"). Paul, 15 Nov 2026 ("go for all"): it opens
// as a one-at-a-time catch-up of the episodes you haven't looked at yet:
// each new episode as a big card; swipe right to play it next, left to skip
// it (marked played), or tap + to leave it to your rules (Keep when it's
// already in Up next). Each one you deal with is remembered, so the count
// on the pill is "new since you last looked". "List" shows the whole week
// as before, with Add all / Mark all played.

/// Episodes already dealt with in the catch-up, kept on this iPhone.
enum DeckTriage {
    static let key = "deckTriaged"

    static func seen(_ raw: String) -> Set<String> {
        Set(raw.split(separator: "\n").map(String.init))
    }

    /// Adds one, keeping the newest 400 so it can't grow for ever.
    static func adding(_ id: String, to raw: String) -> String {
        var list: [String] = raw.split(separator: "\n").map(String.init).filter { $0 != id }
        list.append(id)
        return list.suffix(400).joined(separator: "\n")
    }
}

struct DeckShowsNewSheet: View {
    @Environment(LibraryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Query(LibraryView.newEpisodesQueryForList) private var unplayed: [PodcastEpisode]
    @AppStorage(DeckTriage.key) private var triaged: String = ""
    @State private var listMode = false
    /// The episode page opened from here (shown over this sheet; the root
    /// view can't show one while this sheet is up).
    @State private var opened: PodcastEpisode?

    private var fresh: [PodcastEpisode] {
        let cutoff: Date = Date().addingTimeInterval(-LibraryView.newFor)
        return unplayed.filter { $0.podcast != nil && DeckShowOrder.isNew($0, cutoff: cutoff) }
    }

    /// Oldest first, so you catch up in the order they came out.
    private var unseen: [PodcastEpisode] {
        let seen: Set<String> = DeckTriage.seen(triaged)
        return fresh.filter { !seen.contains($0.episodeID) }.sorted { $0.published < $1.published }
    }

    var body: some View {
        Group {
            if listMode { listBody } else { triageBody }
        }
        .overlay(alignment: .topTrailing) { modeKey }
        .overlay(alignment: .bottom) {
            UndoBar()
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(Theme.background)
        .sheet(item: $opened) { episode in
            EpisodeNotesView(episode: episode)
        }
    }

    private var modeKey: some View {
        Button { listMode.toggle() } label: {
            Text(listMode ? "Catch up" : "List")
                .font(Theme.outfit(14, .bold))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(Capsule().fill(Theme.surface))
                .overlay(Capsule().strokeBorder(Theme.cardEdge, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.top, 20)
        .padding(.trailing, 16)
    }

    // MARK: Catch up

    private var triageBody: some View {
        let left: [PodcastEpisode] = unseen
        return VStack(alignment: .leading, spacing: 0) {
            triageHeading(left.count)
            if let top = left.first {
                DeckTriageCard(episode: top, open: { opened = top },
                               nextUp: { deal(top) { store.playNext(top) } },
                               skip: { deal(top) { store.markPlayed(top.episodeID) } },
                               keep: { deal(top) { if !store.isQueued(top) { store.playLast(top) } } })
                    .id(top.episodeID)
                    .padding(.top, 16)
                Spacer(minLength: 12)
                if left.count > 1 { rest(left) }
            } else {
                caughtUp
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 22)
        .padding(.bottom, 70)
    }

    private func triageHeading(_ count: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(count == 0 ? "Caught up" : "\(count) new since you last looked")
                .font(Theme.outfit(22, .heavy))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Swipe right to play next, left to skip. + leaves it to your rules.")
                .font(Theme.outfit(13, .medium))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
        .padding(.trailing, 80)
    }

    private var caughtUp: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Theme.muted)
            Text("All caught up")
                .font(Theme.outfit(20, .heavy))
                .foregroundStyle(Theme.ink)
            Text("New episodes land here as they arrive. List shows the whole week.")
                .font(Theme.outfit(13, .medium))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    /// The rest in one go: leave them all to your rules, or skip them all.
    private func rest(_ left: [PodcastEpisode]) -> some View {
        HStack(spacing: 8) {
            Button { keepAll(left) } label: {
                DeckShowPill(title: "Keep the rest", wide: true, height: 44)
            }
            .buttonStyle(.plain)
            Button { skipAll(left) } label: {
                DeckShowPill(title: "Skip the rest", wide: true, height: 44)
            }
            .buttonStyle(.plain)
        }
    }

    /// Does it, remembers the episode as looked at, and moves on.
    private func deal(_ episode: PodcastEpisode, _ change: () -> Void) {
        withAnimation(.snappy(duration: 0.25)) {
            change()
            triaged = DeckTriage.adding(episode.episodeID, to: triaged)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func keepAll(_ left: [PodcastEpisode]) {
        let missing: [PodcastEpisode] = left.filter { !store.isQueued($0) }
        addAll(missing)
        var raw: String = triaged
        for episode in left { raw = DeckTriage.adding(episode.episodeID, to: raw) }
        triaged = raw
    }

    private func skipAll(_ left: [PodcastEpisode]) {
        markAll(left)
        var raw: String = triaged
        for episode in left { raw = DeckTriage.adding(episode.episodeID, to: raw) }
        triaged = raw
    }

    // MARK: List (as before)

    private var listBody: some View {
        let list: [PodcastEpisode] = fresh
        return ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                heading(list.count)
                if list.isEmpty {
                    Text("All caught up.")
                        .font(Theme.outfit(15, .medium))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    ForEach(list, id: \.episodeID) { episode in
                        DeckShowsNewRow(episode: episode) { opened = episode }
                    }
                    actions(list)
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 22)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private func heading(_ count: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(count) new this week")
                .font(Theme.outfit(22, .heavy))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Already dealt in by your rules. Shows set to Nowhere wait here.")
                .font(Theme.outfit(13, .medium))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
        .padding(.trailing, 80)
        .padding(.bottom, 6)
    }

    private func actions(_ list: [PodcastEpisode]) -> some View {
        let missing: [PodcastEpisode] = list.filter { !store.isQueued($0) }
        return HStack(spacing: 8) {
            Button { addAll(missing) } label: {
                DeckShowPill(title: missing.isEmpty ? "All in Up next" : "Add all to Up next",
                             on: !missing.isEmpty, wide: true, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(missing.isEmpty)
            Button { markAll(list) } label: {
                DeckShowPill(title: "Mark all played", wide: true, height: 44)
            }
            .buttonStyle(.plain)
        }
    }

    /// Those not in Up next yet go in, oldest first, by the queue rules.
    private func addAll(_ missing: [PodcastEpisode]) {
        guard !missing.isEmpty else { return }
        let oldestFirst: [PodcastEpisode] = missing.sorted { $0.published < $1.published }
        store.undoable("Added \(oldestFirst.count) to Up next", episodes: []) {
            store.commit(QueueEngine.playLast(oldestFirst.map(\.queueEpisode), in: store.queue, settings: store.queueSettings))
        }
    }

    private func markAll(_ list: [PodcastEpisode]) {
        store.undoable("Marked \(list.count) played", episodes: list) { store.markPlayed(list) }
    }
}

/// One new episode: artwork (plays), show · when, title, its place in Up
/// next; + (when not in Up next) and ✓.
private struct DeckShowsNewRow: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    let episode: PodcastEpisode
    let open: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Round with a coral ring: new, not started (Paul, 15 Nov 2026:
            // rings, "like an unread story").
            Button { player.play(episode) } label: {
                DeckNewRingArtwork(episode: episode, size: 48, lineWidth: 2.5, gap: 2.5)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play \(episode.title)")
            Button(action: open) { words }
                .buttonStyle(.plain)
            if !store.isQueued(episode) {
                round("plus", label: "Add to Up next", dark: true) {
                    withAnimation(LibraryStore.listChange) { store.playLast(episode) }
                }
            }
            round("checkmark", label: "Mark played", dark: false) {
                store.undoable("Marked played", episodes: [episode]) { store.markPlayed(episode.episodeID) }
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .padding(.vertical, 10)
        .deckPlainCard(radius: 18)
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(episode.showTitle + " · " + TimeFormat.ago(episode.published))
                .font(Theme.outfit(12, .medium))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
            Text(episode.title)
                .font(Theme.outfit(15, .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(place)
                .font(Theme.outfit(12, .medium))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var place: String {
        guard let index = store.queue.firstIndex(where: { $0.episode.id == episode.episodeID }) else { return "Not in Up next" }
        return "\(EpisodeStatusRows.ordinal(index + 1)) in Up next"
    }

    private func round(_ symbol: String, label: String, dark: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(dark ? Theme.background : Theme.ink)
                .frame(width: 38, height: 38)
                .background(Circle().fill(dark ? Theme.ink : Theme.cardLine))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// One new episode in the catch-up: big artwork, show · when, title, where
/// it is in Up next, a few lines of notes; swipe right (Play next) or left
/// (Skip), or the three keys under it. Tap the words for the episode page.
private struct DeckTriageCard: View {
    @Environment(LibraryStore.self) private var store
    let episode: PodcastEpisode
    let open: () -> Void
    let nextUp: () -> Void
    let skip: () -> Void
    let keep: () -> Void
    @State private var drag: CGFloat = 0

    private static let line: CGFloat = 100

    var body: some View {
        VStack(spacing: 14) {
            card
                .offset(x: drag)
                .rotationEffect(.degrees(Double(drag / 30)))
                .overlay(alignment: .topLeading) { stamp("PLAY NEXT", shown: drag > Self.line / 2) }
                .overlay(alignment: .topTrailing) { stamp("SKIP", shown: drag < -Self.line / 2) }
                .gesture(DeckShowPan(isEnabled: true, changed: { drag = $0 }, ended: released))
            keys
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Round with a coral ring: new, not started (Paul, 15 Nov 2026: rings).
            DeckNewRingArtwork(episode: episode, size: 128, lineWidth: 4, gap: 4)
            Button(action: open) { words }
                .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .deckPlainCard(radius: 28, lifted: true)
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(episode.showTitle + " · " + TimeFormat.ago(episode.published))
                .font(Theme.outfit(13, .semibold))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
            Text(episode.title)
                .font(Theme.outfit(21, .heavy))
                .tracking(-0.4)
                .foregroundStyle(Theme.ink)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            Text(place)
                .font(Theme.outfit(13, .bold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 2)
            if !notes.isEmpty {
                Text(notes)
                    .font(Theme.outfit(13, .medium))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var keys: some View {
        HStack(spacing: 8) {
            key("Skip", icon: "xmark", dark: false, action: skip)
            key(store.isQueued(episode) ? "Keep" : "Up next", icon: "plus", dark: false, action: keep)
            key("Play next", icon: "arrow.up", dark: true, action: nextUp)
        }
    }

    private func key(_ title: String, icon: String, dark: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            DeckShowPill(title: title, icon: icon, on: dark, wide: true, height: 46)
        }
        .buttonStyle(.plain)
    }

    private func stamp(_ text: String, shown: Bool) -> some View {
        Text(text)
            .font(Theme.outfit(14, .heavy))
            .tracking(1)
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Capsule().fill(Theme.surface))
            .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 2))
            .padding(18)
            .opacity(shown ? 1 : 0)
    }

    private func released(_ velocity: CGFloat) {
        let flick: Bool = abs(drag) > 40 && abs(velocity) > 700
        guard abs(drag) > Self.line || flick else {
            withAnimation(.spring(duration: 0.3)) { drag = 0 }
            return
        }
        let right: Bool = drag > 0
        withAnimation(.easeIn(duration: 0.18)) { drag = right ? 600 : -600 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            if right { nextUp() } else { skip() }
        }
    }

    private var place: String {
        guard let index = store.queue.firstIndex(where: { $0.episode.id == episode.episodeID }) else {
            return "Not in Up next"
        }
        return "Already \(EpisodeStatusRows.ordinal(index + 1)) in Up next"
    }

    private var notes: String { episode.summary }
}
