import SwiftUI

/// A chunky physical key: a raised panel that presses down when tapped.
struct KeyButtonStyle: ButtonStyle {
    enum Kind { case plain, dark, accent }
    var kind: Kind = .plain
    var radius: CGFloat = 10

    func makeBody(configuration: Configuration) -> some View {
        let (fill, shadow, text): (Color, Color, Color) = {
            switch kind {
            case .plain: return (Theme.surface, Theme.controlBorder, Theme.ink)
            case .dark: return (Theme.ink, .black, Theme.background)
            case .accent: return (Theme.accentFill, Theme.accentShadow, Theme.ink)
            }
        }()
        let pressed = configuration.isPressed
        return configuration.label
            .foregroundStyle(text)
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(fill)
                    .shadow(color: shadow, radius: 0, x: 0, y: pressed ? 1 : 3)
            )
            .offset(y: pressed ? 2 : 0)
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

extension ButtonStyle where Self == KeyButtonStyle {
    static var key: KeyButtonStyle { KeyButtonStyle() }
    static var darkKey: KeyButtonStyle { KeyButtonStyle(kind: .dark) }
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
            .background(Theme.display, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Progress as a row of segments, played ones lit, ad breaks in amber.
struct SegmentBar: View {
    /// 0...1
    let progress: Double
    /// Ad breaks as fractions of the episode.
    var ads: [ClosedRange<Double>] = []
    var count = 28
    var height: CGFloat = 12

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<count, id: \.self) { index in
                let start = Double(index) / Double(count)
                let end = Double(index + 1) / Double(count)
                let isAd = ads.contains { $0.lowerBound < end && $0.upperBound > start }
                let played = (start + end) / 2 <= progress
                RoundedRectangle(cornerRadius: 1)
                    .fill(isAd ? Theme.adMarker : (played ? Theme.displayText : Theme.displayTrack))
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
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
            .font(Theme.mono(10, .semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.ink, lineWidth: 1))
    }
}

/// A section heading: monospaced title, with an optional detail on the right.
struct DeckHeader: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(Theme.mono(14, .bold))
                .foregroundStyle(Theme.ink)
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
        HStack(spacing: 8) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let selected = option.value == selection
                Button { selection = option.value } label: {
                    HStack(spacing: 6) {
                        LED(on: selected, color: Theme.accentFill)
                        Text(option.label.uppercased())
                            .font(Theme.mono(12, .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(KeyButtonStyle(kind: selected ? .dark : .plain))
                .accessibilityLabel(option.label)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.bottom, 3)
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
                  color: Theme.accentFill)
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
