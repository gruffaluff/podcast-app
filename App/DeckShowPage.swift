import SwiftUI
import PodcastCore

// Deck (Paul, 14 Nov 2026): a show's page, pushed on the Shows tab
// (prototype renderShowPage). A white header card: artwork, name,
// "publisher · n episodes"; Following (in the show's colour; tap to
// unfollow), Alerts on / off and Settings as pills; NEW EPISODES GO TO
// Top / Bottom / Nowhere; the description. Then the episodes as cards.
// ⋯ holds Add all to Up next, Mark all played, Share and Unfollow.

struct DeckShowPage: View {
    @Environment(LibraryStore.self) private var store
    @Environment(PlayerModel.self) private var player
    @Environment(\.dismiss) private var dismiss
    let show: Podcast
    /// The show's colour, fixed when the page opens so nothing changes
    /// colour while it's on screen (Paul, 11 Nov 2026).
    @State private var colour: Color
    @State private var showingSettings = false
    @State private var confirmingUnfollow = false
    @State private var confirmingAddAll = false
    @State private var confirmingMarkAll = false
    @State private var addAllTitle = ""

    init(show: Podcast) {
        self.show = show
        _colour = State(initialValue: DeckShowColour.of(show))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DeckShowPageHeader(show: show, colour: colour, unfollow: { confirmingUnfollow = true },
                                   settings: { showingSettings = true })
                DeckShowEpisodeList(show: show, colour: colour, markAll: { confirmingMarkAll = true })
                    .padding(.top, 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .deckPage()
        .toolbar(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { moreMenu } }
        .environment(\.showColour, colour)
        .sheet(isPresented: $showingSettings) { ShowSettingsView(show: show) }
        .modifier(DeckShowPageAlerts(show: show, unfollowing: $confirmingUnfollow, addingAll: $confirmingAddAll,
                                     markingAll: $confirmingMarkAll, addAllTitle: addAllTitle, unfollow: unfollow))
        .task(id: show.artworkURL) { await ArtworkColors.shared.load(show.artworkURL) }
    }

    private var moreMenu: some View {
        Menu {
            Button("Add all to Up next, oldest first", systemImage: "text.append") { askAddAll() }
            Button("Mark all as played", systemImage: "checkmark.circle") { confirmingMarkAll = true }
            if let link = shareLink {
                ShareLink(item: link) { Label("Share show", systemImage: "square.and.arrow.up") }
            }
            Button("Unfollow", systemImage: "xmark", role: .destructive) { confirmingUnfollow = true }
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel("More")
    }

    private var shareLink: URL? {
        show.website ?? URL(string: show.feedURL)
    }

    private func askAddAll() {
        let count: Int = store.backCatalogue(of: show).count
        addAllTitle = count == 0 ? "Every unplayed episode is already in Up next"
            : "Add \(count) episode\(count == 1 ? "" : "s") to Up next?"
        confirmingAddAll = true
    }

    /// As ShowView: stop it if it's playing, leave the page, then delete
    /// once the page has gone (so it never shows a removed show).
    private func unfollow() {
        player.stopIfPlaying(showFeedURL: show.feedURL)
        dismiss()
        let show = show
        let store = store
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            store.unfollow(show)
        }
    }
}

/// The confirms on the show page, kept out of its body.
private struct DeckShowPageAlerts: ViewModifier {
    @Environment(LibraryStore.self) private var store
    let show: Podcast
    @Binding var unfollowing: Bool
    @Binding var addingAll: Bool
    @Binding var markingAll: Bool
    let addAllTitle: String
    let unfollow: () -> Void

    func body(content: Content) -> some View {
        content
            .alert("Unfollow \(show.title)?", isPresented: $unfollowing) {
                Button("Cancel", role: .cancel) {}
                Button("Unfollow", role: .destructive, action: unfollow)
            } message: {
                Text("Its episodes leave Up next and your shows.")
            }
            .alert(addAllTitle, isPresented: $addingAll) {
                Button("Add to Up next") { store.addBackCatalogue(of: show) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("They go at the end of Up next, oldest first. Nothing extra downloads.")
            }
            .alert("Mark all \(show.episodes.count) episodes as played?", isPresented: $markingAll) {
                Button("Mark all played") { markAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("They leave Up next and stop showing as unplayed.")
            }
    }

    private func markAll() {
        let all: [PodcastEpisode] = show.episodes
        store.undoable("Marked \(all.count) played", episodes: all) { store.markPlayed(all) }
    }
}

/// The white header card.
private struct DeckShowPageHeader: View {
    let show: Podcast
    let colour: Color
    let unfollow: () -> Void
    let settings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                ArtworkView(url: show.artworkURL, title: show.title, size: 104, radius: 20)
                names
            }
            DeckShowPagePills(show: show, colour: colour, unfollow: unfollow, settings: settings)
                .padding(.top, 14)
            DeckShowLabel(text: "New episodes go to")
                .padding(.top, 16)
            DeckShowRulePicker(show: show)
                .padding(.top, 8)
            if !show.summary.isEmpty {
                Text(show.summary)
                    .font(Theme.outfit(14, .medium))
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(3)
                    .lineLimit(8)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .deckPlainCard(radius: 28)
    }

    private var names: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(show.title)
                .font(Theme.outfit(24, .heavy))
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(byline)
                .font(Theme.outfit(13, .medium))
                .foregroundStyle(Theme.muted)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var byline: String {
        let count: Int = show.episodes.count
        let total: String = "\(count) episode\(count == 1 ? "" : "s")"
        return show.author.isEmpty ? total : show.author + " · " + total
    }
}

/// Following (the show's colour), Alerts on / off, Settings (or the show's
/// own speed).
private struct DeckShowPagePills: View {
    @Environment(LibraryStore.self) private var store
    let show: Podcast
    let colour: Color
    let unfollow: () -> Void
    let settings: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: unfollow) {
                DeckShowPill(title: "Following", icon: "checkmark", fill: colour)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Unfollows this show, after asking")
            Button(action: toggleAlerts) {
                DeckShowPill(title: show.notify ? "Alerts on" : "Alerts off",
                             icon: show.notify ? "bell.fill" : "bell", on: show.notify)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(show.notify ? [.isSelected] : [])
            Button(action: settings) {
                DeckShowPill(title: settingsTitle, icon: "slider.horizontal.3")
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
    }

    private var settingsTitle: String {
        show.speedOverride > 0 ? PlayerOptions.speedLabel(show.speedOverride) : "Settings"
    }

    /// As the show settings' switch: ask iOS once, and tell the alerts job.
    private func toggleAlerts() {
        show.notify.toggle()
        store.save()
        if show.notify { Task { await NewEpisodeAlerts.requestPermission() } }
        Task { await RealtimeAlerts.publishFollows(store: store) }
    }
}

/// Top / Bottom / Nowhere, equal widths, the chosen one ink.
private struct DeckShowRulePicker: View {
    @Environment(LibraryStore.self) private var store
    let show: Podcast

    var body: some View {
        HStack(spacing: 6) {
            choice("Top", mode: .top)
            choice("Bottom", mode: .bottom)
            choice("Nowhere", mode: .off)
        }
    }

    private func choice(_ title: String, mode: AutoAddMode) -> some View {
        let on: Bool = show.autoAdd == mode
        return Button {
            // A show newly set to Top joins the end of the Top ranking
            // (LibraryStore.setAutoAdd); re-rank it in Settings.
            withAnimation(.snappy(duration: 0.2)) { store.setAutoAdd(mode, for: show) }
        } label: {
            DeckShowPill(title: title, on: on, wide: true)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }
}
