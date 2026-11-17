import SwiftUI
import PodcastCore

/// The player's Options as a short sheet (Paul's D, 12 Nov 2026), sized to
/// fit everything at once (Paul, 13 Nov 2026: no swiping up for the rest;
/// no blue; the see-through glass was too cloudy). Solid warm page, white
/// cards, icons and keys in ink and the accent.
struct PlayerOptionsSheet: View {
    @Environment(PlayerModel.self) private var player
    @Environment(\.dismiss) private var dismiss
    /// The sheet is exactly as tall as what's in it.
    @State private var height: CGFloat = 420

    private static let quickSpeeds: [Double] = [1, 1.2, 1.5, 2]

    var body: some View {
        VStack(spacing: 12) {
            header
            card { speedRow; quickPicks }
            card {
                toggleRow("Trim silences", detail: "Skips through the pauses", icon: "scissors",
                          isOn: Binding(get: { player.trimSilences }, set: { player.setTrimSilences($0) }))
                Divider().overlay(Theme.hairline)
                toggleRow("Boost voices", detail: "Evens out quiet speech", icon: "waveform",
                          isOn: Binding(get: { player.boostVoices }, set: { player.setBoostVoices($0) }))
            }
            card { sleepRow }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .foregroundStyle(Theme.ink)
        .tint(Theme.accentFill)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Theme.background)
    }

    private var header: some View {
        ZStack {
            Text("Options").font(.headline)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .buttonStyle(.plain)
            }
        }
        .frame(height: 32)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 10) { content() }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    private func label(_ title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.ink)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.body)
                Text(detail).font(.caption).foregroundStyle(Theme.muted)
            }
        }
    }

    private func toggleRow(_ title: String, detail: String, icon: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) { label(title, detail: detail, icon: icon) }
    }

    private var speeds: [Double] { PlayerOptions.speeds }

    private var speedIndex: Int {
        speeds.firstIndex { abs($0 - player.speed) < 0.01 } ?? 0
    }

    /// "Speed" on the left, one compact "− 1.2× +" control on the right.
    private var speedRow: some View {
        let index: Int = speedIndex
        return HStack {
            label("Speed", detail: player.speedIsForShow ? "This show" : "All shows", icon: "gauge.with.dots.needle.50percent")
            Spacer(minLength: 8)
            HStack(spacing: 0) {
                stepButton("minus", label: "Slower", enabled: index > 0) { player.setSpeed(speeds[index - 1]) }
                Text(PlayerOptions.speedLabel(player.speed))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .frame(minWidth: 44)
                stepButton("plus", label: "Faster", enabled: index < speeds.count - 1) { player.setSpeed(speeds[index + 1]) }
            }
            .background(Theme.ink.opacity(0.07), in: Capsule())
        }
    }

    private func stepButton(_ icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 36, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.3)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private var quickPicks: some View {
        HStack(spacing: 8) {
            ForEach(Self.quickSpeeds, id: \.self) { speed in
                let on: Bool = abs(player.speed - speed) < 0.01
                Button { player.setSpeed(speed) } label: {
                    Text(PlayerOptions.speedLabel(speed))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .foregroundStyle(on ? Theme.onAccent : Theme.ink)
                        .background(on ? Theme.accentFill : Theme.ink.opacity(0.07), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    /// One row; its value opens the list of timers. "+5" while one runs.
    private var sleepRow: some View {
        HStack(spacing: 8) {
            Menu {
                Button("Off") {
                    player.setSleepTimer(nil)
                    player.setStopAtChapterEnd(false)
                }
                ForEach(SleepTimerOption.all, id: \.self) { option in
                    Button(option.label) {
                        player.setStopAtChapterEnd(false)
                        player.chooseSleepTimer(option)
                    }
                }
                // End of chapter (Paul, 15 Nov 2026): uses the chapter stop
                // (fades and pauses when the chapter playing now ends).
                if !player.chapters.isEmpty {
                    Button("End of chapter") {
                        player.setSleepTimer(nil)
                        player.setStopAtChapterEnd(true)
                    }
                }
            } label: {
                HStack {
                    label("Sleep timer", detail: "Fades out, then stops", icon: "moon")
                    Spacer(minLength: 8)
                    Text(sleepValue).foregroundStyle(Theme.muted)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // The list in ink, not the accent (Paul, 16 Nov 2026: menus on
            // the player had "a kind of purple tint").
            .tint(Theme.ink)
            if player.sleepEndsAt != nil {
                Button { player.extendSleepTimer() } label: {
                    Text("+5")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 30)
                        .background(Theme.ink.opacity(0.07), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("5 more minutes")
            }
        }
    }

    private var sleepValue: String {
        if let ends = player.sleepEndsAt {
            return "\(max(1, Int((ends.timeIntervalSinceNow / 60).rounded(.up)))) min left"
        }
        if player.stopsAtChapterEnd { return "End of chapter" }
        switch player.sleepTimer {
        case .none: return "Off"
        case .some(.endOfEpisode): return "End of episode"
        case .some(let option): return option.label
        }
    }
}
