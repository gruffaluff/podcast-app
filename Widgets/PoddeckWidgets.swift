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

// MARK: - Tape Deck colours (same values as App/Theme.swift)

private enum Deck {
    static let panel = Color(red: 0xE8 / 255, green: 0xE6 / 255, blue: 0xE1 / 255)
    static let ink = Color(red: 0x1B / 255, green: 0x1B / 255, blue: 0x1A / 255)
    static let muted = Color(red: 0x5F / 255, green: 0x5C / 255, blue: 0x55 / 255)
    static let accent = Color(red: 0xF0 / 255, green: 0x5A / 255, blue: 0x1A / 255)
    static let accentText = Color(red: 0xB0 / 255, green: 0x3A / 255, blue: 0x0A / 255)
    static let display = Color(red: 0x22 / 255, green: 0x23 / 255, blue: 0x1F / 255)
    static let displayText = Color(red: 0xE6 / 255, green: 0xED / 255, blue: 0xD7 / 255)
    static let displayDim = Color(red: 0x9D / 255, green: 0xA6 / 255, blue: 0x90 / 255)
    static let track = Color(red: 0x3A / 255, green: 0x3C / 255, blue: 0x35 / 255)

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
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
    let entry: DeckEntry

    private var snapshot: WidgetSnapshot { entry.snapshot }
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
                    Text(snapshot.isPlaying ? "PLAYING" : "UP NEXT").font(Deck.mono(10, .bold))
                    Text(lead?.title ?? "Nothing queued").font(.system(size: 13, weight: .semibold)).lineLimit(2)
                    if let lead { Text(lead.show).font(Deck.mono(10)).lineLimit(1).opacity(0.7) }
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
            home.containerBackground(Deck.panel, for: .widget)
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
                Image(systemName: "list.bullet").font(.system(size: 22, weight: .semibold)).foregroundStyle(Deck.muted)
                Text("UP NEXT IS EMPTY").font(Deck.mono(11, .bold)).foregroundStyle(Deck.ink)
                Text("Open Poddeck to add episodes").font(.system(size: 11)).foregroundStyle(Deck.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// The dark display panel: artwork, title, show, time left and a
    /// progress bar; on the small widget the play key sits inside it.
    private func display(_ item: WidgetSnapshot.Item) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                artwork(item, size: family == .systemSmall ? 40 : 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.isPlaying ? "● PLAYING" : (snapshot.nowPlaying == nil ? "UP NEXT" : "PAUSED"))
                        .font(Deck.mono(9, .bold))
                        .foregroundStyle(snapshot.isPlaying ? Deck.accent : Deck.displayDim)
                    Text(item.show.uppercased()).font(Deck.mono(9)).foregroundStyle(Deck.displayDim).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            Text(item.title)
                .font(.system(size: family == .systemSmall ? 12 : 13, weight: .semibold))
                .foregroundStyle(Deck.displayText)
                .lineLimit(2)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                progressBar(item.progress)
                if let remaining = item.remaining {
                    Text(Self.left(remaining)).font(Deck.mono(9)).foregroundStyle(Deck.displayDim).fixedSize()
                }
                if family == .systemSmall {
                    Button(intent: WidgetPlayPauseIntent()) { playKey(size: 26) }.buttonStyle(.plain)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: family == .systemLarge ? 128 : .infinity, alignment: .topLeading)
        .background(Deck.display, in: RoundedRectangle(cornerRadius: 10))
    }

    private var keys: some View {
        HStack(spacing: 8) {
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
                Text(item.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Deck.ink).lineLimit(1)
                Text(item.show.uppercased()).font(Deck.mono(9)).foregroundStyle(Deck.muted).lineLimit(1)
            }
            Spacer(minLength: 0)
            if let remaining = item.remaining {
                Text(Self.left(remaining)).font(Deck.mono(9)).foregroundStyle(Deck.muted).fixedSize()
            }
        }
    }

    private func key(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Deck.ink)
            .frame(width: 44, height: 30)
            .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Deck.muted.opacity(0.35), lineWidth: 1))
    }

    private func playKey(size: CGFloat) -> some View {
        Image(systemName: snapshot.isPlaying ? "pause.fill" : "play.fill")
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size * 1.6, height: size)
            .background(Deck.accent, in: RoundedRectangle(cornerRadius: 7))
    }

    private func progressBar(_ value: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Deck.track)
                Capsule().fill(Deck.accent).frame(width: max(0, min(1, value)) * proxy.size.width)
            }
        }
        .frame(height: 4)
    }

    private func artwork(_ item: WidgetSnapshot.Item, size: CGFloat) -> some View {
        Group {
            if let url = WidgetSnapshot.artworkURL(item.artworkFile), let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Deck.track.overlay(
                    Text(String(item.show.prefix(1)).uppercased())
                        .font(Deck.mono(size * 0.4, .bold))
                        .foregroundStyle(Deck.displayText))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    static func left(_ seconds: Double) -> String {
        let minutes = Int((seconds / 60).rounded(.up))
        return minutes >= 60 ? "\(minutes / 60)H\(String(format: "%02d", minutes % 60))" : "\(minutes)M"
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
