import SwiftUI
import UIKit
import PodcastCore

// Deck: Up next fanned out into the full list (prototype: renderFan,
// pullClose, reorder). Pull down past the top (or tap the handle) to put
// the deck back together. Hold a card and drag it to move it (the one
// playing stays first). Swipe a card left when heard, right a little to
// play it next, right all the way to send it to the bottom.

struct DeckUpNextFan: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    let plan: DeckQueuePlan
    let close: () -> Void

    /// How far the list is pulled down past its top.
    @State private var pulled: CGFloat = 0
    @State private var closing = false

    private static let closeLine: CGFloat = 110

    /// The cards: Up next in order, with the episode playing first if it
    /// isn't in Up next itself.
    private var rows: [PodcastEpisode] {
        guard let top = plan.top, !plan.all.contains(where: { $0.episodeID == top.episodeID }) else { return plan.all }
        return [top] + plan.all
    }

    var body: some View {
        let shown: [PodcastEpisode] = rows
        ScrollViewReader { proxy in
            List {
                header(count: shown.count)
                ForEach(shown, id: \.episodeID) { episode in
                    DeckFanRow(episode: episode, plan: plan)
                        .id(episode.episodeID)
                        .moveDisabled(episode.episodeID == plan.playingID)
                }
                .onMove { source, destination in move(from: source, to: destination, rows: shown) }
                footer
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .environment(\.defaultMinListRowHeight, 0)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                pulled = max(0, -offset)
            }
            .onScrollPhaseChange { old, _ in
                guard old == .interacting, pulled > Self.closeLine, !closing else { return }
                closing = true
                close()
            }
            .onChange(of: store.revealInUpNext, initial: true) { _, id in
                guard let id else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    withAnimation { proxy.scrollTo(id, anchor: .center) }
                    store.revealInUpNext = nil
                }
            }
        }
    }

    // MARK: Header and footer

    private func header(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            handle
            Text("Up next")
                .font(Theme.outfit(34, .heavy))
                .tracking(-1)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 6)
                .padding(.top, 2)
                .padding(.bottom, 4)
            Text(summary(count: count))
                .font(Theme.outfit(13, .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 6)
                .padding(.bottom, 10)
        }
        .plainFanRow()
    }

    private var handle: some View {
        Button(action: close) {
            VStack(spacing: 4) {
                Capsule().fill(Theme.cardEdge.mix(with: Theme.muted, by: 0.35)).frame(width: 40, height: 5)
                Text(pulled > Self.closeLine ? "Let go to close" : "Pull down to close")
                    .font(Theme.outfit(11, .semibold))
                    .foregroundStyle(Theme.faint)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
            .padding(.bottom, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close the list")
    }

    /// "6 episodes · 3h 26m at 1.2× · done by 16:17".
    private func summary(count: Int) -> String {
        let words: String = count == 1 ? "1 episode" : "\(count) episodes"
        let speed: String = String(format: "%g", plan.speed)
        return words + " · " + DeckUpNextTime.length(plan.total) + " at " + speed + "× · done by " + UpNextTimes.clock(plan.end)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Hold a card and drag to move it. Swipe left when heard. Swipe right a little to play it next, or all the way to send it to the bottom. New episodes are dealt in by your rules: Top shows first, each show oldest first.")
                .font(Theme.outfit(12, .medium))
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 6)
                .padding(.top, 14)
            keepPlaying
        }
        .padding(.bottom, 24)
        .plainFanRow()
    }

    private var keepPlaying: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Keep playing new episodes")
                    .font(Theme.outfit(15, .semibold))
                    .foregroundStyle(Theme.ink)
                Text("When the deck runs out, carry on with this week's new ones")
                    .font(Theme.outfit(12, .medium))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 8)
            Toggle("Keep playing new episodes",
                   isOn: Binding(get: { store.keepPlayingNew }, set: { store.keepPlayingNew = $0 }))
                .labelsHidden()
                .tint(Theme.ink)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .deckPlainCard(radius: 22)
    }

    // MARK: Moving

    /// Moves within the cards shown, as places in the whole of Up next.
    /// Nothing goes above the episode playing.
    private func move(from source: IndexSet, to destination: Int, rows: [PodcastEpisode]) {
        var target: Int = destination
        if let first = rows.first, first.episodeID == plan.playingID { target = max(1, target) }
        let ids: [String] = store.queue.map(\.episode.id)
        var full = IndexSet()
        for index in source where rows.indices.contains(index) {
            if let place = ids.firstIndex(of: rows[index].episodeID) { full.insert(place) }
        }
        guard !full.isEmpty else { return }
        let place: Int = target < rows.count ? (ids.firstIndex(of: rows[target].episodeID) ?? ids.count) : ids.count
        store.moveQueue(from: full, to: place)
    }
}

private extension View {
    /// A list row that's just part of the page (not a card, can't move).
    func plainFanRow() -> some View {
        self
            .moveDisabled(true)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    }
}

// MARK: - A card in the list

