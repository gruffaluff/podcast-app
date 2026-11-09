import SwiftUI

/// A rounded key: paper (plain), ink (dark) or olive (accent, "on").
/// Presses in slightly when tapped.
struct KeyButtonStyle: ButtonStyle {
    enum Kind { case plain, dark, accent, sand }
    var kind: Kind = .plain
    var radius: CGFloat = 14
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let (fill, text): (Color, Color) = {
            switch kind {
            case .plain: return (Theme.surface, Theme.ink)
            case .dark: return (Theme.ink, Theme.surface)
            case .accent: return (Theme.accentFill, Theme.onAccent)
            case .sand: return (Theme.background, Theme.ink)
            }
        }()
        let pressed = configuration.isPressed
        return configuration.label
            .foregroundStyle(text)
            .background(RoundedRectangle(cornerRadius: radius).fill(fill))
            .scaleEffect(pressed ? 0.97 : 1)
            .opacity(isEnabled ? (pressed ? 0.85 : 1) : 0.4)
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

extension ButtonStyle where Self == KeyButtonStyle {
    static var key: KeyButtonStyle { KeyButtonStyle() }
    static var accentKey: KeyButtonStyle { KeyButtonStyle(kind: .accent) }
}

/// The dark display panel (like a deck's readout).
struct DeckDisplay<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .font(Theme.mono(13))
            .foregroundStyle(Theme.displayText)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint ?? Theme.display, in: RoundedRectangle(cornerRadius: 22))
    }

    @Environment(\.heroTint) private var tint
}

private struct HeroTintKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

extension EnvironmentValues {
    /// The colour of the episode playing (from its artwork), for coloured
    /// panels; nil uses the default olive.
    var heroTint: Color? {
        get { self[HeroTintKey.self] }
        set { self[HeroTintKey.self] = newValue }
    }
}

/// Progress as a row of bars of varying height (a sound wave), played ones
/// lit, ad breaks in amber. `played` / `track` default to the colours for a
/// coloured panel.
struct SegmentBar: View {
    /// 0...1
    let progress: Double
    /// Ad breaks as fractions of the episode.
    var ads: [ClosedRange<Double>] = []
    var count = 28
    var height: CGFloat = 12
    var played: Color = Theme.displayText
    var track: Color = Theme.displayTrack
    /// The episode's real loudness per bar (0...1), when known; otherwise
    /// a fixed pattern.
    var levels: [CGFloat]? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<count, id: \.self) { index in
                let start = Double(index) / Double(count)
                let end = Double(index + 1) / Double(count)
                let isAd = ads.contains { $0.lowerBound < end && $0.upperBound > start }
                let isPlayed = (start + end) / 2 <= progress
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isAd ? Theme.adMarker : (isPlayed ? played : track))
                    .frame(height: height < 10 ? height : height * barHeight(index))
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }

    private func barHeight(_ index: Int) -> CGFloat {
        if let levels, index < levels.count { return levels[index] }
        return Self.wave(index)
    }

    /// A fixed, natural-looking pattern of bar heights (0.35...1).
    static func wave(_ index: Int) -> CGFloat {
        let pattern: [CGFloat] = [0.45, 0.7, 0.95, 0.6, 1, 0.8, 0.5, 0.9, 0.65, 0.95, 0.75, 0.55, 0.85, 0.4, 0.7, 0.95, 0.6, 0.8, 0.45, 0.9]
        return pattern[index % pattern.count]
    }
}

/// A small status light.
struct LED: View {
    let on: Bool
    var color: Color = Theme.ink

    var body: some View {
        Circle()
            .fill(on ? color : Theme.controlBorder)
            .frame(width: 7, height: 7)
    }
}

/// A boxed monospaced tag, e.g. "TOP1", "BTM", "YOU".
struct DeckTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.mono(10, .bold))
            .foregroundStyle(Theme.accentText)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .overlay(Capsule().stroke(Theme.accentText, lineWidth: 1.5))
    }
}

/// A section heading: monospaced title, with an optional detail on the right.
struct DeckHeader: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(Theme.mono(11, .bold))
                .tracking(1.4)
                .foregroundStyle(Theme.muted)
            Spacer(minLength: 8)
            if let detail {
                Text(detail.uppercased())
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.muted)
            }
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A row of keys where one is pressed in: the deck's version of a
/// segmented control (e.g. OFF / TOP / BOTTOM).
struct DeckSwitch<Value: Hashable>: View {
    let options: [(label: String, value: Value)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let selected = option.value == selection
                Button { selection = option.value } label: {
                    Text(option.label.uppercased())
                        .font(Theme.mono(12, .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .foregroundStyle(selected ? Theme.onAccent : Theme.ink)
                        .background(selected ? Theme.accentFill : .clear, in: RoundedRectangle(cornerRadius: 11))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.label)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 15))
    }
}

/// "Choose from a list" (style rules, Paul 9 Nov 2026): a sand key showing
/// the choice with ▾, opening the list. Replaces iOS's olive drop-down text.
struct DeckPicker<Value: Hashable>: View {
    let title: String
    let options: [(label: String, value: Value)]
    @Binding var selection: Value

