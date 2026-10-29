import Foundation

/// Choices offered by the player and its settings.
public enum PlayerOptions {
    /// Skip lengths for the back and forward buttons, in seconds.
    public static let skipLengths: [Int] = [5, 10, 15, 30, 60]
    public static let defaultSkip = 10

    /// Playback speeds, 1.0× to 2.0× in steps of 0.1.
    public static let speeds: [Double] = (10...20).map { Double($0) / 10 }

    /// "1×", "1.5×", "2×".
    public static func speedLabel(_ speed: Double) -> String {
        let rounded = (speed * 10).rounded() / 10
        return rounded == rounded.rounded() ? "\(Int(rounded))×" : "\(rounded)×"
    }

    /// Keeps a stored skip length to one of the offered values.
    public static func validSkip(_ seconds: Int) -> Int {
        skipLengths.contains(seconds) ? seconds : defaultSkip
    }
}

/// Sleep timer choices.
public enum SleepTimerOption: Equatable, Hashable, Sendable {
    case minutes(Int)
    case endOfEpisode

    public static let all: [SleepTimerOption] = [.minutes(5), .minutes(15), .minutes(30), .minutes(45), .minutes(60), .endOfEpisode]

    public var label: String {
        switch self {
        case .minutes(let m): return m == 60 ? "1 hour" : "\(m) minutes"
        case .endOfEpisode: return "End of episode"
        }
    }
}
