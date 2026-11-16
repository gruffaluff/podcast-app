import SwiftUI
import PodcastCore

// Episodes as tabs (Paul, 15 Nov 2026: tabs): the overview's grid of tab
// cards, two across, in the group's order. Tap a tab to open it full
// screen; × or a swipe left closes it (like Safari); hold for a menu; in
// Up next, hold and drag a tab onto another to move it there.

struct DeckTabsGrid: View {
    @Environment(PlayerModel.self) private var player
    @Environment(DeckTabsModel.self) private var model
    let tabs: [PodcastEpisode]

    private static let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        LazyVGrid(columns: Self.columns, spacing: 10) {
            ForEach(tabs, id: \.episodeID) { episode in
                DeckTabCard(episode: episode, place: place(of: episode))
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
    }

    /// Up next's order on each tab (Paul, 16 Nov 2026: "add a number to
    /// the up next tabs to make it clear the order"): "Now" on the one
    /// playing, then 1, 2, 3… for what comes after. None in New / Saved.
    private func place(of episode: PodcastEpisode) -> String? {
        guard model.group == .upNext else { return nil }
        let playing: String? = player.nowPlaying?.episodeID
        if episode.episodeID == playing { return "Now" }
        var number: Int = 0
        for tab in tabs where tab.episodeID != playing {
            number += 1
            if tab.episodeID == episode.episodeID { return String(number) }
        }
        return nil
    }
}

private struct DeckTabCard: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(DeckTabsModel.self) private var model
    let episode: PodcastEpisode
    /// Its place in Up next ("Now", "1", "2"…), or nil.
    var place: String? = nil

    /// How far the card has been swiped sideways (left only).
    @State private var drag: CGFloat = 0
    @State private var width: CGFloat = 170
    @State private var closing = false
    @State private var notes: PodcastEpisode?

    private var actions: DeckTabActions { DeckTabActions(store: store, player: player, group: model.group) }
    private var isOn: Bool { player.nowPlaying?.episodeID == episode.episodeID }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 16, style: .continuous) }

    var body: some View {
        card
            .offset(x: drag)
            .opacity(1 - Double(min(0.6, abs(drag) / max(width, 1) * 0.6)))
            .gesture(DeckShowPan(isEnabled: !closing, changed: moved, ended: released))
            .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.width } action: { new in width = new }
            .sheet(item: $notes) { episode in EpisodeNotesView(episode: episode) }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            head
            Button { model.open(episode.episodeID) } label: { bodyPart }
                .buttonStyle(.plain)
                .accessibilityLabel("Open " + episode.title)
        }
        .background(shape.fill(Theme.surface)
            .shadow(color: Color(red: 40 / 255, green: 30 / 255, blue: 10 / 255).opacity(0.08), radius: 8, y: 2))
        .clipShape(shape)
        .overlay(shape.strokeBorder(isOn ? Theme.ink : Theme.cardEdge, lineWidth: isOn ? 2 : 1))
        .contentShape(.dragPreview, shape)
        .contentShape(.contextMenuPreview, shape)
        .contextMenu { menu }
        .modifier(DeckTabReorder(episode: episode, enabled: model.group == .upNext && !isOn))
    }

    /// A small square in the show's colour, its name and ×.
    private var head: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(showColour)
                .frame(width: 12, height: 12)
            Text(episode.showTitle)
                .font(Theme.outfit(11, .bold))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
            Spacer(minLength: 2)
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Theme.background))
                    .frame(width: 36, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.group == .saved ? "Close tab, remove from Saved" : "Close tab, mark played")
        }
        .padding(.leading, 8)
        .frame(height: 30)
    }

    /// "Now", "1", "2"… in a small ink pill on the artwork's corner.
    @ViewBuilder private var placeBadge: some View {
        if let place {
            Text(place)
                .font(Theme.outfit(13, .heavy))
                .monospacedDigit()
                .foregroundStyle(Color.white)
                .padding(.horizontal, 8)
                .frame(minWidth: 26, minHeight: 26)
                .background(Capsule().fill(Color(hex: 0x1C1B1A)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5))
                .padding(7)
                .accessibilityLabel(place == "Now" ? "Playing now" : "Number \(place) in Up next")
        }
    }

    private var bodyPart: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 108)
                .overlay {
                    CachedImage(url: episode.artwork) { Theme.placeholderColor(for: episode.showTitle) }
                }
                .clipped()
                .overlay(alignment: .topLeading) { placeBadge }
            Text(episode.title)
                .font(Theme.outfit(13, .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 9)
                .padding(.top, 7)
            HStack(spacing: 6) {
                DeckRing(progress: DeckRing.progress(of: episode), lineWidth: 2.5,
                         colour: Color(hex: 0xEC6550))
                    .frame(width: 16, height: 16)
                Text(detail)
                    .font(Theme.outfit(11, .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 9)
            .padding(.top, 5)
            .padding(.bottom, 9)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder private var menu: some View {
        Button(isOn && player.isPlaying ? "Pause" : "Play now", systemImage: isOn && player.isPlaying ? "pause" : "play") {
            actions.playNow(episode)
        }
        Button("Play next", systemImage: "text.line.first.and.arrowtriangle.forward") { actions.playNext(episode) }
        if actions.isQueued(episode) {
            Button("Remove from Up next", systemImage: "minus.circle") { actions.removeFromUpNext(episode) }
        }
        Button("Episode notes", systemImage: "doc.text") { notes = episode }
        DeckSaveForLaterMenuItem(episode: episode)
    }

    private var showColour: Color {
        ArtworkColors.shared.background(for: episode.artwork) ?? Theme.placeholderColor(for: episode.showTitle)
    }

    /// "Playing · 34m left", "34m left" once started, else "9 Nov · 52m".
    private var detail: String {
        let date: String = episode.published.formatted(.dateTime.day().month(.abbreviated))
        guard let duration = episode.duration, duration > 0 else { return isOn ? "Playing" : date }
        let left: TimeInterval = episode.timeLeft ?? duration
        if isOn { return "Playing · " + DeckUpNextTime.length(left) + " left" }
        if episode.position > 30 && left > 0 { return DeckUpNextTime.length(left) + " left" }
        return date + " · " + DeckUpNextTime.length(duration)
    }

    // MARK: Swipe to close (like Safari)

    private func moved(_ x: CGFloat) {
        guard !closing else { return }
        // Left only; a little give to the right.
        drag = x < 0 ? x : x * 0.15
    }

    private func released(_ velocity: CGFloat) {
        guard !closing else { return }
        let far: Bool = drag < -width * 0.35
        let flick: Bool = velocity < -700 && drag < -12
        if far || flick {
            closing = true
            withAnimation(.easeOut(duration: 0.2)) { drag = -width * 1.4 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                close()
                // If Undo brings it back, it comes back in place.
                drag = 0
                closing = false
            }
        } else {
            withAnimation(.spring(duration: 0.3)) { drag = 0 }
        }
    }

    private func close() {
        actions.close(episode)
    }
}

/// Hold and drag a tab onto another in Up next to move it to that place.
private struct DeckTabReorder: ViewModifier {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    let episode: PodcastEpisode
    let enabled: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if enabled {
            content
                .draggable(episode.episodeID)
                .dropDestination(for: String.self) { (items: [String], _: CGPoint) -> Bool in
                    guard let dragged = items.first else { return false }
                    let actions = DeckTabActions(store: store, player: player, group: .upNext)
                    return actions.move(dragged, onto: episode.episodeID)
                }
        } else {
            content
        }
    }
}
