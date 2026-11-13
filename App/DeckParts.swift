import SwiftUI
import PodcastCore

// Deck 0 (Paul, 11 Nov 2026; mock-ups https://claude.ai/artifact/4o3aSsUdjsA7xxsXYXdVAP
// and https://claude.ai/artifact/7Pz2BXFcpRBv9JMsz2m1TA). Everything you
// press sits in the bottom half, on a deck: a small green display for
// what's playing (the only dark, "live" thing), chunky keys only for skip /
// play / skip, a quiet strip with a light each for Speed / Trim / Boost /
// Sleep, and the tabs as words. Rows are paper boxes with a band in the
// show's colour; the episode playing is a dark card wherever it shows.

enum Deck0 {
    /// The display: near-black glass with pale green figures.
    static let lcd = Color(hex: 0x262622)
    static let lcdText = Color(hex: 0xD9E6B8)
    static let lcdBright = Color(hex: 0xEFF6D8)
    static var lcdDim: Color { lcdText.opacity(0.45) }
    static let lcdAd = Color(hex: 0xE0A43A)
    /// The one red key (play) and the lights on the tools strip.
    static let red = Color(hex: 0xC2462F)
    static let redEdge = Color(hex: 0x8E2F1E)
    static let led = Color(hex: 0xE2553A)
}

/// The green display panel.
struct LCDPanel<Content: View>: View {
    var vertical: CGFloat = 9
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) { content }
            .font(Theme.mono(10.5))
            .foregroundStyle(Deck0.lcdText)
            .padding(.horizontal, 12)
            .padding(.vertical, vertical)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Deck0.lcd.shadow(.inner(color: .black.opacity(0.7), radius: 3, y: 1.5)))
            }
    }
}

/// Progress on the display: small blocks like a deck's level meter, a gap
/// where each chapter starts, ad breaks amber.
struct LCDProgress: View {
    let progress: Double
    var chapterStarts: [Double] = []
    var ads: [ClosedRange<Double>] = []

    var body: some View {
        Canvas { graphics, size in
            Self.draw(in: graphics, size: size, progress: progress, chapterStarts: chapterStarts, ads: ads)
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }

    private static func draw(in graphics: GraphicsContext, size: CGSize, progress: Double, chapterStarts: [Double], ads: [ClosedRange<Double>]) {
        let gap: CGFloat = 2
        let count: Int = max(1, Int((size.width + gap) / 7))
        let step: CGFloat = size.width / CGFloat(count)
        let cuts: [Double] = chapterStarts.filter { $0 > 0.01 && $0 < 0.99 }
        for index in 0..<count {
            let low: Double = Double(index) / Double(count)
            let high: Double = Double(index + 1) / Double(count)
            // One block left out where a chapter starts.
            if index > 0, cuts.contains(where: { $0 >= low && $0 < high }) { continue }
            let middle: Double = (low + high) / 2
            let played: Bool = middle <= progress
            let isAd: Bool = ads.contains { $0.contains(middle) }
            let colour: Color = isAd ? Deck0.lcdAd.opacity(played ? 1 : 0.45) : (played ? Deck0.lcdText : Deck0.lcdText.opacity(0.18))
            let rect = CGRect(x: CGFloat(index) * step, y: 0, width: step - gap, height: size.height)
            graphics.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(colour))
        }
    }
}

/// The face of a chunky deck key: paper (or red) on a darker edge, so it
/// looks like it stands up off the plate.
struct DeckKeyFace: View {
    var red = false
    var pressed = false
    var radius: CGFloat = 12

    var body: some View {
        let fill: Color = red ? Deck0.red : Theme.surface
        let edge: Color = red ? Deck0.redEdge : Theme.controlBorder
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(edge)
                .offset(y: pressed ? 0.5 : 2.5)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(fill)
                .offset(y: pressed ? 1.5 : 0)
        }
        .shadow(color: red ? Deck0.red.opacity(0.25) : Color.black.opacity(0.08), radius: 4, y: 3)
    }
}

/// A chunky key that presses in.
struct DeckKeyStyle: ButtonStyle {
    var red = false
    var radius: CGFloat = 12

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .foregroundStyle(red ? Color.white : Theme.ink)
            .offset(y: pressed ? 1.5 : 0)
            .background { DeckKeyFace(red: red, pressed: pressed, radius: radius) }
            .animation(.easeOut(duration: 0.06), value: pressed)
    }
}

