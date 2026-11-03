import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// OPML: the file podcast apps use to move a list of shows between them
/// (Pocket Casts, Overcast, Castro, Spotify-free apps…). Each show is an
/// `<outline type="rss" xmlUrl="…">`, sometimes inside folders.
public enum OPML {
    public struct Show: Equatable, Sendable {
        public var title: String
        public var feedURL: URL

        public init(title: String, feedURL: URL) {
            self.title = title
            self.feedURL = feedURL
        }
    }

    public enum Failure: LocalizedError, Equatable {
        case noShows
        public var errorDescription: String? {
            "This file doesn't list any podcasts. Export an OPML file from your other podcast app and try again."
        }
    }

    /// Shows in an OPML file, in file order, without repeats.
    public static func parse(_ data: Data) throws -> [Show] {
        let reader = OPMLReader()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = false
        parser.shouldResolveExternalEntities = false
        parser.delegate = reader
        parser.parse()
        guard !reader.shows.isEmpty else { throw Failure.noShows }
        return reader.shows
    }

    /// An OPML file listing `shows`.
    public static func make(_ shows: [Show], title: String = "Podspot shows", date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        var lines = [
            #"<?xml version="1.0" encoding="UTF-8"?>"#,
            #"<opml version="2.0">"#,
            "  <head>",
            "    <title>\(escape(title))</title>",
            "    <dateCreated>\(formatter.string(from: date))</dateCreated>",
            "  </head>",
            "  <body>",
        ]
        for show in shows {
            let name = escape(show.title)
            lines.append(#"    <outline type="rss" text="\#(name)" title="\#(name)" xmlUrl="\#(escape(show.feedURL.absoluteString))"/>"#)
        }
        lines += ["  </body>", "</opml>", ""]
        return lines.joined(separator: "\n")
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

private final class OPMLReader: NSObject, XMLParserDelegate {
    var shows: [OPML.Show] = []
    private var seen = Set<String>()

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        guard name.lowercased() == "outline" else { return }
        // Attribute names vary in case between apps (xmlUrl, xmlURL, xmlurl).
        var lower: [String: String] = [:]
        for (key, value) in attributes { lower[key.lowercased()] = value }
        guard let link = lower["xmlurl"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: link), let scheme = url.scheme?.lowercased(),
              ["http", "https", "feed", "itpc", "pcast"].contains(scheme) else { return }
        let feedURL = Self.normalised(url)
        guard seen.insert(feedURL.absoluteString).inserted else { return }
        let title = [lower["title"], lower["text"]].compactMap { $0 }.first { !$0.isEmpty } ?? feedURL.host ?? "Podcast"
        shows.append(OPML.Show(title: title, feedURL: feedURL))
    }

    /// `feed://`, `itpc://` and `pcast://` links are web feeds really.
    private static func normalised(_ url: URL) -> URL {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = parts.scheme?.lowercased(), scheme != "http", scheme != "https" else { return url }
        parts.scheme = "https"
        return parts.url ?? url
    }
}
