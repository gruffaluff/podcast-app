import SwiftUI
import PodcastCore

/// Find a show in Apple's podcast directory, or paste its RSS feed link.
struct AddShowView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [DirectoryShow] = []
    @State private var searching = false
    @State private var following: Set<String> = []
    @State private var message: String?
    /// A show just followed, whose settings sheet is open.
    @State private var justFollowed: Podcast?

    var body: some View {
        NavigationStack {
            List {
                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(Theme.accentText)
                        .listRowBackground(Theme.background)
                }
                if looksLikeFeedLink, let url = feedLink {
                    Button { follow(url) } label: {
                        Label("Follow this link", systemImage: "link")
                    }
                    .foregroundStyle(Theme.accentText)
                    .listRowBackground(Theme.background)
                }
                // Tap a show for its page (description and episodes); the
                // Follow key follows it straight away.
                ForEach(Array(results.enumerated()), id: \.element.id) { index, show in
                    let item = DirectoryItem(show)
                    DirectoryItemRow(item: item)
                        .showRow(item.artworkURL, title: item.title)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .overlay {
                if searching {
                    ProgressView()
                } else if results.isEmpty && !looksLikeFeedLink && message == nil {
                    Text("Search by show name, person or topic, or paste a link from Apple Podcasts or a show's RSS feed.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .padding(32)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Shows, people, topics, or a link")
            .textInputAutocapitalization(.never)
            .onSubmit(of: .search) { search() }
            .sheet(item: $justFollowed) { show in
                ShowSettingsView(show: show, justFollowed: true)
            }
            .navigationTitle("ADD A SHOW")
            .navigationDestination(for: DirectoryItem.self) { ShowPreviewView(item: $0) }
            .navigationDestination(for: Podcast.self) { ShowView(show: $0) }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func state(for show: DirectoryShow) -> FollowState {
        guard let url = show.feedURL?.absoluteString else { return .none }
        if store.podcast(feedURL: url) != nil { return .followed }
        return following.contains(url) ? .following : .none
    }

    private var feedLink: URL? {
        var text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("feed://") { text = "https://" + text.dropFirst("feed://".count) }
        guard let url = URL(string: text), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https", url.host != nil else { return nil }
        return url
    }

    private var looksLikeFeedLink: Bool { feedLink != nil }

    private func search() {
        message = nil
        if let url = feedLink {
            follow(url)
            return
        }
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        searching = true
        Task {
            defer { searching = false }
            do {
                results = try await FeedClient.searchDirectory(term)
                if results.isEmpty { message = "No shows found for “\(term)”." }
            } catch {
                message = "Couldn't search right now. Check your connection and try again."
            }
        }
    }

    private func follow(_ url: URL) {
        let key = url.absoluteString
        guard !following.contains(key) else { return }
        following.insert(key)
        message = nil
        Task {
            defer { following.remove(key) }
            do {
                // An Apple Podcasts link: look up the show's feed first.
                var feedURL = url
                if let appleID = Directory.appleID(fromLink: url) {
                    guard let found = try await FeedClient.lookup(appleID: appleID)?.feedURL else {
                        message = "Couldn't find that show in Apple's directory."
                        return
                    }
                    feedURL = found
                }
                let isNew = store.podcast(feedURL: feedURL.absoluteString) == nil
                let show = try await store.follow(feedURL: feedURL)
                message = "Following \(show.title)."
                if isNew { justFollowed = show }
            } catch {
                message = "Couldn't read that show's feed. (\(error.localizedDescription))"
            }
        }
    }
}

private enum FollowState { case none, following, followed }

