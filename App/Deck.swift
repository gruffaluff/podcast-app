import SwiftUI

/// A rounded key: paper (plain), ink (dark) or olive (accent, "on").
/// Presses in slightly when tapped.
struct KeyButtonStyle: ButtonStyle {
    enum Kind { case plain, dark, accent, sand }
    var kind: Kind = .plain
    var radius: CGFloat = 14
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.showColour) private var showColour

    func makeBody(configuration: Configuration) -> some View {
        let (fill, text): (Color, Color) = {
            switch kind {
            case .plain: return (Theme.surface, Theme.ink)
            case .dark: return (Theme.ink, Theme.surface)
            case .accent: return (Theme.showAccentFill(showColour), Theme.showOnAccent(showColour))
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

private struct ShowColourKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

extension EnvironmentValues {
    /// Set on a screen about one show: its artwork colour, used by the
    /// "on" keys there instead of the colour of what's playing.
    var showColour: Color? {
        get { self[ShowColourKey.self] }
        set { self[ShowColourKey.self] = newValue }
    }
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
    @Environment(\.showColour) private var showColour

    var body: some View {
        Text(text)
            .font(Theme.mono(10, .bold))
            .foregroundStyle(Theme.showAccentText(showColour))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .overlay(Capsule().stroke(Theme.showAccentText(showColour), lineWidth: 1.5))
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
    @Environment(\.showColour) private var showColour

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
                        .foregroundStyle(selected ? Theme.showOnAccent(showColour) : Theme.ink)
                        .background(selected ? Theme.showAccentFill(showColour) : .clear, in: RoundedRectangle(cornerRadius: 11))
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
    @Environment(TranscriptService.self) private var transcripts
    let episode: PodcastEpisode
    /// On the dark display panel.
    var onDark = false

    var body: some View {
        let progress: Double? = downloads.progress[episode.episodeID]
        let txState: TranscriptState = episode.transcriptState
        let txBusy: Bool = txState == .transcribing || txState == .waiting
        HStack(spacing: 6) {
            light("DL", done: episode.downloadFile != nil, fill: progress.map { max(0.05, $0) })
            light("TX", done: txState == .ready,
                  fill: txBusy ? max(0.05, transcripts.progress[episode.episodeID] ?? 0) : nil)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label(progress: progress))
    }

    /// Just the small letters (Paul, 12 Nov 2026, option 4): faded when not
    /// done, dark when done, and while it's on its way the letters darken
    /// from left to right as it goes. Nothing changes width, so the row
    /// never moves.
    private func light(_ text: String, done: Bool, fill: Double?) -> some View {
        let ink: Color = onDark ? Poster.paper : Theme.ink
        return Text(text)
            .foregroundStyle(ink)
            .opacity(done ? 0.85 : 0.22)
            .overlay {
                if let fill, !done {
                    Text(text)
                        .foregroundStyle(ink)
                        .opacity(0.85)
                        .mask(alignment: .leading) {
                            GeometryReader { geometry in
                                Rectangle().frame(width: geometry.size.width * fill)
                            }
                        }
                        .animation(.easeOut(duration: 0.3), value: fill)
                }
            }
            .font(Theme.mono(8.5, .semibold))
            .tracking(0.6)
            .lineLimit(1)
            .fixedSize()
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
        // iOS's large title, but on the same line as the bar's buttons
        // (Paul, build 145: "Up Next level with the buttons at the top"),
        // so every tab's content starts higher.
        self.navigationTitle(title)
            .toolbarTitleDisplayMode(.inlineLarge)
    }
}

// MARK: - List rows (one row style everywhere)

extension View {
    /// The app's one card look (Paul picked B, 9 Nov 2026): a rounded
    /// paper card sitting slightly off the sand on a soft shadow. Every
    /// list row and every card-like panel uses it.
    func deckCard(_ fill: Color = Theme.surface, radius: CGFloat = Theme.cardRadius) -> some View {
        background {
            // Native warm: flat, like an iOS inset list (no shadows).
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(fill)
        }
    }

    /// The list-row settings around a card: sand behind it (so a row lifted
    /// to drag has sand corners, not white ones) and the gaps between cards.
    func deckCardRow() -> some View {
        self
            .listRowBackground(Theme.background)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12))
    }

    /// A card row you can pick up and drag (Up Next, the pulled-up Up Next):
    /// the lifted copy is just the rounded card, with no square of the
    /// page round it (Paul, build 145 screenshot). The row's own
    /// background is clear, so only the card is lifted.
    /// For a sheet opened from inside the player: the player paints its
    /// text and keys in light paper, and a sheet opened from within it took
    /// that on (Paul, 13 Nov 2026: Share a clip's Cancel / Share and switch
    /// labels were washed out). Back to the app's ink and accent.
    func normalColours() -> some View {
        self
            .foregroundStyle(Theme.ink)
            .tint(Theme.accentFill)
    }

    func reorderCardRow() -> some View {
        self
            .contentShape(.dragPreview, RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12))
    }
}
