import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers
import PodcastCore

// Deck (Paul, 14 Nov 2026): Settings, opened from the gear on Up next.
// Spec: the prototype's renderSettings / renderPriority and its sw / cyc /
// link / group helpers (design/deck/poddeck-prototype.html). Grouped white
// cards on the warm page. Every setting from the old Shows screen
// (`TopPriorityView`) is here, with the same saved keys and store values:
// nothing new is saved and nothing moves to a different key.

struct DeckSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    DeckSettingsListening()
                    DeckSettingsUpNext()
                    DeckSettingsLook()
                    DeckSettingsPlayback()
                    DeckSettingsDownloads()
                    DeckSettingsBadge()
                    DeckSettingsShows()
                    DeckSettingsProblems()
                    DeckSettingsAbout()
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .deckPage()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Theme.outfit(16, .bold))
                }
            }
        }
        .tint(Theme.ink)
    }
}

// MARK: - Building blocks (the prototype's group / link / sw / cyc)

/// A group: small capitals label, one white card of rows, optional note.
struct DeckSetGroup<Content: View>: View {
    let title: String
    let footer: String?
    let content: Content

    init(_ title: String, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(Theme.outfit(12, .bold))
                .tracking(0.6)
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 8)
                .accessibilityAddTraits(.isHeader)
            DeckSetCard { content }
                .padding(.horizontal, 16)
            if let footer {
                Text(footer)
                    .font(Theme.outfit(12, .medium))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 22)
                    .padding(.top, 6)
            }
        }
    }
}

/// One white card holding rows (rows are split by `DeckSetLine`).
struct DeckSetCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .deckPlainCard(radius: 22)
    }
}

/// The fine line between rows in a card.
struct DeckSetLine: View {
    var body: some View {
        Rectangle()
            .fill(Theme.cardLine)
            .frame(height: 1)
            .padding(.leading, 16)
            .accessibilityHidden(true)
    }
}

/// A row: icon, title (and a small line under it), value, chevron.
struct DeckSetRowLabel: View {
    var icon: String? = nil
    let title: String
    var detail: String? = nil
    var value: String? = nil
    var chevron: String? = "chevron.right"
    var destructive = false

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(destructive ? Color.red : Theme.ink)
                    .frame(width: 24)
            }
            titles
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(Theme.outfit(14, .medium))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            if let chevron {
                Image(systemName: chevron)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.faint)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Theme.outfit(15, .medium))
                .foregroundStyle(destructive ? Color.red : Theme.ink)
                .multilineTextAlignment(.leading)
            if let detail {
                Text(detail)
                    .font(Theme.outfit(12, .medium))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A switch row (ink when on, like every Deck key that's on).
struct DeckSetToggle: View {
    let title: String
    var detail: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.outfit(15, .medium))
                    .foregroundStyle(Theme.ink)
                if let detail {
                    Text(detail)
                        .font(Theme.outfit(12, .medium))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(Theme.ink)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 54)
    }
}

/// Choose from a list: the row shows the choice; tap for the list.
struct DeckSetChoice<Value: Hashable>: View {
    var icon: String? = nil
    let title: String
    let options: [(label: String, value: Value)]
    @Binding var selection: Value

    private var current: String {
        options.first { $0.value == selection }?.label ?? ""
    }

    var body: some View {
        Menu {
            Picker(title, selection: $selection) {
                ForEach(options.indices, id: \.self) { index in
                    Text(options[index].label).tag(options[index].value)
                }
            }
        } label: {
            DeckSetRowLabel(icon: icon, title: title, value: current, chevron: "chevron.up.chevron.down")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title): \(current)")
    }
}

// MARK: - Your listening

private struct DeckSettingsListening: View {
    @Environment(LibraryStore.self) private var store
    @State private var downloadsSize = ""

    var body: some View {
        DeckSetGroup("Your listening") {
            NavigationLink { HistoryView() } label: {
                DeckSetRowLabel(icon: "clock.arrow.circlepath", title: "History")
            }
            DeckSetLine()
            NavigationLink { StatsView() } label: {
                DeckSetRowLabel(icon: "chart.bar", title: "Stats", value: StatsView.hours(WeekStats.current.listened) + " this week")
            }
            DeckSetLine()
            NavigationLink { StorageView() } label: {
                DeckSetRowLabel(icon: "internaldrive", title: "Downloads", value: downloadsSize)
            }
        }
        .buttonStyle(.plain)
        .task { measure() }
    }

