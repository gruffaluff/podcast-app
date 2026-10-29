import Foundation

/// When a played episode's download is deleted.
public enum DownloadCleanup {
    public static let keepWindow: TimeInterval = 24 * 60 * 60

    /// - Parameter keepFor24Hours: the "Keep played downloads for 24 hours" setting.
    public static func shouldDelete(played: Bool, playedAt: Date?, keepFor24Hours: Bool, now: Date = Date()) -> Bool {
        guard played else { return false }
        guard keepFor24Hours, let playedAt else { return true }
        return now.timeIntervalSince(playedAt) >= keepWindow
    }
}
