import SwiftUI
import PodcastCore

// The insides of Up next's top card, one per Layout choice (prototype:
// topCard). Standard: artwork, show · chapter, title, line, times, skip /
// play / skip. Calm: the same, muted, with a Sleep pill in place of the
// skips. Big buttons: one huge pause and two big skip tiles. Read along:
// the line being said, large.

/// Standard and Calm.
struct DeckStandardTop: View {
    let info: DeckTopInfo
    let actions: DeckTopActions
    let calm: Bool
    var words = DeckTopWords()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            artworkBlock
                .padding(.horizontal, 18)
                .padding(.top, 18)
            titles
                .padding(.horizontal, 22)
                .padding(.top, 14)
            VStack(spacing: 0) {
                DeckUpNextProgressLine(fraction: info.fraction, ads: info.ads, duration: info.duration)
                DeckUpNextTimesRow(info: info)
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
            controls
                .padding(.top, 10)
                .padding(.bottom, 14)
        }
    }

    /// The artwork on a wash of the show's colour; tap for the player.
    private var artworkBlock: some View {
        Button(action: actions.open) {
            GeometryReader { geometry in
                let side: CGFloat = max(40, min(geometry.size.height - 28, geometry.size.width - 28))
                ZStack {
                    LinearGradient(colors: [info.colour, info.dark], startPoint: .topLeading, endPoint: .bottomTrailing)
                    if words.showing {
                        DeckTopWordsView(words: words)
                    } else {
                        DeckUpNextArtwork(episode: info.episode, size: side, radius: 16)
                            .shadow(color: Color.black.opacity(0.25), radius: 10, y: 6)
                    }
                }
            }
            .frame(minHeight: 110, maxHeight: 214)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .saturation(calm ? 0.45 : 1)
            .brightness(calm ? -0.06 : 0)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open the player")
        .overlay(alignment: .bottomTrailing) {
            DeckTopWordsSwitch(showing: words.showing, action: actions.toggleWords)
                .padding(10)
        }
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(info.showLine)
                .font(Theme.outfit(13, .semibold))
                .foregroundStyle(calm ? Theme.muted : info.colour)
                .lineLimit(1)
            Text(info.episode.title)
                .font(Theme.outfit(26, calm ? .semibold : .heavy))
                .tracking(-0.7)
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var controls: some View {
        if calm {
            ZStack {
                DeckUpNextPlayKey(isPlaying: info.isPlaying, fill: Theme.muted, action: actions.play)
                DeckUpNextSleepPill(action: actions.options)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 22)
            }
        } else {
            DeckUpNextTransport(info: info, actions: actions)
        }
    }
}

