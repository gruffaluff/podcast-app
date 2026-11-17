import Foundation

/// How each show has moved in a chart since an earlier day's chart, kept
/// on this iPhone (Apple's chart feed has no movement). The first day a
/// chart is seen there are no marks; after that, NEW for shows that
/// weren't in the earlier one.
enum ChartHistory {
    enum Move: Equatable {
        case up(Int), down(Int), same, new
    }

    private struct Saved: Codable {
        var day: String
        var ranks: [String: Int]
        var previous: [String: Int]?
    }

    /// Saves today's ranks (moving the last day's to "previous" on a new
    /// day) and returns each show's move against the previous day's.
    static func record(key: String, ids: [String], now: Date = Date()) -> [String: Move] {
        let defaults = UserDefaults.standard
        let storageKey = "chartHistory." + key
        let today = dayString(now)
        var saved: Saved? = defaults.data(forKey: storageKey).flatMap { try? JSONDecoder().decode(Saved.self, from: $0) }
        var ranks: [String: Int] = [:]
        for (index, id) in ids.enumerated() where ranks[id] == nil {
            ranks[id] = index + 1
        }
        if var current = saved {
            if current.day != today {
                current.previous = current.ranks
                current.day = today
            }
            current.ranks = ranks
            saved = current
        } else {
            saved = Saved(day: today, ranks: ranks, previous: nil)
        }
        if let saved, let data = try? JSONEncoder().encode(saved) {
            defaults.set(data, forKey: storageKey)
        }
        guard let previous = saved?.previous, !previous.isEmpty else { return [:] }
        var moves: [String: Move] = [:]
        for (id, rank) in ranks {
            if let before = previous[id] {
                if before > rank {
                    moves[id] = .up(before - rank)
                } else if before < rank {
                    moves[id] = .down(rank - before)
                } else {
                    moves[id] = .same
                }
            } else {
                moves[id] = .new
            }
        }
        return moves
    }

    private static func dayString(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}
