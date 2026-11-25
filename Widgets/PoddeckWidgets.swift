import AppIntents
import SwiftUI
import UIKit
import WidgetKit

/// Poddeck's widgets: Up Next on the Home Screen (small / medium / large)
/// and Lock Screen, and a play/pause button for Control Centre, the Lock
/// Screen or the Action button. They read what the app last saved
/// (`WidgetSnapshot`); the keys run inside the app.
@main
struct PoddeckWidgets: WidgetBundle {
    var body: some Widget {
        UpNextWidget()
        PlayPauseControl()
    }
}

// MARK: - Deck colours and type (same values as App/Theme.swift)

/// The Deck look: warm page, white cards, ink text, coral as the one
/// accent. `night` is Deck night, used when the iPhone is dark.
private struct DeckPalette {
    let page: Color
    let card: Color
    let ink: Color
    let muted: Color
    let hairline: Color
    let track: Color
    /// Text / glyph on an ink fill (the play key).
    let onInk: Color

    static let coral = Color(red: 0xEC / 255, green: 0x65 / 255, blue: 0x50 / 255)

    static let day = DeckPalette(
        page: DeckPalette.hex(0xEEEBE5), card: DeckPalette.hex(0xFFFFFF),
        ink: DeckPalette.hex(0x1C1B1A), muted: DeckPalette.hex(0x6B6862),
        hairline: DeckPalette.hex(0xE5E1D9), track: DeckPalette.hex(0xE5E1D9),
        onInk: DeckPalette.hex(0xFFFFFF))

    static let night = DeckPalette(
        page: DeckPalette.hex(0x141312), card: DeckPalette.hex(0x211F1D),
        ink: DeckPalette.hex(0xF2EFEA), muted: DeckPalette.hex(0xA29E96),
        hairline: DeckPalette.hex(0x37342F), track: DeckPalette.hex(0x37342F),
        onInk: DeckPalette.hex(0x141312))

    static func of(_ scheme: ColorScheme) -> DeckPalette {
        scheme == .dark ? DeckPalette.night : DeckPalette.day
    }

    static func hex(_ value: UInt32) -> Color {
        let r: Double = Double((value >> 16) & 0xFF) / 255
        let g: Double = Double((value >> 8) & 0xFF) / 255
        let b: Double = Double(value & 0xFF) / 255
        return Color(red: r, green: g, blue: b)
    }
}

private enum DeckType {
    /// Outfit (bundled with the widgets, listed in Widgets-Info.plist).
    /// Font.custom falls back to SF if the font isn't there.
    static func outfit(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        let name: String
        switch weight {
        case .heavy, .black: name = "Outfit-ExtraBold"
        case .bold: name = "Outfit-Bold"
        case .medium, .regular, .light, .thin, .ultraLight: name = "Outfit-Medium"
        default: name = "Outfit-SemiBold"
        }
        return Font.custom(name, fixedSize: size)
    }
}

// MARK: - Timeline

