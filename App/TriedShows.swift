import Foundation
import SwiftData
import PodcastCore

// Try a show without following it (Paul, 16 Nov 2026: "if I click into a
// podcast, I want to be able to add an episode to my queue without
// following the show … try out a show without subscribing if they have a
// particular guest or topic of interest").
//
// An episode from a show you don't follow needs a saved show to belong to
// (playing, downloads, transcripts and Up next all work on saved
// episodes). So the show is saved as a "tried" show: nothing goes to Up
// next by itself (Nowhere), nothing downloads by itself, no alerts, and
// its feed isn't checked. Its feed link is listed in the synced setting
// "triedShows" (one per line), and tried shows are left out of everything
// that lists the shows you follow (Your shows, Find, Search, settings,
// CarPlay, the alerts job, OPML export). Once none of its episodes are in
// Up next, playing or part-played, it's tidied away. Following it later
// turns it into an ordinary followed show.

enum TriedShows {
    static let key = "triedShows"

    static var feeds: Set<String> {
        let raw: String = UserDefaults.standard.string(forKey: key) ?? ""
        return Set(raw.split(separator: "\n").map(String.init).filter { !$0.isEmpty })
    }

    static func isTried(_ feedURL: String) -> Bool {
        feeds.contains(feedURL)
    }

    static func add(_ feedURL: String) {
        var set: Set<String> = feeds
        guard set.insert(feedURL).inserted else { return }
        store(set)
    }

    static func remove(_ feedURL: String) {
        var set: Set<String> = feeds
        guard set.remove(feedURL) != nil else { return }
        store(set)
    }

    private static func store(_ set: Set<String>) {
        UserDefaults.standard.set(set.sorted().joined(separator: "\n"), forKey: key)
    }
}

extension Podcast {
    /// Saved only because one of its episodes was added without following.
    var isTried: Bool { TriedShows.isTried(feedURL) }
}

extension Array where Element == Podcast {
    /// Leaves out shows only being tried (see `TriedShows`).
    var followedOnly: [Podcast] {
        let tried: Set<String> = TriedShows.feeds
        guard !tried.isEmpty else { return self }
        return filter { !tried.contains($0.feedURL) }
    }
}

extension LibraryStore {
    /// A show you follow (not one only being tried).
    func followedPodcast(feedURL: String) -> Podcast? {
        guard let show = podcast(feedURL: feedURL), !show.isTried else { return nil }
        return show
    }

    /// Adds one episode of a show you don't follow to Up next (next, or at
    /// the end). Uses the feed already loaded on the show's page.
    /// Returns false if the episode couldn't be added.
    @discardableResult
    func addWithoutFollowing(feedURL: URL, feed: ParsedFeed, guid: String, next: Bool) -> Bool {
        let key: String = feedURL.absoluteString
        let show: Podcast
        if let existing = podcast(feedURL: key) {
            show = existing
            applyTried(feed, to: show)
        } else {
            show = Podcast(
                feedURL: key,
                title: feed.title,
                author: feed.author ?? "",
                summary: PlainText.notesFromHTML(feed.summary ?? ""),
                artworkURL: feed.artworkURL
            )
            show.autoAddRaw = AutoAddMode.off.rawValue
            show.autoDownload = false
            show.notify = false
            show.website = feed.link
            TriedShows.add(key)
            context.insert(show)
            applyTried(feed, to: show)
        }
        save()
        guard let episode = episode(PodcastEpisode.makeID(feedURL: key, guid: guid)) else { return false }
        undoable(next ? "Playing next" : "Added to Up next", episodes: [episode]) {
            if next { playNext(episode) } else { playLast(episode) }
        }
        return true
    }

    /// Whether the episode with this guid is in Up next.
    func isQueued(feedURL: URL, guid: String) -> Bool {
        let id: String = PodcastEpisode.makeID(feedURL: feedURL.absoluteString, guid: guid)
        return queue.contains { $0.episode.id == id }
    }

    /// Following a show that was only being tried: it becomes an ordinary
    /// followed show (Bottom, downloads on), followed from now.
    func promoteTried(_ show: Podcast) {
        guard show.isTried else { return }
        TriedShows.remove(show.feedURL)
        show.autoAddRaw = AutoAddMode.bottom.rawValue
        show.autoDownload = true
        show.followedAt = Date()
        save()
    }

    /// Tidies away tried shows none of whose episodes are in Up next,
    /// playing or part-played. Runs with each feed check.
    func pruneTriedShows() {
        let tried: Set<String> = TriedShows.feeds
        guard !tried.isEmpty else { return }
        let queued: Set<String> = Set(queue.map(\.episode.id))
        for feed in tried {
            guard let show = podcast(feedURL: feed) else {
                TriedShows.remove(feed)
                continue
            }
            let inUse: Bool = show.episodes.contains { episode in
                queued.contains(episode.episodeID)
                    || episode.episodeID == playingEpisodeID
                    || (!episode.played && episode.position > 30)
            }
            if !inUse {
                TriedShows.remove(feed)
                unfollow(show)
            }
        }
    }

    /// Saves the feed's episodes on a tried show (none go to Up next).
    private func applyTried(_ feed: ParsedFeed, to show: Podcast) {
        let known: Set<String> = Set(show.episodes.map(\.guid))
        for parsed in feed.episodes where !known.contains(parsed.guid) {
            let episode = PodcastEpisode(
                episodeID: PodcastEpisode.makeID(feedURL: show.feedURL, guid: parsed.guid),
                guid: parsed.guid,
                title: parsed.title,
                summary: PlainText.notesFromHTML(parsed.summary ?? ""),
                published: parsed.published ?? .distantPast,
                audioURL: parsed.audioURL
            )
            episode.duration = parsed.duration
            episode.artworkURL = parsed.artworkURL
            let transcript = TranscriptParser.preferred(parsed.transcripts)
            episode.transcriptURL = transcript?.url
            episode.transcriptType = transcript?.type
            episode.chaptersURL = parsed.chaptersURL
            episode.webLink = parsed.link
            context.insert(episode)
            episode.podcast = show
        }
        show.lastChecked = Date()
    }
}