    private func measure() {
        let rows: [LibraryStore.ShowStorage] = store.storageByShow()
        let count: Int = rows.reduce(0) { $0 + $1.count }
        let bytes: Int64 = rows.reduce(Int64(0)) { $0 + $1.bytes }
        downloadsSize = count == 0 ? "None" : "\(count) · " + StorageView.size(bytes)
    }
}

// MARK: - Up next

private struct DeckSettingsUpNext: View {
    @Environment(LibraryStore.self) private var store
    @State private var checkHours = BackgroundRefresh.intervalHours

    var body: some View {
        @Bindable var store = store
        DeckSetGroup("Up next", footer: "iOS decides the exact moment of each check, so it can run a little late. Pull down on Up next to check now.") {
            NavigationLink { DeckPriorityView() } label: {
                DeckSetRowLabel(icon: "list.number", title: "Top show priority", value: "\(store.topShows.count) shows")
            }
            .buttonStyle(.plain)
            DeckSetLine()
            DeckSetToggle(title: "Keep each show in order",
                          detail: "Play next and Play last never jump a show ahead of its older episodes",
                          isOn: $store.keepShowOrder)
            DeckSetLine()
            DeckSetToggle(title: "Keep playing new episodes",
                          detail: "When Up next runs out, carry on with the last week's new episodes",
                          isOn: $store.keepPlayingNew)
            DeckSetLine()
            DeckSetChoice(icon: "arrow.clockwise", title: "Check for new episodes",
                          options: [(label: "Hourly", value: 1), (label: "Every 3 hours", value: 3), (label: "Every 6 hours", value: 6)],
                          selection: checkBinding)
        }
    }

    private var checkBinding: Binding<Int> {
        Binding(get: { checkHours }, set: { hours in
            checkHours = hours
            BackgroundRefresh.intervalHours = hours
            BackgroundRefresh.schedule()
        })
    }
}

// MARK: - Look

private struct DeckSettingsLook: View {
    @AppStorage(ColourScheme.key) private var colourScheme = ColourScheme.auto
    @AppStorage(FogBackdrop.densityKey) private var fogDensity = 1.0
    @AppStorage(FogBackdrop.tintKey) private var fogTint = true
    @State private var refreshed = false

    /// Auto, then every scheme by name (Deck, Deck night, Haar, Sand,
    /// Slate, Clay, Night).
    private var schemes: [(label: String, value: String)] {
        [(label: "Auto", value: ColourScheme.auto)] + ColourScheme.allCases.map { (label: $0.label, value: $0.rawValue) }
    }

    var body: some View {
        DeckSetGroup("Look", footer: "Auto uses Deck, or Deck night when your iPhone is in dark mode. Choosing colours redraws the app, so Settings closes.") {
            NavigationLink { DeckLayoutView() } label: {
                DeckSetRowLabel(icon: "slider.horizontal.3", title: "Layout")
            }
            .buttonStyle(.plain)
            DeckSetLine()
            DeckSetChoice(icon: "paintpalette", title: "Colours", options: schemes, selection: $colourScheme)
            if Theme.isHaar { haarFog }
            DeckSetLine()
            Button(action: refreshArtwork) {
                DeckSetRowLabel(icon: "photo.on.rectangle", title: "Refresh artwork",
                                detail: "Fetches every show's artwork and colours again",
                                value: refreshed ? "Done" : nil, chevron: nil)
            }
            .buttonStyle(.plain)
        }
    }

    /// Haar's fog settings, only while Haar is the look.
    @ViewBuilder private var haarFog: some View {
        DeckSetLine()
        HStack(spacing: 10) {
            Text("Fog").font(Theme.outfit(15, .medium)).foregroundStyle(Theme.ink)
            Slider(value: $fogDensity, in: 0...1.4).tint(Theme.ink)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 54)
        DeckSetLine()
        DeckSetToggle(title: "Tint the mist with each show", isOn: $fogTint)
    }

    private func refreshArtwork() {
        ArtworkImageCache.shared.clear()
        ArtworkColors.shared.clear()
        refreshed = true
    }
}

// MARK: - Playback

private struct DeckSettingsPlayback: View {
    @Environment(PlayerModel.self) private var player
    @AppStorage(PlayerModel.rewindKey) private var rewindOnResume = true
    @AppStorage("bedtimeSleepTimer") private var bedtimeTimer = false  // PlayerModel.bedtimeKey
    @AppStorage("afterEpisode") private var afterEpisode = "top"  // PlayerModel.afterEpisodeKey

