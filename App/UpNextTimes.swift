import Foundation


/// When each Up Next episode starts at the current speed, and when the
/// whole list is done. The first one (or the one playing) is "now".
enum UpNextTimes {
    static func starts(lengths: [TimeInterval], speed: Double, from now: Date = Date()) -> [Date] {
        var clock = now
        var result: [Date] = []
        for length in lengths {
            result.append(clock)
            clock = clock.addingTimeInterval(length / max(speed, 0.5))
        }
        return result
    }

    static func doneBy(lengths: [TimeInterval], speed: Double, from now: Date = Date()) -> Date {
        now.addingTimeInterval(lengths.reduce(0, +) / max(speed, 0.5))
    }

    /// "19:42".
    static func clock(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }
}
