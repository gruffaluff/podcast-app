import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// Reads a podcast RSS feed: RSS 2.0, iTunes tags and the Podcasting 2.0
/// transcript and chapters tags.
///
/// Elements are matched by their usual prefixes (`itunes:`, `podcast:`,
/// `content:`), which nearly every feed uses.
public enum FeedParser {
    public static func parse(_ data: Data) throws -> ParsedFeed {
        let reader = FeedReader()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = false
        parser.shouldResolveExternalEntities = false
        parser.delegate = reader
        parser.parse()
        // Be forgiving: a feed with a stray bad character near the end still
        // gives us everything read up to that point.
        guard let feed = reader.result() else { throw FeedError.notAFeed }
        return feed
    }
}

private final class FeedReader: NSObject, XMLParserDelegate {
    private struct ItemBuilder {
        var guid: String?
        var title: String?
        var itunesTitle: String?
        var description: String?
        var itunesSummary: String?
        var contentEncoded: String?
        var published: Date?
        var audioURL: URL?
        var audioType: String?
        var audioBytes: Int64?
        var duration: TimeInterval?
        var artworkURL: URL?
        var link: URL?
        var transcripts: [TranscriptLink] = []
        var chaptersURL: URL?
    }

    private var stack: [String] = []
    private var text = ""
    private var sawChannel = false

    private var title: String?
    private var author: String?
    private var channelDescription: String?
    private var itunesSummary: String?
    private var itunesImage: URL?
    private var rssImage: URL?
    private var link: URL?
    private var episodes: [ParsedEpisode] = []
    private var item: ItemBuilder?

    func result() -> ParsedFeed? {
        guard sawChannel, title != nil || !episodes.isEmpty else { return nil }
        return ParsedFeed(
            title: title ?? "Untitled show",
            author: author,
            summary: channelDescription ?? itunesSummary,
            artworkURL: itunesImage ?? rssImage,
            link: link,
            episodes: episodes
        )
    }

    // MARK: XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String] = [:]) {
        let key = elementName.lowercased()
        stack.append(key)
        text = ""

        switch key {
        case "channel":
            sawChannel = true
        case "item":
            item = ItemBuilder()
        case "enclosure":
            guard item != nil, item?.audioURL == nil, let url = Self.url(attributes["url"]) else { break }
            item?.audioURL = url
            item?.audioType = attributes["type"]
            item?.audioBytes = attributes["length"].flatMap { Int64($0.trimmingCharacters(in: .whitespaces)) }
        case "itunes:image":
            let url = Self.url(attributes["href"])
            if item != nil {
                item?.artworkURL = url ?? item?.artworkURL
            } else if parent == "channel" {
                itunesImage = url ?? itunesImage
            }
        case "podcast:transcript":
            guard item != nil, let url = Self.url(attributes["url"]) else { break }
            item?.transcripts.append(TranscriptLink(url: url, type: attributes["type"], language: attributes["language"]))
        case "podcast:chapters":
            guard item != nil, let url = Self.url(attributes["url"]) else { break }
            item?.chaptersURL = url
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let key = stack.popLast() ?? elementName.lowercased()
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        text = ""

        if item != nil {
            endItemElement(key, value: value)
        } else {
            endChannelElement(key, value: value)
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let string = String(data: CDATABlock, encoding: .utf8) {
            text += string
        }
    }

    // MARK: Elements

    /// The element containing the current one.
    private var parent: String? {
        stack.count >= 2 ? stack[stack.count - 2] : nil
    }

    private func endItemElement(_ key: String, value: String) {
        // Only direct children of <item> count (not, say, <image><title>).
        guard key == "item" || stack.last == "item" else { return }
        let nonEmpty = value.isEmpty ? nil : value

        switch key {
        case "item":
            finishItem()
        case "guid": item?.guid = nonEmpty
        case "title": item?.title = nonEmpty
        case "itunes:title": item?.itunesTitle = nonEmpty
        case "description": item?.description = nonEmpty
        case "itunes:summary": item?.itunesSummary = nonEmpty
        case "content:encoded": item?.contentEncoded = nonEmpty
        case "pubdate": item?.published = FeedDates.date(from: value)
        case "itunes:duration": item?.duration = FeedDates.duration(from: value)
        case "link": item?.link = Self.url(value)
        default: break
        }
    }

    private func endChannelElement(_ key: String, value: String) {
        let nonEmpty = value.isEmpty ? nil : value
        switch (key, stack.last) {
        case ("title", "channel"): title = nonEmpty
        case ("itunes:author", "channel"): author = nonEmpty
        case ("description", "channel"): channelDescription = nonEmpty
        case ("itunes:summary", "channel"): itunesSummary = nonEmpty
        case ("link", "channel"): link = Self.url(value) ?? link
        case ("url", "image"):
            if stack.dropLast().last == "channel" { rssImage = Self.url(value) }
        default: break
        }
    }

    private func finishItem() {
        defer { item = nil }
        guard let built = item, let audioURL = built.audioURL else { return }
        episodes.append(ParsedEpisode(
            guid: built.guid ?? audioURL.absoluteString,
            title: built.title ?? built.itunesTitle ?? "Untitled episode",
            summary: built.description ?? built.contentEncoded ?? built.itunesSummary,
            published: built.published,
            audioURL: audioURL,
            audioType: built.audioType,
            audioBytes: built.audioBytes,
            duration: built.duration,
            artworkURL: built.artworkURL,
            link: built.link,
            transcripts: built.transcripts,
            chaptersURL: built.chaptersURL
        ))
    }

    static func url(_ string: String?) -> URL? {
        guard let trimmed = string?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil { return url }
        // Some feeds put spaces or other unescaped characters in URLs.
        if let escaped = trimmed.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed),
           let url = URL(string: escaped), url.scheme != nil {
            return url
        }
        return nil
    }
}
