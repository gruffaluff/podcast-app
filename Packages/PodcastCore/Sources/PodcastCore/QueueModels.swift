import Foundation

/// A podcast episode, as far as the queue needs to know.
public struct Episode: Equatable, Hashable, Sendable {
    public let id: String
    public let showID: String
    public let title: String
    public let published: Date

    public init(id: String, showID: String, title: String, published: Date) {
        self.id = id
        self.showID = showID
        self.title = title
        self.published = published
    }
}

/// How an episode got into Up Next.
public enum QueueSource: Equatable, Hashable, Sendable {
    /// Added automatically because its show is set to Top or Bottom.
    case auto
    /// Added by Paul with Play next / Play last.
    case manual
}

public struct QueueItem: Equatable, Hashable, Sendable {
    public let episode: Episode
    public let source: QueueSource

    public init(episode: Episode, source: QueueSource) {
        self.episode = episode
        self.source = source
    }
}

/// Per-show auto-add setting.
public enum AutoAddMode: String, Equatable, Hashable, Sendable, CaseIterable {
    case off, top, bottom
}

/// The settings that drive queue ordering.
public struct QueueSettings: Equatable, Sendable {
    /// Auto-add mode per show ID. Shows not listed are `.off`.
    public var modes: [String: AutoAddMode]
    /// Top shows in priority order, favourite first.
    public var topRank: [String]
    /// When on, Play next / Play last never put an episode before an older
    /// episode of the same show (or after a newer one).
    public var keepShowOrder: Bool

    public init(modes: [String: AutoAddMode] = [:], topRank: [String] = [], keepShowOrder: Bool = true) {
        self.modes = modes
        self.topRank = topRank
        self.keepShowOrder = keepShowOrder
    }

    public func mode(for showID: String) -> AutoAddMode {
        modes[showID] ?? .off
    }

    /// Rank of a Top show; 0 is the favourite. Top shows missing from the
    /// ranking count as lowest priority.
    public func rank(of showID: String) -> Int {
        topRank.firstIndex(of: showID) ?? Int.max
    }
}
