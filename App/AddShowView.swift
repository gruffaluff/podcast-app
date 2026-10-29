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
                        Label("Follow this feed link", systemImage: "link")
                    }
                    .foregroundStyle(Theme.accentText)
                    .listRowBackground(Theme.background)
                }
                ForEach(results) { show in
                    ResultRow(show: show, state: state(for: show)) {
                        if let url = show.feedURL { follow(url) }
                    }
                    .listRowBackground(Theme.background)
                    .listRowSeparatorTint(Theme.hairline)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .overlay {
                if searching {
                    ProgressView()
                } else if results.isEmpty && !looksLikeFeedLink && message == nil {
                    Text("Search by show name, person or topic, or paste an RSS feed link.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .padding(32)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Shows, people, topics or a feed link")
            .textInputAutocapitalization(.never)
            .onSubmit(of: .search) { search() }
            .navigationTitle("Add a show")
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
                let show = try await store.follow(feedURL: url)
                message = "Following \(show.title)."
            } catch {
                message = "Couldn't read that show's feed. (\(error.localizedDescription))"
            }
        }
    }
}

private enum FollowState { case none, following, followed }

private struct ResultRow: View {
    let show: DirectoryShow
    let state: FollowState
    let follow: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ArtworkView(url: show.artworkURL, title: show.collectionName)
            VStack(alignment: .leading, spacing: 3) {
                Text(show.collectionName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                Text([show.artistName, show.primaryGenreName].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            switch state {
            case .none:
                Button("Follow", action: follow)
                    .buttonStyle(.bordered)
                    .tint(Theme.ink)
            case .following:
                ProgressView()
                    .frame(width: 44, height: 44)
            case .followed:
                Image(systemName: "checkmark")
                    .foregroundStyle(Theme.accentText)
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("Following")
            }
        }
        .padding(.vertical, 6)
    }
}
