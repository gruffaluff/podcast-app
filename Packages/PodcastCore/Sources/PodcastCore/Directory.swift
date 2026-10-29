import Foundation

/// A show from Apple's free podcast directory (the iTunes Search API).
public struct DirectoryShow: Decodable, Equatable, Hashable, Sendable, Identifiable {
    public let collectionId: Int
    public let collectionName: String
    public let artistName: String?
    public let feedUrl: String?
    public let artworkUrl600: String?
    public let artworkUrl100: String?
    public let primaryGenreName: String?

    public var id: Int { collectionId }
    public var feedURL: URL? { feedUrl.flatMap(URL.init(string:)) }
    public var artworkURL: URL? { (artworkUrl600 ?? artworkUrl100).flatMap(URL.init(string:)) }
}

public enum Directory {
    /// Search URL for shows matching `term` (show names, people, topics).
    public static func searchURL(term: String, country: String = "GB", limit: Int = 25) -> URL {
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "media", value: "podcast"),
            URLQueryItem(name: "entity", value: "podcast"),
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return components.url!
    }

    /// Reads a search response, dropping shows that have no public feed.
    public static func decodeSearch(_ data: Data) throws -> [DirectoryShow] {
        struct Response: Decodable { let results: [DirectoryShow] }
        return try JSONDecoder().decode(Response.self, from: data).results.filter { $0.feedURL != nil }
    }
}
