import AVKit
import SwiftUI
import PodcastCore

/// The full player. Basic for now; artwork colours, speed, Trim silences,
/// Boost voices, chapters and the sleep timer come in build step 4.
struct NowPlayingView: View {
    @Environment(PlayerModel.self) private var player
    @Environment(\.dismiss) private var dismiss
    /// While dragging the scrubber, where the thumb is.
    @State private var scrubTime: TimeInterval?

    var body: some View {
        VStack(spacing: 24) {
            if let item = player.nowPlaying {
                Spacer(minLength: 8)
                GeometryReader { proxy in
                    ArtworkView(url: item.artworkURL, title: item.showTitle, size: proxy.size.width, radius: 20)
                }
                .aspectRatio(1, contentMode: .fit)
                .shadow(color: .black.opacity(0.12), radius: 16, y: 8)

                VStack(spacing: 6) {
                    Text(item.title)
                        .font(Theme.screenTitle(24))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                    Text(item.showTitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }

                scrubber
                controls

                HStack {
                    Spacer()
                    RoutePicker()
                        .frame(width: 44, height: 44)
                        .accessibilityLabel("Play on another device")
                    Spacer()
                }
                Spacer(minLength: 8)
            } else {
                Text("Nothing playing")
                    .foregroundStyle(Theme.muted)
                    .onAppear { dismiss() }
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
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
            .tint(Theme.ink)
            .accessibilityLabel("Position")
            .accessibilityValue(TimeFormat.clock(shown))

            HStack {
                Text(TimeFormat.clock(shown))
                Spacer()
                Text(player.duration > 0 ? "-" + TimeFormat.clock(player.duration - shown) : "")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(Theme.muted)
        }
    }

    private var controls: some View {
        HStack(spacing: 44) {
            Button { player.skipBackward() } label: {
                Image(systemName: "gobackward.\(Int(player.skipBack))")
                    .font(.system(size: 30))
                    .frame(width: 56, height: 56)
            }
            .accessibilityLabel("Back \(Int(player.skipBack)) seconds")

            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.background)
                    .frame(width: 76, height: 76)
                    .background(Theme.ink, in: Circle())
            }
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

            Button { player.skipForwardBy() } label: {
                Image(systemName: "goforward.\(Int(player.skipForward))")
                    .font(.system(size: 30))
                    .frame(width: 56, height: 56)
            }
            .accessibilityLabel("Forward \(Int(player.skipForward)) seconds")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.ink)
    }
}

/// The system AirPlay / Bluetooth device picker.
private struct RoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = false
        view.tintColor = UIColor(Theme.ink)
        view.activeTintColor = UIColor(Theme.accentFill)
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
