import XCTest
@testable import PodcastCore

final class TranscriptAlignTests: XCTestCase {

    /// A made-up transcript: one distinct sentence every 10 seconds.
    func transcript() -> [TranscriptSegment] {
        let words = ["harbour", "lantern", "pilot", "tide", "rope", "gull", "anchor", "chart", "fog", "keel",
                     "mast", "sail", "buoy", "reef", "crab", "net", "oar", "deck", "hull", "wake"]
        return (0..<60).map { i in
            let text = (0..<6).map { words[(i * 7 + $0 * 3) % words.count] + "\(i)" }.joined(separator: " ")
            return TranscriptSegment(start: Double(i) * 10, end: Double(i) * 10 + 8, text: text)
        }
    }

    /// The same speech as heard in a download with a 90-second ad inserted at 200s.
    func heard(from segments: [TranscriptSegment], adAt: TimeInterval = 200, adLength: TimeInterval = 90) -> [TranscriptSegment] {
        var out: [TranscriptSegment] = []
        for segment in segments {
            let shift = segment.start >= adAt ? adLength : 0
            let parts = segment.text.split(separator: " ")
            let step = (segment.end - segment.start) / Double(parts.count)
            for (i, part) in parts.enumerated() {
                let t = segment.start + shift + step * Double(i)
                out.append(TranscriptSegment(start: t, end: t + step, text: String(part)))
            }
        }
        out.append(TranscriptSegment(start: adAt, end: adAt + 5, text: "this episode is brought to you by"))
        return out.sorted { $0.start < $1.start }
    }

    func testFindsOffsetAfterAnInsertedAd() throws {
        let said = transcript()
        let slice = heard(from: said).filter { $0.start >= 400 && $0.start < 520 }
        let anchor = try XCTUnwrap(TranscriptAlign.anchor(heard: slice, transcript: said))
        XCTAssertEqual(anchor.offset, 90, accuracy: 1)
    }

    func testNoAnchorForWordsNotInTheTranscript() {
        let ad = [TranscriptSegment(start: 0, end: 20, text: "use code POD for twenty percent off at example dot com today only")]
        XCTAssertNil(TranscriptAlign.anchor(heard: ad, transcript: transcript()))
    }

    func testWholeEpisodeAnchorsShiftOnlyAfterTheAd() {
        let said = transcript()
        let anchors = TranscriptAlign.anchors(heard: heard(from: said), transcript: said)
        XCTAssertFalse(anchors.isEmpty)
        XCTAssertEqual(TranscriptAlign.offset(at: 100, anchors: anchors), 0, accuracy: 1)
        XCTAssertEqual(TranscriptAlign.offset(at: 500, anchors: anchors), 90, accuracy: 1)

        let aligned = TranscriptAlign.aligned(Transcript(source: .publisher, segments: said), anchors: anchors)
        XCTAssertEqual(aligned.segments[50].start, 590, accuracy: 1)
        XCTAssertEqual(aligned.segments[5].start, 50, accuracy: 1)
    }

    func testAnchorsReplaceNearbyOnesAndMapBack() {
        var anchors = TranscriptAlign.adding(SyncAnchor(transcriptTime: 100, offset: 30), to: [])
        anchors = TranscriptAlign.adding(SyncAnchor(transcriptTime: 110, offset: 32), to: anchors)
        anchors = TranscriptAlign.adding(SyncAnchor(transcriptTime: 300, offset: 120), to: anchors)
        XCTAssertEqual(anchors.map(\.offset), [32, 120])
        XCTAssertEqual(TranscriptAlign.offset(at: 50, anchors: anchors), 32)
        XCTAssertEqual(TranscriptAlign.transcriptTime(forAudio: 450, anchors: anchors), 330, accuracy: 0.01)
        XCTAssertEqual(TranscriptAlign.transcriptTime(forAudio: 200, anchors: anchors), 168, accuracy: 0.01)
    }
}
