import SwiftUI
import PodcastCore

// The Haar show sheet's Settings page and the small pieces it shares with
// the Episodes page (HaarShow.swift): underlined words, frosted grouped
// cards and their hairlines.

// MARK: Settings

/// The show's settings, Haar style: plain words and switches straight on
/// the page with hairlines between (Paul, 13 Nov 2026: menus are just
/// text, no white card). The same settings as `ShowSettingsView` (which the other colour
/// schemes keep).
struct HaarShowSettings: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    let show: Podcast
    let tint: Color
    @State private var confirmingOlder = false
    @State private var olderCount = 0
    @State private var confirmingAddAll = false
    @State private var addAllCount = 0
    /// Bumped after a Top re-rank, so the rank redraws straight away.
    @State private var rankTick = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            if show.autoAdd == .top {
                priorityCard
            }
            switchCard
            joinSection
            playbackSection
            olderSection
        }
        .alert("Mark \(olderCount) older episode\(olderCount == 1 ? "" : "s") as played?", isPresented: $confirmingOlder) {
            Button("Mark as played") { markOlderPlayed() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Everything but the newest episode. They leave Up Next and stop showing as unplayed.")
        }
        .alert(addAllTitle, isPresented: $confirmingAddAll) {
            if addAllCount > 0 {
                Button("Add to Up next") { store.addBackCatalogue(of: show) }
                Button("Cancel", role: .cancel) {}
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: {
            Text(addAllMessage)
        }
    }

    // MARK: Top show priority

    private var priorityCard: some View {
        let tops: [Podcast] = store.topShows
        let index: Int = tops.firstIndex { $0.feedURL == show.feedURL } ?? 0
        let _ = rankTick
        return VStack(spacing: 8) {
            HStack(spacing: 0) {
                rankArrow("arrow.up", label: "Move up", enabled: index > 0) { move(by: -1) }
                Text("#\(index + 1)")
                    .font(Theme.serif(30))
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Number \(index + 1) of \(tops.count) Top shows")
                rankArrow("arrow.down", label: "Move down", enabled: index < tops.count - 1) { move(by: 1) }
            }
            Text("Your #1 show's episodes go first in Up next")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
    }

    private func rankArrow(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.ink.opacity(enabled ? 1 : 0.25))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    /// Swaps this show with the one above or below it in the Top order;
    /// Up next re-sorts to match.
    private func move(by step: Int) {
        var tops: [Podcast] = store.topShows
        guard let from = tops.firstIndex(where: { $0.feedURL == show.feedURL }) else { return }
        let to = from + step
        guard tops.indices.contains(to) else { return }
        tops.swapAt(from, to)
        withAnimation(LibraryStore.listChange) { store.setTopOrder(tops) }
        rankTick += 1
    }

    // MARK: Switches

    private var switchCard: some View {
        VStack(spacing: 0) {
            toggleRow("Download new episodes", isOn: downloadBinding)
            HaarMenuHairline()
            toggleRow("Tell me when one lands", isOn: notifyBinding)
        }
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(Theme.ink)
        }
        .tint(tint)
        .padding(.vertical, 11)
    }

    private var downloadBinding: Binding<Bool> {
        Binding(get: { show.autoDownload }, set: { value in
            show.autoDownload = value
            store.save()
        })
    }

    private var notifyBinding: Binding<Bool> {
        Binding(get: { show.notify }, set: { on in
            show.notify = on
            store.save()
            if on { Task { await NewEpisodeAlerts.requestPermission() } }
            Task { await RealtimeAlerts.publishFollows(store: store) }
        })
    }

    // MARK: Where new episodes go

    private var joinSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("New episodes join Up next at the")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
            HaarShowChoice(options: Self.autoAddOptions, selection: autoAddBinding)
        }
    }

    private static let autoAddOptions: [(label: String, value: AutoAddMode)] = [
        (label: "Top", value: .top), (label: "Bottom", value: .bottom), (label: "Don't add", value: .off)
    ]

    private var autoAddBinding: Binding<AutoAddMode> {
        Binding(get: { show.autoAdd }, set: { mode in
            store.setAutoAdd(mode, for: show)
            rankTick += 1
        })
    }

    // MARK: Playback

    private var playbackSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HaarShowLabel(text: "Playback")
            choiceRow("Skip the intro", options: Self.skipOptions, selection: secondsBinding(\.skipIntro))
            choiceRow("Skip the outro", options: Self.skipOptions, selection: secondsBinding(\.skipOutro))
            choiceRow("Speed", options: Self.speedOptions, selection: speedBinding)
            choiceRow("Keep downloads", options: Self.keepOptions, selection: keepBinding)
        }
    }

    private func choiceRow<Value: Hashable>(_ title: String, options: [(label: String, value: Value)], selection: Binding<Value>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
            HaarShowChoice(options: options, selection: selection)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private static let skipOptions: [(label: String, value: Double)] = [
        (label: "Off", value: 0), (label: "15s", value: 15), (label: "30s", value: 30), (label: "45s", value: 45)
    ]

    /// 0 = Default (the speed everything else plays at).
    private static let speedOptions: [(label: String, value: Double)] = [
        (label: "Default", value: 0), (label: "1×", value: 1.0), (label: "1.2×", value: 1.2),
        (label: "1.5×", value: 1.5), (label: "2×", value: 2.0)
    ]

    /// 0 = keep all.
    private static let keepOptions: [(label: String, value: Int)] = [
        (label: "All", value: 0), (label: "Latest 1", value: 1), (label: "3", value: 3),
        (label: "5", value: 5), (label: "10", value: 10)
    ]

    private func secondsBinding(_ keyPath: ReferenceWritableKeyPath<Podcast, Double>) -> Binding<Double> {
        Binding(get: { show[keyPath: keyPath] }, set: { value in
            show[keyPath: keyPath] = value
            store.save()
            player.showSettingsChanged(show)
        })
    }

    private var speedBinding: Binding<Double> {
        Binding(get: { show.speedOverride }, set: { value in
            show.speedOverride = value
            store.save()
            player.showSettingsChanged(show)
        })
    }

    private var keepBinding: Binding<Int> {
        Binding(get: { show.downloadLimit }, set: { store.setDownloadLimit($0, for: show) })
    }

    // MARK: Older episodes

    private var olderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HaarShowLabel(text: "Older episodes")
            VStack(spacing: 0) {
                actionRow("Mark older episodes as played", symbol: "checkmark.circle") { askMarkOlder() }
                HaarMenuHairline()
                actionRow("Add all to Up next, oldest first", symbol: "text.append") { askAddAll() }
            }
        }
    }

    private func actionRow(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var olderEpisodes: [PodcastEpisode] {
        let latest: PodcastEpisode? = store.latestEpisode(of: show)
        return show.episodes.filter { !$0.played && $0.episodeID != latest?.episodeID }
    }

    private func askMarkOlder() {
        olderCount = olderEpisodes.count
        if olderCount == 0 {
            addAllCount = -1
            confirmingAddAll = true
        } else {
            confirmingOlder = true
        }
    }

    private func markOlderPlayed() {
        let older: [PodcastEpisode] = olderEpisodes
        guard !older.isEmpty else { return }
        store.undoable("Marked \(older.count) played", episodes: older) { store.markPlayed(older) }
    }

    private func askAddAll() {
        addAllCount = store.backCatalogue(of: show).count
        confirmingAddAll = true
    }

    private var addAllTitle: String {
        if addAllCount < 0 { return "Every older episode is already played" }
        if addAllCount == 0 { return "Every unplayed episode is already in Up next" }
        return "Add \(addAllCount) episode\(addAllCount == 1 ? "" : "s") to Up next?"
    }

    private var addAllMessage: String {
        if addAllCount < 0 { return "Only the newest episode is still unplayed." }
        if addAllCount == 0 { return "There's nothing left to add." }
        return "They go at the end of Up next, oldest first, so you can listen from the very first episode. Nothing extra downloads."
    }
}

