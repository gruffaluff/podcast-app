import Foundation

/// Makes chapters from a transcript for shows that don't supply any:
/// finds where the topic changes (words used before vs after), preferring
/// pauses, music and ad breaks as boundaries, then names each chapter
/// from its most distinctive words. (The app can replace the names with
/// ones from Apple's on-device language model when available.)
public enum ChapterMaker {
    /// Roughly how long chapters should be.
    public static let targetLength: TimeInterval = 8 * 60
    public static let minimumLength: TimeInterval = 3 * 60

    public static func chapters(lines: [TranscriptLayout.Line], music: [MusicSpan] = [], ads: [AdBreak] = [], duration: TimeInterval) -> [Chapter] {
        guard let first = lines.first, duration > 0 else { return [] }
        let contentLines = lines.filter { line in !ads.contains { $0.contains(line.start) } }

        // Candidate boundaries: the start of each line, scored by topic change
        // plus bonuses for pauses, music and ads just before it.
        var candidates: [(time: TimeInterval, score: Double)] = []
        for index in contentLines.indices.dropFirst() {
            let line = contentLines[index]
            var score = topicShift(at: index, in: contentLines)
            let previous = contentLines[index - 1]
            let gap = line.start - previous.end
            // A gap left by a removed ad isn't a pause (the ad is its own chapter).
            let adBetween = ads.contains { $0.start >= previous.start && $0.end <= line.start + 1 }
            if gap >= 2, !adBetween { score += min(0.4, gap / 10) }
            if music.contains(where: { abs($0.end - line.start) < 5 }) { score += 0.4 }
            candidates.append((line.start, score))
        }

        let wanted = max(1, min(12, Int((duration / targetLength).rounded()))) - 1
        var cuts: [TimeInterval] = []
        for candidate in candidates.sorted(by: { $0.score > $1.score }) where cuts.count < wanted {
            let nearOtherCut = cuts.contains { abs($0 - candidate.time) < minimumLength }
            let nearStart = candidate.time - first.start < minimumLength
            let nearEnd = duration - candidate.time < minimumLength
            if !nearOtherCut && !nearStart && !nearEnd { cuts.append(candidate.time) }
        }
        let starts = ([0] + cuts.sorted())

        var chapters: [Chapter] = []
        for (index, start) in starts.enumerated() {
            let end = index + 1 < starts.count ? starts[index + 1] : duration
            let text = contentLines.filter { $0.start >= start && $0.start < end }.map(\.text)
            chapters.append(Chapter(start: start, end: end, title: ""))
            chapters[chapters.count - 1].title = title(for: text, among: lines.map(\.text), index: index)
        }

        return Chapters.tidy(insertingAds(ads, into: chapters), duration: duration)
    }

    /// Ad breaks become their own chapters, marked as ads; the chapter they
    /// interrupt carries on afterwards.
    static func insertingAds(_ ads: [AdBreak], into chapters: [Chapter]) -> [Chapter] {
        var result = chapters
        for ad in ads.sorted(by: { $0.start < $1.start }) {
            guard let index = result.lastIndex(where: { $0.start <= ad.start }) else { continue }
            let interrupted = result[index]
            let end = interrupted.end ?? ad.end
            result[index].end = ad.start
            var insert = [Chapter(start: ad.start, end: ad.end, title: "Sponsor break", isAd: true)]
            if end - ad.end >= 20 {
                insert.append(Chapter(start: ad.end, end: end, title: interrupted.title))
            }
            if ad.start - interrupted.start < 1 { result.remove(at: index) } else { result[index].end = ad.start }
            let at = ad.start - interrupted.start < 1 ? index : index + 1
            result.insert(contentsOf: insert, at: at)
        }
        return result
    }

    /// 0–1: how different the words in the lines just before are from the
    /// lines just after (counted in lines, so a removed ad doesn't leave a hole).
    static func topicShift(at index: Int, in lines: [TranscriptLayout.Line], window: Int = 6) -> Double {
        let before = words(lines[max(0, index - window)..<index].map(\.text))
        let after = words(lines[index..<min(lines.count, index + window)].map(\.text))
        guard !before.isEmpty, !after.isEmpty else { return 0 }
        return 1 - cosine(before, after)
    }

    /// Up to three distinctive words: "Tides, salt and harbours".
    static func title(for text: [String], among all: [String], index: Int) -> String {
        let here = words(text)
        let everywhere = words(all)
        var scored: [(word: String, score: Double)] = []
        for (word, count) in here where count >= 2 && word.count >= 4 {
            let overall = Double(everywhere[word] ?? 1)
            scored.append((word, Double(count) / overall.squareRoot()))
        }
        scored.sort { a, b in a.score != b.score ? a.score > b.score : a.word < b.word }
        let ranked: [String] = scored.prefix(3).map { $0.word }
        guard !ranked.isEmpty else { return index == 0 ? "Introduction" : "Part \(index + 1)" }
        var list = ranked
        list[0] = list[0].prefix(1).uppercased() + list[0].dropFirst()
        if list.count == 1 { return list[0] }
        return list.dropLast().joined(separator: ", ") + " and " + list.last!
    }

    static func words(_ texts: [String]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for text in texts {
            for raw in text.lowercased().split(whereSeparator: { !$0.isLetter && $0 != "'" }) {
                let word = String(raw).trimmingCharacters(in: CharacterSet(charactersIn: "'"))
                guard word.count >= 3, !stopWords.contains(word) else { continue }
                counts[word, default: 0] += 1
            }
        }
        return counts
    }

    static func cosine(_ a: [String: Int], _ b: [String: Int]) -> Double {
        var dot = 0.0
        for (word, count) in a { dot += Double(count * (b[word] ?? 0)) }
        let normA = a.values.reduce(0.0) { $0 + Double($1 * $1) }.squareRoot()
        let normB = b.values.reduce(0.0) { $0 + Double($1 * $1) }.squareRoot()
        return normA > 0 && normB > 0 ? dot / (normA * normB) : 0
    }

    static let stopWords: Set<String> = [
        "the", "and", "that", "this", "with", "you", "for", "are", "was", "were", "but", "not", "have", "has",
        "had", "they", "them", "their", "there", "then", "than", "what", "when", "where", "which", "who", "why",
        "how", "all", "can", "could", "would", "should", "will", "just", "like", "really", "know", "think",
        "yeah", "yes", "okay", "right", "well", "about", "from", "into", "out", "our", "your", "its", "it's",
        "i'm", "you're", "they're", "we're", "that's", "there's", "don't", "didn't", "doesn't", "isn't",
        "can't", "won't", "kind", "sort", "lot", "lots", "thing", "things", "one", "two", "get", "got", "going",
        "gonna", "want", "said", "say", "says", "see", "also", "very", "much", "more", "some", "any", "been",
        "being", "because", "so", "if", "or", "on", "in", "at", "to", "of", "is", "it", "we", "he", "she",
        "his", "her", "him", "me", "my", "do", "did", "does", "an", "a", "be", "by", "up", "no", "now", "here",
        "actually", "mean", "maybe", "something", "anything", "everything", "people", "time", "way", "good",
        "make", "made", "back", "even", "still", "these", "those", "other", "only", "over", "after",
        "before", "first", "little", "need", "look", "come", "came", "take", "let", "let's", "um", "uh", "oh"
    ]
}