struct DeckEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct DeckProvider: TimelineProvider {
    func placeholder(in context: Context) -> DeckEntry {
        DeckEntry(date: .now, snapshot: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (DeckEntry) -> Void) {
        let saved = WidgetSnapshot.load()
        completion(DeckEntry(date: .now, snapshot: context.isPreview && saved == nil ? Self.sample : saved ?? WidgetSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DeckEntry>) -> Void) {
        // The app asks for a refresh whenever something changes.
        let entry = DeckEntry(date: .now, snapshot: WidgetSnapshot.load() ?? WidgetSnapshot())
        completion(Timeline(entries: [entry], policy: .never))
    }

    static let sample = WidgetSnapshot(
        nowPlaying: .init(id: "a", title: "The long way round", show: "Tidewater Weekly", artworkFile: nil, remaining: 1860, progress: 0.4),
        isPlaying: false,
        upNext: [
            .init(id: "b", title: "Letters from the coast", show: "Harbour Lights", artworkFile: nil, remaining: 2700, progress: 0),
            .init(id: "c", title: "Ask us anything", show: "Two Kettles", artworkFile: nil, remaining: 3300, progress: 0),
        ])
}

// MARK: - Up Next widget

struct UpNextWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSnapshot.widgetKind, provider: DeckProvider()) { entry in
            UpNextWidgetView(entry: entry)
        }
        .configurationDisplayName("Up Next")
        .description("What's playing and what's next, with a play key.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct UpNextWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: DeckEntry

    private var snapshot: WidgetSnapshot { entry.snapshot }
    private var palette: DeckPalette { DeckPalette.of(colorScheme) }
    /// What the play key would play: what's playing, or the top of Up Next.
    private var lead: WidgetSnapshot.Item? { snapshot.nowPlaying ?? snapshot.upNext.first }
    private var rest: [WidgetSnapshot.Item] {
        snapshot.nowPlaying == nil ? Array(snapshot.upNext.dropFirst()) : snapshot.upNext
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(lead.map { "\(snapshot.isPlaying ? "▶︎" : "❚❚") \($0.show)" } ?? "Up Next is empty")
                .containerBackground(.clear, for: .widget)
        case .accessoryCircular:
            Button(intent: WidgetPlayPauseIntent()) {
                ZStack {
                    AccessoryWidgetBackground()
                    Gauge(value: lead?.progress ?? 0) { EmptyView() }
                        .gaugeStyle(.accessoryCircularCapacity)
                    Image(systemName: snapshot.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .bold))
                }
            }
            .buttonStyle(.plain)
            .containerBackground(.clear, for: .widget)
        case .accessoryRectangular:
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(snapshot.isPlaying ? "PLAYING" : "UP NEXT").font(DeckType.outfit(10, .bold))
                    Text(lead?.title ?? "Nothing queued").font(DeckType.outfit(14, .semibold)).lineLimit(2)
                    if let lead { Text(lead.show).font(DeckType.outfit(11, .medium)).lineLimit(1).opacity(0.7) }
                }
                Spacer(minLength: 0)
                if lead != nil {
                    Button(intent: WidgetPlayPauseIntent()) {
                        Image(systemName: snapshot.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 16, weight: .bold))
                    }
                    .buttonStyle(.plain)
                }
            }
            .containerBackground(.clear, for: .widget)
        default:
            home.containerBackground(palette.page, for: .widget)
        }
    }

    // MARK: Home Screen

    private var listLength: Int {
        switch family {
        case .systemLarge: return 4
        case .systemMedium: return 1
        default: return 0
        }
    }

    @ViewBuilder
    private var home: some View {
        if let lead {
            VStack(alignment: .leading, spacing: 8) {
                display(lead)
                if family != .systemSmall { keys }
                ForEach(rest.prefix(listLength)) { item in
                    row(item)
                }
                if family == .systemLarge { Spacer(minLength: 0) }
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "square.stack").font(.system(size: 22, weight: .semibold)).foregroundStyle(palette.muted)
                Text("Up next is empty").font(DeckType.outfit(14, .bold)).foregroundStyle(palette.ink)
                Text("Open Poddeck to add episodes").font(DeckType.outfit(11, .medium)).foregroundStyle(palette.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var statusText: String {
        if snapshot.isPlaying { return "PLAYING" }
        return snapshot.nowPlaying == nil ? "UP NEXT" : "PAUSED"
    }

    private func statusLabel() -> some View {
        HStack(spacing: 4) {
            if snapshot.isPlaying {
                Circle().fill(DeckPalette.coral).frame(width: 5, height: 5)
            }
            Text(statusText)
                .font(DeckType.outfit(9, .bold))
                .foregroundStyle(snapshot.isPlaying ? DeckPalette.coral : palette.muted)
        }
    }

    /// What's playing (or the top of Up Next): artwork, status, show,
    /// title, a thin progress line and time left. A white card on the
    /// medium and large widgets; on the small one it sits on the page
    /// with the play key inside.
    @ViewBuilder
    private func display(_ item: WidgetSnapshot.Item) -> some View {
        let small: Bool = family == .systemSmall
        let content = displayContent(item, small: small)
        if small {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            content
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: family == .systemLarge ? 128 : .infinity, alignment: .topLeading)
                .background(palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func displayContent(_ item: WidgetSnapshot.Item, small: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                artwork(item, size: small ? 44 : 46)
                VStack(alignment: .leading, spacing: 2) {
                    statusLabel()
                    Text(item.show.uppercased())
                        .font(DeckType.outfit(9, .bold))
                        .foregroundStyle(palette.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            Text(item.title)
                .font(DeckType.outfit(small ? 13 : 14, .semibold))
                .foregroundStyle(palette.ink)
                .lineLimit(2)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                progressLine(item.progress)
                if let remaining = item.remaining {
                    Text(Self.left(remaining))
                        .font(DeckType.outfit(10, .semibold))
                        .monospacedDigit()
                        .foregroundStyle(palette.muted)
                        .fixedSize()
                }
                if small {
                    Button(intent: WidgetPlayPauseIntent()) { playKey(size: 30) }.buttonStyle(.plain)
                }
            }
        }
    }

    private var keys: some View {
        HStack(spacing: 22) {
            Button(intent: WidgetSkipBackIntent()) { key("gobackward") }.buttonStyle(.plain)
            Button(intent: WidgetPlayPauseIntent()) { playKey(size: 30) }.buttonStyle(.plain)
            Button(intent: WidgetSkipForwardIntent()) { key("goforward") }.buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ item: WidgetSnapshot.Item) -> some View {
        HStack(spacing: 8) {
            artwork(item, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(DeckType.outfit(12, .semibold))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                Text(item.show.uppercased())
                    .font(DeckType.outfit(9, .bold))
                    .foregroundStyle(palette.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let remaining = item.remaining {
                Text(Self.left(remaining))
                    .font(DeckType.outfit(10, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(palette.muted)
                    .fixedSize()
            }
        }
    }

    /// Skip keys: plain ink symbols, no chrome.
    private func key(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(palette.ink)
            .frame(width: 40, height: 30)
            .contentShape(Rectangle())
    }

    /// Round ink play key (light glyph); in Deck night the ink is light,
    /// so the glyph turns dark.
    private func playKey(size: CGFloat) -> some View {
        Image(systemName: snapshot.isPlaying ? "pause.fill" : "play.fill")
            .font(.system(size: size * 0.4, weight: .bold))
            .foregroundStyle(palette.onInk)
            .frame(width: size, height: size)
            .background(Circle().fill(palette.ink))
    }

    /// Thin ink line on a faint track.
    private func progressLine(_ value: Double) -> some View {
        let clamped: Double = max(0, min(1, value))
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.track)
                Capsule().fill(palette.ink).frame(width: CGFloat(clamped) * proxy.size.width)
            }
        }
        .frame(height: 3)
    }

    private func artwork(_ item: WidgetSnapshot.Item, size: CGFloat) -> some View {
        let corner: CGFloat = size * 0.22
        return Group {
            if let url = WidgetSnapshot.artworkURL(item.artworkFile), let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                palette.track.overlay(
                    Text(String(item.show.prefix(1)).uppercased())
                        .font(DeckType.outfit(size * 0.42, .heavy))
                        .foregroundStyle(palette.muted))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    static func left(_ seconds: Double) -> String {
        let minutes = Int((seconds / 60).rounded(.up))
        return minutes >= 60 ? "\(minutes / 60)h \(String(format: "%02d", minutes % 60))m" : "\(minutes)m"
    }
}

// MARK: - Control Centre / Lock Screen / Action button

struct PlayPauseControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.gruffaluff.podcasts.playpause") {
            ControlWidgetButton(action: WidgetPlayPauseIntent()) {
                Label(WidgetSnapshot.load()?.isPlaying == true ? "Pause Poddeck" : "Play Poddeck",
                      systemImage: WidgetSnapshot.load()?.isPlaying == true ? "pause.fill" : "play.fill")
            }
        }
        .displayName("Poddeck Play/Pause")
        .description("Plays or pauses Poddeck (starts Up Next if nothing is playing).")
    }
}