    private var current: String {
        options.first { $0.value == selection }?.label ?? ""
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            Menu {
                Picker(title, selection: $selection) {
                    ForEach(options.indices, id: \.self) { index in
                        Text(options[index].label).tag(options[index].value)
                    }
                }
            } label: {
                Text(current.uppercased() + " ▾")
                    .font(Theme.mono(11, .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 32)
                    .background(Theme.background, in: RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel("\(title): \(current)")
        }
    }
}

/// "Do something" in a settings row: the row's title, then a key. Dark for
/// the main action, sand for others (style rules, Paul 9 Nov 2026).
struct DeckActionRow: View {
    let title: String
    let key: String
    var main = false
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            Button(action: action) {
                Text(key.uppercased())
                    .font(Theme.mono(11, .bold))
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 32)
            }
            .buttonStyle(KeyButtonStyle(kind: main ? .dark : .sand, radius: 10))
        }
    }
}

/// Two labelled lights for an episode: DL (downloaded; shows % while
/// downloading) and TX (transcript ready; blinks while transcribing).
struct EpisodeLights: View {
    @Environment(DownloadManager.self) private var downloads
    let episode: PodcastEpisode
    /// On the dark display panel.
    var onDark = false

    var body: some View {
        let progress = downloads.progress[episode.episodeID]
        HStack(spacing: 8) {
            light(progress.map { $0 > 0 ? "DL \(Int($0 * 100))%" : "DL …" } ?? "DL",
                  state: episode.downloadFile != nil ? .on : (progress != nil ? .busy : .off),
                  color: onDark ? Theme.displayText : Theme.ink)
            light(episode.transcriptState == .transcribing ? "TX …" : (episode.transcriptState == .waiting ? "TX WAIT" : "TX"),
                  state: episode.transcriptState == .ready ? .on : (episode.transcriptState == .transcribing || episode.transcriptState == .waiting ? .busy : .off),
                  color: onDark ? Theme.adMarker : Theme.accentFill)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label(progress: progress))
    }

    private enum LightState { case on, busy, off }

    private func light(_ text: String, state: LightState, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(state == .off ? (onDark ? Theme.displayTrack : Theme.controlBorder) : color)
                .opacity(state == .busy ? 0.5 : 1)
                .frame(width: 7, height: 7)
            Text(text)
                .font(Theme.mono(9, .semibold))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(state == .off ? (onDark ? Theme.displayDim : Theme.muted) : (onDark ? Theme.displayText : Theme.ink))
        }
    }

    private func label(progress: Double?) -> String {
        let download = episode.downloadFile != nil ? "Downloaded" : (progress.map { "Downloading, \(Int($0 * 100)) percent" } ?? "Not downloaded")
        let transcript: String = switch episode.transcriptState {
        case .ready: "transcript ready"
        case .transcribing: "transcribing"
        case .waiting: "transcript waiting"
        default: "no transcript"
        }
        return "\(download), \(transcript)"
    }
}

extension View {
    /// A tab's big title on the same line as its bar buttons (no tall
    /// large-title gap above the content). The plain title stays for back
    /// buttons on screens pushed from here.
    func tabTitle(_ title: String) -> some View {
        self.navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1) }
                ToolbarItem(placement: .topBarLeading) {
                    Text(title)
                        .font(Theme.big(30))
                        .foregroundStyle(Theme.ink)
                        .fixedSize()
                        .accessibilityAddTraits(.isHeader)
                }
                .sharedBackgroundVisibility(.hidden)
            }
    }
}

// MARK: - Panel rows (Paul, 6 Nov 2026: one row style everywhere, "B")

/// Where a row sits in its rounded paper panel.
enum PanelPosition {
    case only, first, middle, last

    init(index: Int, count: Int) {
        if count <= 1 { self = .only }
        else if index == 0 { self = .first }
        else if index >= count - 1 { self = .last }
        else { self = .middle }
    }

    var roundsTop: Bool { self == .only || self == .first }
    var roundsBottom: Bool { self == .only || self == .last }
}

/// One slice of a rounded paper panel, with a thin line under every row
/// but the last. Drawn by the row itself (not the system separators, which
/// run past the panel's edge in plain lists).
struct PanelBackground: View {
    let position: PanelPosition
    var fill: Color = Theme.surface

    var body: some View {
        let top: CGFloat = position.roundsTop ? 14 : 0
        let bottom: CGFloat = position.roundsBottom ? 14 : 0
        UnevenRoundedRectangle(topLeadingRadius: top, bottomLeadingRadius: bottom,
                               bottomTrailingRadius: bottom, topTrailingRadius: top)
            .fill(fill)
            .overlay(alignment: .bottom) {
                if !position.roundsBottom {
                    Rectangle().fill(Theme.hairline).frame(height: 0.5).padding(.leading, 16)
                }
            }
            // Same margins as iOS's inset grouped lists (Up Next, Shows,
            // pulled-up lists), so every panel lines up.
            .padding(.horizontal, 16)
    }
}

extension View {
    /// Puts a list row in a rounded paper panel, like the pulled-up Up Next
    /// and Chapters lists: the same look for every list in the app.
    func panelRow(_ index: Int, of count: Int) -> some View {
        self
            .listRowBackground(PanelBackground(position: PanelPosition(index: index, count: count),
                                               fill: Theme.surface))
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: 32, bottom: 8, trailing: 32))
    }
}