// MARK: Pieces

/// A word that can be chosen: ink, bold and underlined when it is, muted
/// otherwise (tabs, Unplayed / All and the settings choices).
struct HaarShowWord: View {
    let title: String
    let selected: Bool
    var size: CGFloat = 15
    /// Space between the word and its underline.
    var gap: CGFloat = 7
    /// Take an equal share of the row, centred, with the underline across
    /// the whole share (settings choices spread across the page).
    var fills: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if fills { spread } else { word }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var label: some View {
        Text(title)
            .font(.system(size: size, weight: selected ? .bold : .medium))
            .foregroundStyle(selected ? Theme.ink : Theme.muted)
            .lineLimit(1)
    }

    private var word: some View {
        label
            .fixedSize()
            .overlay(alignment: .bottom) { underline }
            .frame(minHeight: 36)
            .contentShape(Rectangle())
    }

    private var spread: some View {
        label
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, minHeight: 36)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(selected ? Theme.ink : Color.clear)
                    .frame(height: 2)
            }
            .contentShape(Rectangle())
    }

    private var underline: some View {
        Rectangle()
            .fill(selected ? Theme.ink : Color.clear)
            .frame(height: 2)
            .offset(y: gap + 2)
    }
}

/// One of a few words, underlined when chosen, spread evenly across the
/// page (Paul, 13 Nov 2026, after build 152: left-aligned looked odd).
struct HaarShowChoice<Value: Hashable>: View {
    let options: [(label: String, value: Value)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                word(index)
            }
        }
    }

    private func word(_ index: Int) -> some View {
        let option: (label: String, value: Value) = options[index]
        return HaarShowWord(title: option.label, selected: option.value == selection, size: 15, gap: 5, fills: true) {
            withAnimation(.easeOut(duration: 0.15)) { selection = option.value }
        }
    }
}

/// A small section label: 11 pt bold capitals, spaced out.
struct HaarShowLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(1.3)
            .foregroundStyle(Theme.muted)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A thin line between rows of a grouped card.
struct HaarShowHairline: View {
    var inset: CGFloat = 16

    var body: some View {
        Rectangle()
            .fill(Color(red: 31 / 255, green: 35 / 255, blue: 40 / 255).opacity(0.07))
            .frame(height: 1)
            .padding(.leading, inset)
            .accessibilityHidden(true)
    }
}

/// The frosted fill of a grouped card (white over a blur).
struct HaarShowCardFill: View {
    var body: some View {
        // The page's own grey: rows sit on the page with hairlines between
        // (it still covers the swipe's action block as a row slides).
        Theme.background
    }
}

/// A grouped frosted card: rounded 22, white edge. `filled: false` when
/// the rows paint their own fill (rows that swipe).
private struct HaarShowGroup: ViewModifier {
    let filled: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        content
            .background {
                if filled { HaarShowCardFill() }
            }
            .clipShape(shape)
    }
}

extension View {
    /// A grouped frosted card (Haar show sheet).
    func haarShowGroup(filled: Bool = true) -> some View {
        modifier(HaarShowGroup(filled: filled))
    }
}
