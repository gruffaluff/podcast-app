import Foundation

/// Plans "find ads while listening": which slice of the downloaded audio
/// to check next, a few minutes ahead of where Paul is listening, so a
/// Skip ad button is ready when an ad starts, without transcribing the
/// whole episode.
public enum AdScanPlan {
    /// Length of each slice checked.
    public static let sliceLength: TimeInterval = 150
    /// How far ahead of the playhead to stay checked.
    public static let lookahead: TimeInterval = 240
    /// Slices overlap a little so an ad on a boundary isn't missed.
    public static let overlap: TimeInterval = 20

    /// The next slice to check, or nil when everything just ahead is done.
    public static func nextSlice(playhead: TimeInterval, scanned: [ClosedRange<TimeInterval>], duration: TimeInterval) -> ClosedRange<TimeInterval>? {
        guard duration > 0 else { return nil }
        let windowEnd = min(duration, playhead + lookahead)
        var point = max(0, playhead)
        for range in scanned.sorted(by: { $0.lowerBound < $1.lowerBound }) where range.contains(point) {
            point = range.upperBound
        }
        guard point < windowEnd - 1 else { return nil }
        let start = point > playhead ? max(playhead, point - overlap) : point
        return start...min(duration, start + sliceLength)
    }

    /// Adds a checked slice, joining it with any it touches.
    public static func adding(_ slice: ClosedRange<TimeInterval>, to scanned: [ClosedRange<TimeInterval>]) -> [ClosedRange<TimeInterval>] {
        var result: [ClosedRange<TimeInterval>] = []
        for range in (scanned + [slice]).sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = result.last, range.lowerBound <= last.upperBound {
                result[result.count - 1] = last.lowerBound...max(last.upperBound, range.upperBound)
            } else {
                result.append(range)
            }
        }
        return result
    }
}
