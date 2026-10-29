import Foundation

/// A stretch of an episode that's an advert or sponsor read.
public struct AdBreak: Codable, Equatable, Hashable, Sendable {
    public var start: TimeInterval
    public var end: TimeInterval
    /// Total cue score; higher means surer.
    public var score: Int

    public init(start: TimeInterval, end: TimeInterval, score: Int) {
        self.start = start
        self.end = end
        self.score = score
    }

    public var length: TimeInterval { end - start }

    public func contains(_ time: TimeInterval) -> Bool { time >= start && time < end }
}

/// Finds ad breaks from what's said (sponsor-read language, promo codes,
/// web addresses) and from audio cues (music around the break). Rule-based,
/// on the iPhone. Must run on a transcript of Paul's own download, because
/// dynamically inserted ads differ per download.
public enum AdDetection {
    /// Phrases and their weight. Strong cues are near-certain on their own.
    static let cues: [(phrase: String, weight: Int)] = [
        ("brought to you by", 3), ("sponsored by", 3), ("is sponsored by", 3), ("our sponsor", 3),
        ("today's sponsor", 3), ("support for this podcast", 3), ("support for this show", 3),
        ("support comes from", 3), ("this episode is supported by", 3), ("thanks to our sponsor", 3),
        ("promo code", 3), ("use code", 3), ("use the code", 3), ("offer code", 3), ("discount code", 3),
        ("free trial", 2), ("% off", 2), ("percent off", 2), ("first month free", 2), ("terms apply", 2),
        ("terms and conditions apply", 2), ("dot com slash", 2), (".com/", 2), ("sign up at", 2),
        ("head to", 1), ("go to", 1), ("visit", 1), ("download the app", 1), ("limited time", 1),
        ("money-back guarantee", 2), ("money back guarantee", 2), ("subscribe to", 1), ("ad-free", 1),
        ("we'll be right back", 2), ("after the break", 2), ("after this break", 2), ("short break", 1),
        ("and now back to", 2), ("back to the show", 2)
    ]

    /// Minimum score for a stretch to count as an ad break.
    public static let minimumScore = 4
    /// Lines this close together join into one break.
    public static let joinGap: TimeInterval = 40

    public static func score(_ text: String) -> Int {
        let lower = text.lowercased()
        return cues.reduce(0) { total, cue in total + (lower.contains(cue.phrase) ? cue.weight : 0) }
    }

    /// Finds breaks. `music` spans next to a break widen it to the music's
    /// edges (jingles often bracket ads). Breaks are 10 seconds to 4 minutes.
    public static func breaks(in lines: [TranscriptLayout.Line], music: [MusicSpan] = []) -> [AdBreak] {
        var found: [AdBreak] = []
        for line in lines {
            let points = score(line.text)
            guard points > 0 else { continue }
            if var last = found.last, line.start - last.end <= joinGap, points >= 1 {
                last.end = max(last.end, line.end)
                last.score += points
                found[found.count - 1] = last
            } else if points >= 2 {
                found.append(AdBreak(start: line.start, end: line.end, score: points))
            }
        }

        return found
            .filter { $0.score >= minimumScore }
            .map { widen($0, lines: lines, music: music) }
            .filter { $0.length >= 10 && $0.length <= 240 }
    }

    /// Combines breaks found separately (e.g. in overlapping slices of audio),
    /// joining ones that overlap or sit within `joinGap` of each other.
    public static func merge(_ existing: [AdBreak], _ found: [AdBreak]) -> [AdBreak] {
        var result: [AdBreak] = []
        for adBreak in (existing + found).sorted(by: { $0.start < $1.start }) {
            if var last = result.last, adBreak.start <= last.end + joinGap / 4 {
                last.end = max(last.end, adBreak.end)
                last.score = max(last.score, adBreak.score)
                result[result.count - 1] = last
            } else {
                result.append(adBreak)
            }
        }
        return result
    }

    /// Starts the break at the line before the first cue if that line is
    /// part of the read ("This episode..."), and stretches to adjoining music.
    static func widen(_ adBreak: AdBreak, lines: [TranscriptLayout.Line], music: [MusicSpan]) -> AdBreak {
        var result = adBreak
        // A short intro line just before ("Quick break.", "Now,") belongs to it.
        if let index = lines.firstIndex(where: { $0.start == adBreak.start }), index > 0 {
            let previous = lines[index - 1]
            if adBreak.start - previous.end < 1.5, previous.text.count < 40 {
                result.start = previous.start
            }
        }
        for span in music {
            if span.end >= result.start - 3, span.start < result.start, result.start - span.start < 30 {
                result.start = span.start
            }
            if span.start <= result.end + 3, span.end > result.end, span.end - result.end < 30 {
                result.end = span.end
            }
        }
        return result
    }
}
