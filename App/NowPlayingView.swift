import AVKit
import SwiftUI
import PodcastCore

/// The full player, coloured from the episode artwork (like Apple Podcasts)
/// with white text kept at 4.5:1 contrast. Trim silences, Boost voices and
/// chapters join the controls row later in step 4.
struct NowPlayingView: View {
    @Environment(PlayerModel.self) private var player
    @Environment(\.dismiss) private var dismiss
    /// While dragging the scrubber, where the thumb is.
    @State private var scrubTime: TimeInterval?

    private let text = Color.white
    private let secondary = Color.white.opacity(ColorContrast.secondaryAlpha)

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            if let item = player.nowPlaying {
                VStack(spacing: 22) {
                    Spacer(minLength: 4)
                    GeometryReader { proxy in
                        ArtworkView(url: item.artworkURL, title: item.showTitle, size: proxy.size.width, radius: 20)
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .shadow(color: .black.opacity(0.25), radius: 18, y: 10)

                    VStack(spacing: 6) {
                        Text(item.title)
                            .font(Theme.screenTitle(24))
                            .foregroundStyle(text)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                        Text(item.showTitle)
                            .font(.subheadline)
                            .foregroundStyle(secondary)
                    }

                    scrubber
                    controls
                    optionsRow
                    routeRow
                    Spacer(minLength: 4)
                }
                .padding(.horizontal, 24)
                .task(id: item.artworkURL) { await ArtworkColors.shared.load(item.artworkURL) }
            } else {
                Text("Nothing playing")
                    .foregroundStyle(text)
                    .onAppear { dismiss() }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: player.nowPlaying?.artworkURL)
    }

    /// Artwork colour, or a calm placeholder tone until it's known.
    private var background: Color {
        if let item = player.nowPlaying, let color = ArtworkColors.shared.background(for: item.artworkURL) {
            return color
        }
        return Color(rgb: ColorContrast.themedBackground(from: RGB(r: 0.36, g: 0.34, b: 0.31)))
    }

    private var scrubber: some View {
        let upper = max(player.duration, player.currentTime, 1)
        let shown = scrubTime ?? player.currentTime
        return VStack(spacing: 4) {
            Slider(
                value: Binding(get: { min(shown, upper) }, set: { scrubTime = $0 }),
                in: 0...upper,
                onEditingChanged: { editing in
                    if !editing, let target = scrubTime {
                        player.seek(to: target)
                        scrubTime = nil
                    }
                }
            )
            .tint(text)
            .accessibilityLabel("Position")
            .accessibilityValue(TimeFormat.clock(shown))

            HStack {
                Text(TimeFormat.clock(shown))
                Spacer()
                Text(player.duration > 0 ? "-" + TimeFormat.clock(player.duration - shown) : "")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(secondary)
        }
    }

    private var controls: some View {
        HStack(spacing: 40) {
            SkipButton(direction: .back, iconSize: 30, frame: 56)
            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(background)
                    .frame(width: 76, height: 76)
                    .background(text, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
            SkipButton(direction: .forward, iconSize: 30, frame: 56)
        }
        .foregroundStyle(text)
        .tint(text)
    }

    /// Speed and sleep timer.
    private var optionsRow: some View {
        HStack(spacing: 0) {
            Menu {
                Picker("Speed", selection: Binding(get: { player.speed }, set: { player.setSpeed($0) })) {
                    ForEach(PlayerOptions.speeds, id: \.self) { speed in
                        Text(PlayerOptions.speedLabel(speed)).tag(speed)
                    }
                }
            } label: {
                optionLabel(PlayerOptions.speedLabel(player.speed), systemImage: "gauge.with.dots.needle.67percent")
            }
            .accessibilityLabel("Speed, \(PlayerOptions.speedLabel(player.speed))")

            Rectangle().fill(secondary.opacity(0.4)).frame(width: 1, height: 22)

            Menu {
                if player.sleepTimer != nil {
                    Button("Turn off timer", systemImage: "moon.zzz") { player.setSleepTimer(nil) }
                }
                ForEach(SleepTimerOption.all, id: \.self) { option in
                    Button(option.label) { player.setSleepTimer(option) }
                }
            } label: {
                sleepLabel
            }
        }
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
        .foregroundStyle(text)
        .tint(text)
    }

    @ViewBuilder private var sleepLabel: some View {
        if let ends = player.sleepEndsAt {
            let now = Date()
            HStack(spacing: 6) {
                Image(systemName: "moon.fill")
                Text(timerInterval: now...max(ends, now), countsDown: true)
                    .monospacedDigit()
            }
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 44)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Sleep timer on")
        } else if player.sleepTimer == .endOfEpisode {
            optionLabel("End of episode", systemImage: "moon.fill")
        } else {
            optionLabel("Sleep", systemImage: "moon")
        }
    }

    private func optionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 44)
    }

    /// AirPlay / Bluetooth picker, and where the sound is going.
    private var routeRow: some View {
        HStack(spacing: 8) {
            RoutePicker(tint: .white)
                .frame(width: 44, height: 44)
                .accessibilityLabel("Play on another device")
            Text(player.outputName.map { "Playing on \($0)" } ?? "Play on…")
                .font(.footnote)
                .foregroundStyle(secondary)
                .lineLimit(1)
        }
    }
}

/// The system AirPlay / Bluetooth device picker.
private struct RoutePicker: UIViewRepresentable {
    let tint: UIColor

    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = false
        view.tintColor = tint
        view.activeTintColor = tint
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
