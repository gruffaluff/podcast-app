import Foundation

/// Dates and lengths as feeds write them, which varies a lot in practice.
public enum FeedDates {
    private static let formats = [
        // RFC 822 (standard for RSS), after any leading day name is removed.
        "d MMM yyyy HH:mm:ss Z",
        "d MMM yyyy HH:mm:ss zzz",
        "d MMM yyyy HH:mm:ss ZZZZZ",
        "d MMM yyyy HH:mm Z",
        "d MMM yyyy HH:mm zzz",
        "d MMM yyyy HH:mm:ss",
        "d MMM yyyy",
        // ISO 8601, used by some generators.
        "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
        "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",
        "yyyy-MM-dd HH:mm:ss Z",
        "yyyy-MM-dd"
    ]

    private static let formatters: [DateFormatter] = formats.map { format in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = format
        return formatter
    }

    /// Parses a `<pubDate>`. The day name is ignored, because feeds often get it wrong.
    public static func date(from string: String) -> Date? {
        var trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let comma = trimmed.firstIndex(of: ","), trimmed[..<comma].allSatisfy(\.isLetter) {
            trimmed = String(trimmed[trimmed.index(after: comma)...]).trimmingCharacters(in: .whitespaces)
        }
        trimmed = trimmed.replacingOccurrences(of: "  ", with: " ")
        guard !trimmed.isEmpty else { return nil }
        for formatter in formatters {
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }

    /// Parses `<itunes:duration>`: plain seconds ("3723"), "62:03" or "1:02:03".
    public static func duration(from string: String) -> TimeInterval? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count <= 3 else { return nil }
        var total: TimeInterval = 0
        for part in parts {
            guard let value = Double(part), value >= 0 else { return nil }
            total = total * 60 + value
        }
        return total > 0 ? total : nil
    }
}
