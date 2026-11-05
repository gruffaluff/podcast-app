import Foundation

/// This week's listening summary for Stats: time listened, time saved by
/// speed and trimmed silences, and ads skipped. Kept on the iPhone per week
/// (Monday to Sunday); older weeks are dropped.
enum WeekStats {
    struct Week: Codable, Equatable {
        var listened: TimeInterval = 0
        /// Episode time covered while listening (more than `listened` when
        /// sped up or trimming).
        var episodeTime: TimeInterval = 0
        var adsSkipped = 0
        var adSeconds: TimeInterval = 0

        var saved: TimeInterval { max(0, episodeTime - listened) }
    }

    private static let key = "weekStats"

    static var current: Week {
        guard let data = UserDefaults.standard.data(forKey: key),
              let stored = try? JSONDecoder().decode([String: Week].self, from: data) else { return Week() }
        return stored[weekKey()] ?? Week()
    }

    static func addListening(real: TimeInterval, episodeTime: TimeInterval) {
        update { week in
            week.listened += real
            week.episodeTime += episodeTime
        }
    }

    static func addSkippedAd(seconds: TimeInterval) {
        update { week in
            week.adsSkipped += 1
            week.adSeconds += seconds
        }
    }

    private static func update(_ change: (inout Week) -> Void) {
        let thisWeek = weekKey()
        var stored: [String: Week] = [:]
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: Week].self, from: data) {
            stored = decoded
        }
        var week = stored[thisWeek] ?? Week()
        change(&week)
        // Only this week is kept.
        stored = [thisWeek: week]
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func weekKey(_ date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let parts = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(parts.yearForWeekOfYear ?? 0)-\(parts.weekOfYear ?? 0)"
    }
}