/// "Sleep", "15m" or "End": opens the speed and sound options.
struct DeckUpNextSleepPill: View {
    @Environment(PlayerModel.self) private var player
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "moon").font(.system(size: 14, weight: .semibold))
                Text(label).monospacedDigit()
            }
            .font(Theme.outfit(14, .bold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(Capsule().fill(Theme.background))
            .overlay(Capsule().strokeBorder(Theme.cardEdge, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sleep timer: " + label)
    }

    private var label: String {
        if player.sleepTimer == .endOfEpisode { return "End" }
        if let ends = player.sleepEndsAt {
            let minutes: Int = max(1, Int((ends.timeIntervalSinceNow / 60).rounded(.up)))
            return "\(minutes)m"
        }
        return "Sleep"
    }
}

/// The small artwork + show + title row at the top of Big and Read along.
private struct DeckTopHeaderRow: View {
    let info: DeckTopInfo
    let titleSize: CGFloat
    let open: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: open) {
                DeckUpNextArtwork(episode: info.episode, size: 52, radius: 13)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open the player")
            VStack(alignment: .leading, spacing: 1) {
                Text(info.showLine)
                    .font(Theme.outfit(12, .semibold))
                    .foregroundStyle(info.colour)
                    .lineLimit(1)
                Text(info.episode.title)
                    .font(Theme.outfit(titleSize, .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Big buttons: walking, running, cleaning.
struct DeckBigTop: View {
    @Environment(PlayerModel.self) private var player
    let info: DeckTopInfo
    let actions: DeckTopActions

    var body: some View {
        VStack(spacing: 12) {
            DeckTopHeaderRow(info: info, titleSize: 18, open: actions.open)
                .padding(.horizontal, 4)
            bigPlay
            HStack(spacing: 10) {
                skipTile(back: true)
                skipTile(back: false)
            }
            DeckUpNextProgressLine(fraction: info.fraction, ads: info.ads, duration: info.duration)
                .padding(.horizontal, 4)
                .padding(.top, 4)
        }
        .padding(18)
    }

    private var bigPlay: some View {
        Button(action: actions.play) {
            VStack(spacing: 10) {
                Image(systemName: info.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 64))
                Text(info.leftWords)
                    .font(Theme.outfit(15, .semibold))
                    .opacity(0.75)
            }
            .foregroundStyle(Theme.background)
            .frame(maxWidth: .infinity, maxHeight: 200)
            .frame(minHeight: 120)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Theme.ink))
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel((info.isPlaying ? "Pause, " : "Play, ") + info.leftWords)
    }

    private func skipTile(back: Bool) -> some View {
        let seconds: Int = back ? player.skipBackSeconds : player.skipForwardSeconds
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return Button {
            if back { player.skipBackward() } else { player.skipForwardBy() }
        } label: {
            HStack(spacing: 8) {
                if back { Image(systemName: "gobackward").font(.system(size: 26)) }
                Text("\(seconds)s").font(Theme.outfit(18, .heavy))
                if !back { Image(systemName: "goforward").font(.system(size: 26)) }
            }
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .background(shape.fill(Theme.background))
            .overlay(shape.strokeBorder(Theme.cardEdge, lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(!info.isCurrent)
        .accessibilityLabel((back ? "Back " : "Forward ") + "\(seconds) seconds")
    }
}

/// Read along: the line being said takes the card.
struct DeckReadTop: View {
    let info: DeckTopInfo
    let actions: DeckTopActions
    let line: TranscriptLayout.Line?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DeckTopHeaderRow(info: info, titleSize: 16, open: actions.open)
                .padding(.horizontal, 22)
                .padding(.top, 22)
            words
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            VStack(spacing: 0) {
                DeckUpNextProgressLine(fraction: info.fraction, ads: info.ads, duration: info.duration)
                DeckUpNextTimesRow(info: info)
            }
            .padding(.horizontal, 22)
            DeckUpNextTransport(info: info, actions: actions)
                .padding(.top, 10)
                .padding(.bottom, 14)
        }
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let speaker = line?.speaker, !speaker.isEmpty {
                Text(speaker)
                    .font(Theme.outfit(13, .bold))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Text(line?.text ?? "")
                .font(Theme.outfit(27, .bold))
                .tracking(-0.4)
                .foregroundStyle(Theme.ink)
                .lineLimit(6)
                .minimumScaleFactor(0.6)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: line?.start)
        }
    }
}

/// The words being said, white on the show's colour, in the top card's
/// picture area.
struct DeckTopWordsView: View {
    let words: DeckTopWords

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let speaker = words.line?.speaker, !speaker.isEmpty {
                Text(speaker)
                    .font(Theme.outfit(12, .bold))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .lineLimit(1)
            }
            Text(text)
                .font(Theme.outfit(words.ready ? 21 : 16, words.ready ? .bold : .semibold))
                .foregroundStyle(Color.white.opacity(words.ready ? 1 : 0.8))
                .lineLimit(5)
                .minimumScaleFactor(0.6)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: words.line?.start)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.leading, 18)
        .padding(.trailing, 56)
        .padding(.vertical, 16)
    }

    private var text: String {
        guard words.ready else { return "No words for this episode yet. Open the player to transcribe it." }
        return words.line?.text ?? ""
    }
}

/// The round key in the picture area's corner: the transcript icon while
/// the artwork shows, the picture icon while the words show.
struct DeckTopWordsSwitch: View {
    let showing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: showing ? "photo" : "quote.bubble")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.black.opacity(0.35)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showing ? "Show the artwork" : "Show the transcript")
    }
}