    private var skipOptions: [(label: String, value: Int)] {
        PlayerOptions.skipLengths.map { (label: "\($0)s", value: $0) }
    }

    private var skipBack: Binding<Int> {
        Binding(get: { player.skipBackSeconds }, set: { player.setSkipBack($0) })
    }

    private var skipForward: Binding<Int> {
        Binding(get: { player.skipForwardSeconds }, set: { player.setSkipForward($0) })
    }

    var body: some View {
        DeckSetGroup("Playback", footer: "Skip lengths also apply on the lock screen and headphones; touch and hold a skip button in the player to change them there.") {
            DeckSetChoice(icon: "gobackward", title: "Skip back", options: skipOptions,
                          selection: skipBack)
            DeckSetLine()
            DeckSetChoice(icon: "goforward", title: "Skip forward", options: skipOptions,
                          selection: skipForward)
            DeckSetLine()
            DeckSetToggle(title: "Rewind a little when you resume",
                          detail: "3 seconds after a short pause, 10 after a minute, 20 after an hour",
                          isOn: $rewindOnResume)
            DeckSetLine()
            DeckSetToggle(title: "Bedtime sleep timer",
                          detail: "Starting an episode between 10pm and 5am sets the sleep timer you last chose",
                          isOn: $bedtimeTimer)
            DeckSetLine()
            DeckSetChoice(icon: "forward.end", title: "After an episode, play",
                          options: [(label: "Top of Up next", value: "top"), (label: "Next in the list", value: "next")],
                          selection: $afterEpisode)
        }
    }
}

// MARK: - Downloads and transcripts

private struct DeckSettingsDownloads: View {
    @Environment(LibraryStore.self) private var store
    @Environment(DownloadManager.self) private var downloads
    @AppStorage("downloadCapGB") private var downloadCapGB = 0  // LibraryStore.downloadCapKey

    private var capOptions: [(label: String, value: Int)] {
        [(label: "No limit", value: 0)] + [2, 5, 10, 20].map { (label: "\($0) GB", value: $0) }
    }

    var body: some View {
        @Bindable var store = store
        @Bindable var downloads = downloads
        DeckSetGroup("Downloads and transcripts", footer: "Played downloads are deleted straight away unless you keep them for 24 hours. Over the limit the oldest go first: played, then not in Up next, then the end of Up next (never what's playing).") {
            DeckSetToggle(title: "Download on Wi-Fi only", isOn: $downloads.wifiOnly)
            DeckSetLine()
            DeckSetToggle(title: "Keep played downloads for 24 hours", isOn: $store.keepPlayedDownloads)
            DeckSetLine()
            DeckSetChoice(icon: "externaldrive", title: "Keep downloads under", options: capOptions, selection: $downloadCapGB)
                .onChange(of: downloadCapGB) { store.applyStorageCap() }
            DeckSettingsTranscriptRows()
            DeckSettingsAdRows()
        }
    }
}

private struct DeckSettingsTranscriptRows: View {
    @Environment(TranscriptService.self) private var transcripts