private struct DeckFanRow: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    let episode: PodcastEpisode
    let plan: DeckQueuePlan

    private var moves: DeckQueueMoves { DeckQueueMoves(store: store, player: player) }
    private var isOn: Bool { episode.episodeID == plan.playingID }
    private var text: Color { isOn ? Color.white : Theme.ink }
    private var sub: Color { isOn ? Color(hex: 0xB7B2A8) : Theme.muted }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            artButton
            Button { store.notesEpisode = episode } label: { titles }
                .buttonStyle(.plain)
            times
            grip
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .padding(.top, 14)
        .frame(maxWidth: .infinity, minHeight: 86, maxHeight: 86, alignment: .topLeading)
        .background { card }
        .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 22, style: .continuous))
        .modifier(DeckRowSwipe(left: { moves.played(episode) },
                               near: near, far: far,
                               nearTitle: isOn ? "Next in line" : "Play next",
                               canMoveRight: !isOn || moves.canMoveTop(episode)))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
    }

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return shape.fill(isOn ? Theme.playingCard : Theme.surface)
            .overlay(shape.strokeBorder(isOn ? Theme.playingCard : Theme.cardEdge, lineWidth: 1))
            .shadow(color: Color(red: 40 / 255, green: 30 / 255, blue: 10 / 255).opacity(0.06), radius: 6, y: -2)
    }

    private func near() {
        if isOn { moves.moveTop(episode, toBottom: false) } else { moves.playNext(episode) }
    }

    private func far() {
        if isOn { moves.moveTop(episode, toBottom: true) } else { moves.toBottom(episode) }
    }

    private var artButton: some View {
        Button { moves.playNow(episode) } label: {
            DeckUpNextArtwork(episode: episode, size: 46, radius: 12)
                .overlay {
                    if !isOn {
                        Image(systemName: "play.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.white)
                            .shadow(color: Color.black.opacity(0.35), radius: 3)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? (player.isPlaying ? "Pause" : "Play") : "Play " + episode.title)
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(plan.label(for: episode).uppercased())
                .font(Theme.outfit(11, .bold))
                .tracking(0.4)
                .foregroundStyle(sub)
                .lineLimit(1)
            Text(episode.title)
                .font(Theme.outfit(15, .bold))
                .foregroundStyle(text)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityHint("Opens the episode page")
    }

    private var times: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(timeWords)
                .font(Theme.outfit(12, .medium))
                .monospacedDigit()
                .foregroundStyle(sub)
                .lineLimit(1)
            EpisodeLights(episode: episode, onDark: isOn)
        }
        .fixedSize()
        .padding(.top, 1)
    }

    /// "Playing · 34m" for the one on, "16:20 · 26m" for the others.
    private var timeWords: String {
        let left: String = DeckUpNextTime.length(DeckQueuePlan.left(episode, player: player) / plan.speed)
        if isOn { return (player.isPlaying ? "Playing" : "Paused") + " · " + left }
        guard let start = plan.starts[episode.episodeID] else { return left }
        return UpNextTimes.clock(start) + " · " + left
    }

    @ViewBuilder private var grip: some View {
        if isOn {
            Color.clear.frame(width: 30, height: 58)
        } else {
            // Paul, 14 Nov 2026: the handle sits in the middle of the card
            // (86 pt row less 14 pt top padding = 58 pt either side of centre 43).
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.faint)
                .frame(width: 30, height: 58)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Row swipes

/// Left Played (green), right a little Play next (blue), right all the way
/// To the bottom (ink). The block behind is grey until a line is passed;
/// a tick at each line.
private struct DeckRowSwipe: ViewModifier {
    let left: () -> Void
    let near: () -> Void
    let far: () -> Void
    let nearTitle: String
    let canMoveRight: Bool

    @State private var offset: CGFloat = 0
    @State private var zone: DeckUpNextSwipeZone?

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .background { block }
            .gesture(DeckUpNextPan(isEnabled: true, changed: moved, ended: released))
            .accessibilityActions {
                Button("Played", action: left)
                if canMoveRight {
                    Button(nearTitle, action: near)
                    Button("To the bottom", action: far)
                }
            }
    }

    private func moved(_ x: CGFloat) {
        offset = canMoveRight ? x : min(0, x)
        let now: DeckUpNextSwipeZone? = DeckUpNextSwipeZone.of(offset, allowRight: canMoveRight)
        if now != zone {
            if now != nil { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
            zone = now
        }
    }

    private func released(_ velocity: CGFloat) {
        let fire: DeckUpNextSwipeZone? = zone
        zone = nil
        guard let fire else {
            withAnimation(.spring(duration: 0.3)) { offset = 0 }
            return
        }
        let direction: CGFloat = offset > 0 ? 1 : -1
        withAnimation(.easeIn(duration: 0.18)) { offset = direction * 480 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            switch fire {
            case .left: left()
            case .near: near()
            case .far: far()
            }
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) { offset = 0 }
        }
    }

    @ViewBuilder private var block: some View {
        if offset != 0 {
            let toRight: Bool = offset > 0
            let isFar: Bool = offset >= DeckUpNextSwipeZone.farLine
            let title: String = toRight ? (isFar ? "To the bottom" : nearTitle) : "Played"
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(blockColour(toRight: toRight, isFar: isFar))
                .overlay(alignment: toRight ? .leading : .trailing) {
                    Text(title)
                        .font(Theme.outfit(15, .heavy))
                        .foregroundStyle(isFar && zone != nil ? Theme.background : Color.white)
                        .padding(.horizontal, 20)
                        .scaleEffect(zone != nil ? 1.03 : 1)
                }
                .accessibilityHidden(true)
        }
    }

    private func blockColour(toRight: Bool, isFar: Bool) -> Color {
        guard zone != nil else { return Color(hex: 0xCFC9BF) }
        if !toRight { return DeckUpNextSwipeZone.green }
        return isFar ? Theme.ink : DeckUpNextSwipeZone.blue
    }
}
