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