    var body: some View {
        @Bindable var transcripts = transcripts
        DeckSetLine()
        DeckSetChoice(icon: "text.quote", title: "Transcribe",
                      options: TranscriptService.Schedule.allCases.map { (label: $0.label, value: $0) },
                      selection: $transcripts.schedule)
        DeckSetLine()
        Button { transcripts.transcribeUpNextNow() } label: {
            DeckSetRowLabel(icon: "waveform", title: "Transcribe Up next now",
                            detail: transcripts.schedule.explanation, chevron: nil)
        }
        .buttonStyle(.plain)
        if transcripts.isBusy {
            DeckSetLine()
            // Not red: stopping can be undone with Transcribe now.
            Button { transcripts.stopAll() } label: {
                DeckSetRowLabel(icon: "stop.circle", title: "Stop all transcribing", chevron: nil)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct DeckSettingsAdRows: View {
    @Environment(PlayerModel.self) private var player
    @State private var findAds = AdScanner.isEnabled

    var body: some View {
        DeckSetLine()
        DeckSetToggle(title: "Find ads while listening",
                      detail: "Checks the next few minutes of a downloaded episode for sponsor reads, on your iPhone",
                      isOn: findAdsBinding)
        DeckSetLine()
        DeckSetToggle(title: "Skip ads automatically",
                      isOn: skipAdsBinding)
    }

    private var skipAdsBinding: Binding<Bool> {
        Binding(get: { player.skipAds }, set: { player.setSkipAds($0) })
    }

    private var findAdsBinding: Binding<Bool> {
        Binding(get: { findAds }, set: { on in
            findAds = on
            AdScanner.isEnabled = on
        })
    }
}

// MARK: - App icon badge

private struct DeckSettingsBadge: View {
    @AppStorage(AppBadge.modeKey) private var badgeMode = BadgeMode.off.rawValue

    /// What the chosen badge counts, and how often it updates (as on the
    /// old Shows screen).
    private var footer: String {
        let mode = BadgeMode(rawValue: badgeMode) ?? .off
        guard mode != .off else { return "The red number on Poddeck's icon. " + mode.detail }
        return mode.detail + " It updates when you open the app and when it checks for new episodes, so it can be up to an hour or so behind."
    }

    var body: some View {
        DeckSetGroup("App icon", footer: footer) {
            BadgeSettingRow()
                .padding(.horizontal, 16)
                .frame(minHeight: 54)
        }
    }
}

// MARK: - Shows (import, export, iCloud)

private struct DeckSettingsShows: View {
    @Environment(LibraryStore.self) private var store
    @State private var choosingFile = false
    @State private var importing: (done: Int, total: Int)?
    @State private var message: String?
    @State private var showingCloud = false

    var body: some View {
        DeckSetGroup("Shows", footer: message ?? "Move your shows from or to another podcast app with an OPML file. Imported shows start on Bottom and nothing downloads until new episodes arrive.") {
            Button { choosingFile = true } label: {
                DeckSetRowLabel(icon: "square.and.arrow.down", title: "Import from another app",
                                value: importing.map { "\($0.done) of \($0.total)" } ?? "OPML")
            }
            .buttonStyle(.plain)
            .disabled(importing != nil)
            DeckSetLine()
            ShareLink(item: ShowListFile(text: store.showListOPML), preview: SharePreview("Poddeck shows")) {
                DeckSetRowLabel(icon: "square.and.arrow.up", title: "Export your shows", value: "OPML")
            }
            .buttonStyle(.plain)
            DeckSetLine()
            cloudRow
            if showingCloud {
                ICloudStatusRows()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.opml, .xml, .data]) { result in
            guard case .success(let url) = result else { return }
            Task { await importFile(url) }
        }
    }

    private var cloudRow: some View {
        Button { showingCloud.toggle() } label: {
            DeckSetRowLabel(icon: "icloud", title: "iCloud",
                            value: CloudSync.isSignedIn ? "Syncing" : "Off",
                            chevron: showingCloud ? "chevron.up" : "chevron.down")
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows the account, sync and alerts status")
    }

    /// As the old Shows screen's import (ImportExportSection).
    private func importFile(_ url: URL) async {
        message = nil
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let shows: [OPML.Show]
        do {
            shows = try OPML.parse(try Data(contentsOf: url))
        } catch {
            message = (error as? LocalizedError)?.errorDescription ?? "Couldn't read that file."
            return
        }
        importing = (0, shows.count)
        let result = await store.importShows(shows) { done in importing = (done, shows.count) }
        importing = nil
        message = Self.summary(result)
    }

    private static func summary(_ result: LibraryStore.ImportResult) -> String {
        var parts: [String] = ["Added \(result.added) show\(result.added == 1 ? "" : "s")."]
        if result.alreadyFollowed > 0 { parts.append("\(result.alreadyFollowed) you already follow.") }
        if !result.failed.isEmpty {
            let names: String = result.failed.prefix(5).joined(separator: ", ")
            parts.append("Couldn't load \(result.failed.count): \(names)\(result.failed.count > 5 ? "…" : ""). Try adding those by name.")
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - Problems

private struct DeckSettingsProblems: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(TranscriptService.self) private var transcripts
    @Environment(DownloadManager.self) private var downloads
    @State private var copied = false

    var body: some View {
        DeckSetGroup("Problems", footer: "Copies a summary of how Poddeck is set up and what it's doing (no feed links), to paste into a message about a problem.") {
            Button(action: copy) {
                DeckSetRowLabel(icon: "doc.on.doc", title: "Copy diagnostics",
                                value: copied ? "Copied" : nil, chevron: nil)
            }
            .buttonStyle(.plain)
        }
    }

    private func copy() {
        UIPasteboard.general.string = Diagnostics.report(store: store, player: player, transcripts: transcripts, downloads: downloads)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }
}

// MARK: - About

private struct DeckSettingsAbout: View {
    var body: some View {
        VStack(spacing: 8) {
            Image("IconPreview")
                .resizable()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(Theme.cardEdge, lineWidth: 1))
                .accessibilityHidden(true)
            Text("Poddeck")
                .font(Theme.outfit(16, .heavy))
                .foregroundStyle(Theme.ink)
            Text("No account, no adverts, no subscription")
                .font(Theme.outfit(12, .medium))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
        .padding(.bottom, 10)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Top show priority

/// Top shows in priority order (drag to change; Up next re-sorts to
/// match), then every other show with where its new episodes go and its
/// alert bell (the old Shows screen's "All shows").
struct DeckPriorityView: View {
    @Environment(LibraryStore.self) private var store
    @Query(sort: \Podcast.title) private var allShows: [Podcast]
    @State private var shows: [Podcast] = []

    var body: some View {
        List {
            Section { intro }
            Section { topRows } header: { header("Top, in priority order") }
            Section { otherRows } header: { header("Other shows") }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .deckPage()
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Top show priority")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { shows = store.topShows }
    }

    private var intro: some View {
        Text("Episodes from Top shows go to the top of Up next in this order. Drag to change it.")
            .font(Theme.outfit(14, .medium))
            .foregroundStyle(Theme.muted)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    @ViewBuilder private var topRows: some View {
        if shows.isEmpty {
            Text("No shows are set to Top yet. Make one Top below.")
                .font(Theme.outfit(14, .medium))
                .foregroundStyle(Theme.muted)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        ForEach(Array(shows.enumerated()), id: \.element.feedURL) { index, show in
            DeckPriorityRow(rank: index + 1, show: show)
                .reorderCardRow()
        }
        .onMove { from, to in
            shows.move(fromOffsets: from, toOffset: to)
            store.setTopOrder(shows)
        }
    }

    private var otherRows: some View {
        ForEach(allShows.filter { $0.autoAdd != .top }, id: \.feedURL) { show in
            DeckOtherShowRow(show: show) { shows = store.topShows }
                .reorderCardRow()
        }
    }

    private func header(_ title: String) -> some View {
        Text(title.uppercased())
            .font(Theme.outfit(12, .bold))
            .tracking(0.6)
            .foregroundStyle(Theme.muted)
            .padding(.top, 8)
    }
}

private struct DeckPriorityRow: View {
    let rank: Int
    let show: Podcast

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(Theme.outfit(20, .heavy))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .frame(minWidth: 22)
            DeckFind.artwork(show.artworkURL, title: show.title, size: 44, radius: 11)
            Text(show.title)
                .font(Theme.outfit(15, .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .deckPlainCard(radius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Number \(rank), \(show.title)")
    }
}

/// A show that isn't Top: the bell and where its new episodes go.
private struct DeckOtherShowRow: View {
    @Environment(LibraryStore.self) private var store
    let show: Podcast
    /// Called after the mode changes (the Top list may need refreshing).
    let changed: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            DeckFind.artwork(show.artworkURL, title: show.title, size: 36, radius: 9)
            Text(show.title)
                .font(Theme.outfit(14, .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Spacer(minLength: 4)
            bell
            modeMenu
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .deckPlainCard(radius: 18)
    }

    private var bell: some View {
        Button {
            show.notify.toggle()
            store.save()
            if show.notify { Task { _ = await NewEpisodeAlerts.requestPermission() } }
        } label: {
            Image(systemName: show.notify ? "bell.fill" : "bell")
                .font(.system(size: 15))
                .foregroundStyle(show.notify ? Theme.ink : Theme.faint)
                .frame(width: 40, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(show.notify ? "Alerts on" : "Alerts off")
    }

    private var modeBinding: Binding<AutoAddMode> {
        Binding(get: { show.autoAdd }, set: { mode in
            store.setAutoAdd(mode, for: show)
            changed()
        })
    }

    private var modeMenu: some View {
        Menu {
            Picker("New episodes go to", selection: modeBinding) {
                Text("Top").tag(AutoAddMode.top)
                Text("Bottom").tag(AutoAddMode.bottom)
                Text("Nowhere").tag(AutoAddMode.off)
            }
        } label: {
            HStack(spacing: 4) {
                Text(show.autoAdd == .off ? "Nowhere" : "Bottom")
                    .font(Theme.outfit(13, .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background(Capsule().fill(Theme.surface))
            .overlay(Capsule().strokeBorder(Theme.cardEdge, lineWidth: 1))
        }
        .accessibilityLabel("New episodes go to: \(show.autoAdd == .off ? "Nowhere" : "Bottom")")
    }
}
