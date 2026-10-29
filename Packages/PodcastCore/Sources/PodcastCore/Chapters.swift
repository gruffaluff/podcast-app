import Foundation

/// A chapter of an episode.
public struct Chapter: Equatable, Hashable, Sendable {
    public var start: TimeInterval
    /// Filled in from the next chapter (or the episode length) when missing.
    public var end: TimeInterval?
    public var title: String
    public var imageURL: URL?
    public var link: URL?

    public init(start: TimeInterval, end: TimeInterval? = nil, title: String, imageURL: URL? = nil, link: URL? = nil) {
        self.start = start
        self.end = end
        self.title = title
        self.imageURL = imageURL
        self.link = link
    }

    public var length: TimeInterval? { end.map { $0 - start } }
}

public enum Chapters {
    /// Reads a Podcasting 2.0 chapters file (`<podcast:chapters>` JSON).
    /// Chapters marked `"toc": false` are left out, as the spec intends.
    public static func parseJSON(_ data: Data) throws -> [Chapter] {
        struct File: Decodable {
            struct Item: Decodable {
                let startTime: Double
                let endTime: Double?
                let title: String?
                let img: String?
                let url: String?
                let toc: Bool?
            }
            let chapters: [Item]
        }
        let file = try JSONDecoder().decode(File.self, from: data)
        let chapters = file.chapters
            .filter { $0.toc != false }
            .map { item in
                Chapter(
                    start: max(0, item.startTime),
                    end: item.endTime,
                    title: item.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                    imageURL: item.img.flatMap(URL.init(string:)),
                    link: item.url.flatMap(URL.init(string:))
                )
            }
        return tidy(chapters, duration: nil)
    }

    /// Sorts chapters, names untitled ones and fills in missing end times.
    public static func tidy(_ chapters: [Chapter], duration: TimeInterval?) -> [Chapter] {
        let sorted = chapters.sorted { $0.start < $1.start }
        return sorted.enumerated().map { index, chapter in
            var chapter = chapter
            if chapter.title.isEmpty { chapter.title = "Chapter \(index + 1)" }
            let nextStart = index + 1 < sorted.count ? sorted[index + 1].start : nil
            if chapter.end == nil || (nextStart.map { chapter.end! > $0 } ?? false) {
                chapter.end = nextStart ?? chapter.end ?? duration
            }
            return chapter
        }
    }

    /// Index of the chapter playing at `time`, if any.
    public static func index(at time: TimeInterval, in chapters: [Chapter]) -> Int? {
        chapters.lastIndex { $0.start <= time + 0.25 }
    }
}
