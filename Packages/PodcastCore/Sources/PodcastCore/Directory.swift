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
    public let genreIds: [String]?

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

/// A show as Discover lists it, from a search, a chart or a lookup.
/// Charts don't include the feed address, so it's looked up when following.
public struct DirectoryItem: Equatable, Hashable, Sendable, Identifiable {
    public var appleID: String
    public var title: String
    public var artist: String?
    public var artworkURL: URL?
    public var feedURL: URL?
    public var genre: String?

    public var id: String { appleID }

    public init(appleID: String, title: String, artist: String? = nil, artworkURL: URL? = nil, feedURL: URL? = nil, genre: String? = nil) {
        self.appleID = appleID
        self.title = title
        self.artist = artist
        self.artworkURL = artworkURL
        self.feedURL = feedURL
        self.genre = genre
    }

    public init(_ show: DirectoryShow) {
        self.init(appleID: String(show.collectionId), title: show.collectionName, artist: show.artistName,
                  artworkURL: show.artworkURL, feedURL: show.feedURL, genre: show.primaryGenreName)
    }
}

/// Apple's podcast categories, as used by its charts.
public struct PodcastGenre: Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String

    private static let names: [(String, String)] = [
        ("1489", "News"), ("1488", "True Crime"), ("1303", "Comedy"), ("1324", "Society & Culture"),
        ("1487", "History"), ("1533", "Science"), ("1321", "Business"), ("1318", "Technology"),
        ("1545", "Sports"), ("1512", "Health & Fitness"), ("1304", "Education"), ("1301", "Arts"),
        ("1309", "TV & Film"), ("1310", "Music"), ("1483", "Fiction"), ("1502", "Leisure"),
        ("1305", "Kids & Family"), ("1314", "Religion & Spirituality"), ("1511", "Government")
    ]

    public static let all: [PodcastGenre] = names.map { PodcastGenre(id: $0.0, name: $0.1) }

    public static func named(_ name: String?) -> PodcastGenre? {
        all.first { $0.name.caseInsensitiveCompare(name ?? "") == .orderedSame }
    }
}

public extension Directory {
    /// Look up a show by its Apple ID (to get its feed address).
    static func lookupURL(appleID: String, country: String = "GB") -> URL {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [
            URLQueryItem(name: "id", value: appleID),
            URLQueryItem(name: "entity", value: "podcast"),
            URLQueryItem(name: "country", value: country)
        ]
        return components.url!
    }

    /// Apple's top shows chart for a country (all categories).
    static func topChartURL(country: String = "gb", limit: Int = 25) -> URL {
        URL(string: "https://rss.marketingtools.apple.com/api/v2/\(country)/podcasts/top/\(limit)/podcasts.json")!
    }

    /// Apple's older chart feed, which can be filtered by category.
    static func genreChartURL(genreID: String, country: String = "gb", limit: Int = 25) -> URL {
        URL(string: "https://itunes.apple.com/\(country)/rss/toppodcasts/limit=\(limit)/genre=\(genreID)/json")!
    }

    /// Reads the top chart (marketing tools feed).
    static func decodeTopChart(_ data: Data) throws -> [DirectoryItem] {
        struct Response: Decodable {
            struct Feed: Decodable {
                struct Result: Decodable {
                    struct Genre: Decodable { let name: String? }
                    let id: String
                    let name: String
                    let artistName: String?
                    let artworkUrl100: String?
                    let genres: [Genre]?
                }
                let results: [Result]
            }
            let feed: Feed
        }
        return try JSONDecoder().decode(Response.self, from: data).feed.results.map { result in
            DirectoryItem(appleID: result.id, title: result.name, artist: result.artistName,
                          artworkURL: largerArtwork(result.artworkUrl100), genre: result.genres?.first?.name)
        }
    }

    /// Reads the category chart (older iTunes feed).
    static func decodeGenreChart(_ data: Data) throws -> [DirectoryItem] {
        struct Label: Decodable { let label: String }
        struct Entry: Decodable {
            struct ID: Decodable {
                struct Attributes: Decodable {
                    let id: String
                    enum CodingKeys: String, CodingKey { case id = "im:id" }
                }
                let attributes: Attributes
            }
            struct Category: Decodable {
                struct Attributes: Decodable { let label: String? }
                let attributes: Attributes
            }
            let name: Label
            let artist: Label?
            let image: [Label]?
            let id: ID
            let category: Category?
            enum CodingKeys: String, CodingKey {
                case name = "im:name", artist = "im:artist", image = "im:image", id, category
            }
        }
        struct Response: Decodable {
            struct Feed: Decodable {
                let entry: [Entry]
                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    // A one-show chart has a single entry rather than a list.
                    if let list = try? container.decode([Entry].self, forKey: .entry) {
                        entry = list
                    } else if let single = try? container.decode(Entry.self, forKey: .entry) {
                        entry = [single]
                    } else {
                        entry = []
                    }
                }
                enum CodingKeys: String, CodingKey { case entry }
            }
            let feed: Feed
        }
        return try JSONDecoder().decode(Response.self, from: data).feed.entry.map { entry in
            DirectoryItem(appleID: entry.id.attributes.id, title: entry.name.label, artist: entry.artist?.label,
                          artworkURL: largerArtwork(entry.image?.last?.label), genre: entry.category?.attributes.label)
        }
    }

    /// Chart artwork comes small ("100x100bb"); ask for 600px instead.
    static func largerArtwork(_ string: String?) -> URL? {
        guard let string else { return nil }
        let larger = string.replacingOccurrences(of: #"/\d+x\d+bb\."#, with: "/600x600bb.", options: .regularExpression)
        return URL(string: larger)
    }
}
