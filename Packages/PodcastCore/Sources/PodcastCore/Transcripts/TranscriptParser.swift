import Foundation

/// Reads publisher transcripts: WebVTT, SRT and Podcasting 2.0 JSON.
public enum TranscriptParser {
    public enum Failure: Error, Equatable {
        case unsupported
    }

    /// The best of a feed's transcript links: JSON (often has speakers and
    /// exact times), then WebVTT, then SRT. HTML and plain text have no
    /// timings and are not used.
    public static func preferred(_ links: [TranscriptLink]) -> TranscriptLink? {
        func rank(_ link: TranscriptLink) -> Int? {
            let type = (link.type ?? "").lowercased()
            let ext = link.url.pathExtension.lowercased()
            if type.contains("json") || ext == "json" { return 0 }
            if type.contains("vtt") || ext == "vtt" { return 1 }
            if type.contains("srt") || type.contains("subrip") || ext == "srt" { return 2 }
            return nil
        }
        return links.compactMap { link in rank(link).map { ($0, link) } }.min { $0.0 < $1.0 }?.1
    }

    /// Parses any supported format, recognising it from its content.
    public static func parse(_ data: Data) throws -> [TranscriptSegment] {
        let text = String(decoding: data, as: UTF8.self)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{FEFF}")))
        if trimmed.hasPrefix("{") { return try parseJSON(data) }
        if trimmed.hasPrefix("WEBVTT") { return parseCues(trimmed, vtt: true) }
        if trimmed.contains("-->") { return parseCues(trimmed, vtt: false) }
        throw Failure.unsupported
    }

    /// Podcasting 2.0 JSON: `{"segments": [{"speaker", "startTime", "endTime", "body"}]}`.
    public static func parseJSON(_ data: Data) throws -> [TranscriptSegment] {
        struct File: Decodable {
            struct Segment: Decodable {
                let speaker: String?
                let startTime: Double
                let endTime: Double?
                let body: String?
            }
            let segments: [Segment]
        }
        let file = try JSONDecoder().decode(File.self, from: data)
        return file.segments.compactMap { segment in
            let body = (segment.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { return nil }
            let speaker = segment.speaker?.trimmingCharacters(in: .whitespacesAndNewlines)
            return TranscriptSegment(
                start: segment.startTime,
                end: segment.endTime ?? segment.startTime,
                speaker: (speaker?.isEmpty ?? true) ? nil : speaker,
                text: body
            )
        }
    }

    /// WebVTT and SRT: blocks of a timing line ("00:01:02.500 --> 00:01:05.000")
    /// followed by text. WebVTT voice tags (`<v Name>`) become the speaker.
    static func parseCues(_ text: String, vtt: Bool) -> [TranscriptSegment] {
        let normalised = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var segments: [TranscriptSegment] = []
        for block in normalised.components(separatedBy: "\n\n") {
            let lines = block.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
            guard let timingIndex = lines.firstIndex(where: { $0.contains("-->") }) else { continue }
            let parts = lines[timingIndex].components(separatedBy: "-->")
            guard parts.count == 2,
                  let start = timestamp(parts[0]),
                  let end = timestamp(parts[1].split(separator: " ", omittingEmptySubsequences: true).first.map(String.init) ?? "") else { continue }
            var speaker: String?
            var textLines: [String] = []
            for line in lines[(timingIndex + 1)...] {
                if vtt, speaker == nil, let voice = voiceName(line) { speaker = voice }
                let clean = stripTags(line)
                if !clean.isEmpty { textLines.append(clean) }
            }
            let body = textLines.joined(separator: " ")
            guard !body.isEmpty else { continue }
            segments.append(TranscriptSegment(start: start, end: end, speaker: speaker, text: body))
        }
        return segments
    }

    /// "01:02:03.500", "02:03.500" or "01:02:03,500" in seconds.
    static func timestamp(_ string: String) -> TimeInterval? {
        let trimmed = string.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        let parts = trimmed.split(separator: ":")
        guard (2...3).contains(parts.count) else { return nil }
        var total: TimeInterval = 0
        for part in parts {
            guard let value = Double(part) else { return nil }
            total = total * 60 + value
        }
        return total
    }

    private static func voiceName(_ line: String) -> String? {
        guard let range = line.range(of: "<v[^>]*>", options: .regularExpression) else { return nil }
        var tag = String(line[range].dropFirst(2).dropLast())
        // "<v.loud Name>" carries classes before the space.
        if tag.hasPrefix("."), let space = tag.firstIndex(of: " ") { tag = String(tag[space...]) }
        let name = tag.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    private static func stripTags(_ line: String) -> String {
        PlainText.fromHTML(line)
    }
}
