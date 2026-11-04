import Foundation

/// Lengths and clock times as the app shows them.
public enum TimeFormat {
    /// An episode length: "45m", "1h 12m", "2h".
    public static func length(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "" }
        let minutes = max(1, Int((seconds / 60).rounded()))
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(minutes)m" }
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
    }

    /// A player clock: "4:05" or "1:02:03".
    public static func clock(_ seconds: TimeInterval) -> String {
        let total = seconds.isFinite ? max(0, Int(seconds)) : 0
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        let mm = minutes < 10 && hours > 0 ? "0\(minutes)" : "\(minutes)"
        let ss = secs < 10 ? "0\(secs)" : "\(secs)"
        return hours > 0 ? "\(hours):\(mm):\(ss)" : "\(mm):\(ss)"
    }

    /// A transcript timestamp heading: "45s", "1m 20s", "1h 2m 5s".
    public static func stamp(_ seconds: TimeInterval) -> String {
        let total = seconds.isFinite ? max(0, Int(seconds)) : 0
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        if h > 0 { return "\(h)h \(m)m \(s)s" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }

    /// How long ago something happened: "Just now", "4h ago", "3d ago",
    /// then a plain date such as "12 Oct".
    public static func ago(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 * 60 {
            let minutes = Int(seconds / 60)
            return minutes < 1 ? "Just now" : "\(minutes)m ago"
        }
        if seconds < 24 * 60 * 60 { return "\(Int(seconds / 3600))h ago" }
        if seconds < 7 * 24 * 60 * 60 { return "\(Int(seconds / 86_400))d ago" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = calendar.isDate(date, equalTo: now, toGranularity: .year) ? "d MMM" : "d MMM yyyy"
        return formatter.string(from: date)
    }
}

/// Turns the HTML that feeds put in descriptions into plain text.
public enum PlainText {
    public static func fromHTML(_ html: String) -> String {
        var text = html.replacingOccurrences(of: "<(br|/p|/div|/li)[^>]*>", with: " ", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = decodeEntities(text)
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Show notes as readable text: paragraphs and line breaks kept, list
    /// items as "• ", links' web addresses kept so they can be tapped,
    /// spaces tidied. Plain-text notes keep their own line breaks.
    public static func notesFromHTML(_ html: String) -> String {
        var text = html.replacingOccurrences(of: "\r\n?", with: "\n", options: .regularExpression)
        let isHTML = text.range(of: "<[a-zA-Z/][^>]*>", options: .regularExpression) != nil
        if isHTML {
            // In HTML, line breaks in the source are just spaces.
            text = text.replacingOccurrences(of: "\n", with: " ")
            // A link whose text differs from its address: keep the address.
            text = text.replacingOccurrences(
                of: "<a\\s[^>]*href=[\"']([^\"']+)[\"'][^>]*>(.*?)</a>",
                with: "$2 ($1)", options: [.regularExpression, .caseInsensitive])
            text = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])
            text = text.replacingOccurrences(of: "<li[^>]*>", with: "\n• ", options: [.regularExpression, .caseInsensitive])
            text = text.replacingOccurrences(of: "</(p|div|h[1-6]|ul|ol|blockquote)>", with: "\n\n", options: [.regularExpression, .caseInsensitive])
            text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        }
        text = decodeEntities(text)
        // "word (word)" when a link's text was its own address.
        text = text.replacingOccurrences(of: "(https?://\\S+) \\(\\1\\)", with: "$1", options: .regularExpression)
        let lines = text.components(separatedBy: "\n").map {
            $0.replacingOccurrences(of: "[ \t\u{00A0}]+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
        }
        // At most one blank line between paragraphs.
        var result: [String] = []
        for line in lines {
            if line.isEmpty && (result.last?.isEmpty ?? true) { continue }
            result.append(line)
        }
        while result.last?.isEmpty == true { result.removeLast() }
        return result.joined(separator: "\n")
    }

    private static let named: [String: String] = [
        "quot": "\"", "apos": "'", "lt": "<", "gt": ">", "nbsp": " ",
        "ndash": "–", "mdash": "—", "hellip": "…", "rsquo": "’", "lsquo": "‘",
        "rdquo": "”", "ldquo": "“", "pound": "£", "euro": "€", "amp": "&"
    ]

    static func decodeEntities(_ string: String) -> String {
        guard string.contains("&") else { return string }
        var result = ""
        var rest = Substring(string)
        while let amp = rest.firstIndex(of: "&") {
            result += rest[..<amp]
            let afterAmp = rest.index(after: amp)
            if let semi = rest[afterAmp...].prefix(10).firstIndex(of: ";"),
               let decoded = decodeEntity(String(rest[afterAmp..<semi])) {
                result += decoded
                rest = rest[rest.index(after: semi)...]
            } else {
                result += "&"
                rest = rest[afterAmp...]
            }
        }
        result += rest
        return result
    }

    private static func decodeEntity(_ name: String) -> String? {
        if name.hasPrefix("#x") || name.hasPrefix("#X") {
            return UInt32(name.dropFirst(2), radix: 16).flatMap { Unicode.Scalar($0) }.map { String(Character($0)) }
        }
        if name.hasPrefix("#") {
            return UInt32(name.dropFirst()).flatMap { Unicode.Scalar($0) }.map { String(Character($0)) }
        }
        return named[name.lowercased()]
    }
}
