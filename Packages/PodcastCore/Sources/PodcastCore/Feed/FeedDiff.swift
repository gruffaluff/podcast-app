import Foundation

/// Works out what changed when a show's feed is checked again.
public enum FeedDiff {
    public struct Result: Equatable, Sendable {
        /// Episodes not seen before, to be saved to the library.
        public var added: [ParsedEpisode]
        /// The added episodes that are genuinely new releases, and so may be
        /// auto-added to Up Next. Excludes old episodes a show re-publishes or
        /// back-fills, so Up Next is never flooded.
        public var fresh: [ParsedEpisode]
    }

    /// How far before the newest known episode a newly seen one may be
    /// dated and still count as fresh (feeds sometimes publish late).
    public static let grace: TimeInterval = 2 * 86_400

    /// - Parameters:
    ///   - knownGUIDs: guids of the episodes already saved for this show.
    ///   - newestKnown: publish date of the newest saved episode, or nil
    ///     when the show was only just followed (nothing then counts as fresh).
    public static func compare(_ episodes: [ParsedEpisode], knownGUIDs: Set<String>, newestKnown: Date?) -> Result {
        var seen = knownGUIDs
        var added: [ParsedEpisode] = []
        for episode in episodes where !seen.contains(episode.guid) {
            seen.insert(episode.guid)
            added.append(episode)
        }
        guard let newestKnown else { return Result(added: added, fresh: []) }
        let cutoff = newestKnown.addingTimeInterval(-grace)
        let fresh = added.filter { ($0.published ?? .distantPast) > cutoff }
        return Result(added: added, fresh: fresh)
    }
}
