import SwiftUI
import UIKit
import Combine
import PodcastCore

/// The bottom of the app (Deck 0, Paul 11 Nov 2026): a deck on a plate
/// along the bottom of every screen, so everything you press is in thumb
/// reach. On Listen it's the full deck: the green display (chapter, time,
/// when it ends, what's left, progress), skip / play / skip, then the tabs.
/// On the other tabs a slim strip: a small display and the play key above
/// the tabs. Tap the display, or swipe up on the deck, for the player.
/// It sits under the tabs in RootView's VStack, not over them (a dead spot
/// above it where scrolling did nothing, builds 140 and 141).
struct BottomDock: View {
    @Environment(PlayerModel.self) private var player
    @Binding var showingPlayer: Bool
    @Binding var tab: Int
    /// The deck steps aside while typing, so search results and their play
    /// keys are never hidden under it.
    @State private var keyboardUp = false

    private var playing: Bool { player.nowPlaying != nil }

    var body: some View {
        Group {
            if keyboardUp {
                Color.clear.frame(height: 0)
            } else {
                deck
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardUp = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardUp = false }
    }

    private var deck: some View {
        VStack(spacing: 0) {
            if playing {
                Capsule().fill(Theme.controlBorder).frame(width: 34, height: 4)
                    .padding(.bottom, 8)
                if tab == 0 {
                    DeckNowDisplay { showingPlayer = true }
                    DeckTransport()
                        .padding(.top, 10)
                } else {
                    SlimDeck { showingPlayer = true }
                }
            }
            DeckTabs(tab: $tab)
                .padding(.top, playing ? 6 : 0)
                .overlay(alignment: .top) {
                    if playing { Rectangle().fill(Theme.ink.opacity(0.07)).frame(height: 1) }
                }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous)
                .fill(Theme.plate)
                .shadow(color: .black.opacity(0.08), radius: 10, y: -3)
                .ignoresSafeArea(edges: .bottom)
        }
        .contentShape(Rectangle())
        // Swipe up on the deck for the player (alongside the keys' taps).
        .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { value in
            if playing, value.translation.height < -30 { showingPlayer = true }
        })
        .animation(.easeInOut(duration: 0.2), value: tab == 0)
    }
}

/// The full deck's display: chapter and speed, the episode, the time with
/// when it ends and what's left, and the progress blocks. Tap for the player.
struct DeckNowDisplay: View {
    @Environment(PlayerModel.self) private var player
    let open: () -> Void

    var body: some View {
        if let item = player.nowPlaying {
            let left = max(0, player.duration - player.currentTime)
            Button(action: open) {
                LCDPanel {
                    HStack {
                        Text(chapterLine.uppercased()).lineLimit(1)
                        Spacer(minLength: 6)
                        Text(PlayerOptions.speedLabel(player.speed))
                    }
                    Text(item.title.uppercased())
                        .font(Theme.mono(12, .medium))
                        .foregroundStyle(Deck0.lcdBright)
                        .lineLimit(1)
                    HStack(alignment: .firstTextBaseline) {
                        Text(TimeFormat.clock(player.currentTime))
                            .font(Theme.mono(14, .medium))
                            .foregroundStyle(Deck0.lcdBright)
                        Spacer(minLength: 6)
                        Text("ENDS " + UpNextTimes.clock(Date().addingTimeInterval(left / max(player.speed, 0.5))))
                            .foregroundStyle(Deck0.lcdDim)
                        Spacer(minLength: 6)
                        Text("−" + TimeFormat.clock(left))
                    }
                    .monospacedDigit()
                    LCDProgress(progress: player.duration > 0 ? player.currentTime / player.duration : 0,
                                chapterStarts: chapterStarts, ads: adFractions)
                        .padding(.top, 2)
                }
                .overlay(alignment: .topTrailing) { skipAd }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(item.title), \(TimeFormat.clock(left)) left")
            .accessibilityHint("Opens the player")
        }
    }

    private var chapterLine: String {
        if let index = player.currentChapterIndex, player.chapters.indices.contains(index) {
            return "Ch \(index + 1) · \(player.chapters[index].title)"
        }
        return player.nowPlaying?.showTitle ?? ""
    }

    private var chapterStarts: [Double] {
        guard player.duration > 0 else { return [] }
        return player.chapters.map { $0.start / player.duration }
    }

    private var adFractions: [ClosedRange<Double>] {
        guard player.duration > 0 else { return [] }
        return player.adBreaks.map { ($0.start / player.duration)...($0.end / player.duration) }
    }

    @ViewBuilder private var skipAd: some View {
        if player.currentAd != nil {
            Button { player.skipCurrentAd() } label: {
                Text("SKIP AD")
                    .font(Theme.mono(10, .bold))
                    .foregroundStyle(Deck0.lcd)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 28)
                    .background(Deck0.lcdAd, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(6)
            .accessibilityLabel("Skip ad")
        }
    }
}

/// On the other tabs: a small display (tap for the player) and play.
private struct SlimDeck: View {
    @Environment(PlayerModel.self) private var player
    let open: () -> Void

    var body: some View {
        if let item = player.nowPlaying {
            let left = max(0, player.duration - player.currentTime)
            HStack(spacing: 10) {
                Button(action: open) {
                    LCDPanel(vertical: 7) {
                        Text(item.title.uppercased())
                            .font(Theme.mono(10.5, .medium))
                            .foregroundStyle(Deck0.lcdBright)
                            .lineLimit(1)
                        HStack {
                            Text(TimeFormat.clock(player.currentTime))
                            Spacer(minLength: 4)
                            Text("−" + TimeFormat.clock(left)).foregroundStyle(Deck0.lcdDim)
                        }
                        .font(Theme.mono(9.5))
                        .monospacedDigit()
                    }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(item.title), \(TimeFormat.clock(left)) left")
                .accessibilityHint("Opens the player")
                if player.currentAd != nil {
                    Button { player.skipCurrentAd() } label: {
                        Text("SKIP AD")
                            .font(Theme.mono(10, .bold))
                            .foregroundStyle(Deck0.lcd)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 44)
                            .background(Deck0.lcdAd, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Skip ad")
                }
                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 17, weight: .bold))
                        .frame(width: 58, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(DeckKeyStyle(red: true, radius: 12))
                .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
            }
            .task(id: item.artworkURL) { await ArtworkColors.shared.load(item.artworkURL) }
        }
    }
}