/// Skip back, play / pause (red, wider), skip forward: the only chunky keys.
/// The skips keep touch-and-hold to change how far they go.
struct DeckTransport: View {
    @Environment(PlayerModel.self) private var player
    var height: CGFloat = 44

    var body: some View {
        HStack(spacing: 10) {
            SkipButton(direction: .back, iconSize: 17, frame: height)
                .frame(maxWidth: .infinity)
                .foregroundStyle(Theme.ink)
                .background { DeckKeyFace() }
            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: height + 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(DeckKeyStyle(red: true, radius: 14))
            .frame(maxWidth: .infinity)
            .layoutPriority(1)
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
            SkipButton(direction: .forward, iconSize: 17, frame: height)
                .frame(maxWidth: .infinity)
                .foregroundStyle(Theme.ink)
                .background { DeckKeyFace() }
        }
        .tint(Theme.ink)
    }
}

/// One cell of the tools strip: the setting's value over a small light and
/// its name. Wrapped in a Button or Menu by whoever uses it.
struct ToolCell: View {
    let value: String
    let label: String
    let on: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.mono(11.5, .bold))
                .monospacedDigit()
                .foregroundStyle(on ? Deck0.red : Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(spacing: 4) {
                Circle()
                    .fill(on ? Deck0.led : Theme.controlBorder)
                    .frame(width: 5, height: 5)
                    .shadow(color: on ? Deck0.led : .clear, radius: 3)
                Text(label)
                    .font(Theme.mono(8.5))
                    .tracking(0.6)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(Rectangle())
    }
}

/// A row of tool cells with thin lines between them, on a quiet panel.
struct ToolsStrip<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 0) {
            Group(subviews: content) { cells in
                ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                    if index > 0 {
                        Rectangle().fill(Theme.ink.opacity(0.08)).frame(width: 1, height: 26)
                    }
                    cell
                }
            }
        }
        .padding(.vertical, 2)
        .background(Theme.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// The tabs as words, the one you're on underlined in red.
struct DeckTabs: View {
    @Binding var tab: Int
    static let titles = ["Listen", "Library", "Discover", "Search"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Self.titles.indices, id: \.self) { index in
                let selected = tab == index
                Button { tab = index } label: {
                    VStack(spacing: 4) {
                        Text(Self.titles[index].uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(selected ? Theme.ink : Theme.muted)
                        Capsule()
                            .fill(selected ? Deck0.red : .clear)
                            .frame(width: 26, height: 2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Self.titles[index])
                .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
            }
        }
    }
}

/// Little bars that move while the episode plays (on its dark card).
/// Driven by the clock (each bar a slow, gentle wave of its own) rather
/// than a repeating animation, so redraws of the row (the progress line
/// ticks twice a second) can't restart or jolt them (Paul, 13 Nov 2026:
/// "a bit wild"). Still and level while paused.
struct PlayingBars: View {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let moving = active && !reduceMotion
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !moving)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 1.5) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(Deck0.led)
                        .frame(width: 2.5, height: moving ? Self.height(index, at: t) : 5)
                }
            }
        }
        .frame(height: 10, alignment: .bottom)
        .accessibilityHidden(true)
    }

    /// 4–9 pt, each bar on its own slow period (1.1–1.7 s) and offset.
    private static let periods: [Double] = [1.3, 1.7, 1.1]
    private static let offsets: [Double] = [0, 2.1, 4.0]
    private static func height(_ index: Int, at t: Double) -> CGFloat {
        let wave = sin(t * 2 * .pi / periods[index] + offsets[index])
        return 6.5 + 2.5 * CGFloat(wave)
    }
}

/// When each Up Next episode starts at the current speed, and when the
/// whole list is done. The first one (or the one playing) is "now".
enum UpNextTimes {
    static func starts(lengths: [TimeInterval], speed: Double, from now: Date = Date()) -> [Date] {
        var clock = now
        var result: [Date] = []
        for length in lengths {
            result.append(clock)
            clock = clock.addingTimeInterval(length / max(speed, 0.5))
        }
        return result
    }

    static func doneBy(lengths: [TimeInterval], speed: Double, from now: Date = Date()) -> Date {
        now.addingTimeInterval(lengths.reduce(0, +) / max(speed, 0.5))
    }

    /// "19:42".
    static func clock(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }
}

extension View {
    /// A row card for the episode that's playing: the scheme's dark
    /// "playing" colour, light text (Paul, 11 Nov 2026: the episode playing
    /// stands out the same way wherever it's shown).
    func playingCard() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(Theme.playingCard)
                    .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
            }
            .tint(Poster.paper)
    }
}
