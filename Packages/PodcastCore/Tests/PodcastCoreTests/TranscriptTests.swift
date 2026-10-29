import XCTest
@testable import PodcastCore

final class TranscriptParserTests: XCTestCase {

    func testWebVTTWithVoices() throws {
        let vtt = """
        WEBVTT

        NOTE made by hand

        1
        00:00:01.000 --> 00:00:04.500 align:start
        <v Alice>Welcome back to Tidewater Weekly.</v>

        2
        00:00:04.500 --> 00:00:07.000
        <v.loud Bob>Thanks &amp; hello!
        """
        let segments = try TranscriptParser.parse(Data(vtt.utf8))
        XCTAssertEqual(segments, [
            TranscriptSegment(start: 1, end: 4.5, speaker: "Alice", text: "Welcome back to Tidewater Weekly."),
            TranscriptSegment(start: 4.5, end: 7, speaker: "Bob", text: "Thanks & hello!")
        ])
    }

    func testSRT() throws {
        let srt = "1\r\n00:01:02,500 --> 00:01:05,000\r\nFirst line\r\nwraps here\r\n\r\n2\r\n01:00:00,000 --> 01:00:02,000\r\nAn hour in\r\n"
        let segments = try TranscriptParser.parse(Data(srt.utf8))
        XCTAssertEqual(segments.map(\.text), ["First line wraps here", "An hour in"])
        XCTAssertEqual(segments.map(\.start), [62.5, 3600])
        XCTAssertNil(segments[0].speaker)
    }

    func testPodcastingJSON() throws {
        let json = """
        {"version": "1.0.0", "segments": [
          {"speaker": "Alice", "startTime": 0.5, "endTime": 0.9, "body": "Hi"},
          {"speaker": "", "startTime": 1.0, "endTime": 1.4, "body": "there"},
          {"startTime": 2.0, "body": "   "}
        ]}
        """
        let segments = try TranscriptParser.parse(Data(json.utf8))
        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].speaker, "Alice")
        XCTAssertNil(segments[1].speaker)
    }

    func testUnsupported() {
        XCTAssertThrowsError(try TranscriptParser.parse(Data("<html>hi</html>".utf8)))
    }

    func testPreferredLink() {
        let html = TranscriptLink(url: URL(string: "https://x.com/t.html")!, type: "text/html")
        let srt = TranscriptLink(url: URL(string: "https://x.com/t.srt")!, type: "application/x-subrip")
        let vtt = TranscriptLink(url: URL(string: "https://x.com/t.vtt")!, type: "text/vtt")
        let json = TranscriptLink(url: URL(string: "https://x.com/t.json")!, type: "application/json")
        XCTAssertEqual(TranscriptParser.preferred([html, srt, vtt, json]), json)
        XCTAssertEqual(TranscriptParser.preferred([html, srt]), srt)
        XCTAssertNil(TranscriptParser.preferred([html]))
    }
}

final class TranscriptLayoutTests: XCTestCase {

    func seg(_ start: Double, _ end: Double, _ text: String, _ speaker: String? = nil) -> TranscriptSegment {
        TranscriptSegment(start: start, end: end, speaker: speaker, text: text)
    }

    func testWordByWordJoinsIntoLinesPerSpeaker() {
        let lines = TranscriptLayout.lines(from: [
            seg(0, 0.3, "Hi", "A"), seg(0.3, 0.6, "there,", "A"), seg(0.6, 1.0, "friend.", "A"),
            seg(1.2, 1.5, "Hi", "B"), seg(1.5, 1.8, "too", "B")
        ])
        XCTAssertEqual(lines.map(\.text), ["Hi there, friend.", "Hi too"])
        XCTAssertEqual(lines.map(\.speaker), ["A", "B"])
        XCTAssertEqual(lines[0].end, 1.0)
    }

    func testBlocksEvery20SecondsAndAtPauses() {
        let transcript = Transcript(source: .publisher, segments: [
            // Alternating speakers so each piece stays its own line.
            seg(0, 5, "One.", "A"), seg(5.5, 12, "Two.", "B"), seg(12.5, 21, "Three.", "A"),
            seg(21.5, 25, "Four.", "B"),  // 21.5s after the heading → new block
            seg(30, 33, "Five.", "A")     // after a 5s pause → new block
        ], music: [MusicSpan(start: 40, end: 54)])
        let blocks = TranscriptLayout.blocks(for: transcript)
        XCTAssertEqual(blocks.map(\.start), [0, 21.5, 30, 40])
        XCTAssertEqual(blocks[0].rows.count, 3)
        XCTAssertEqual(blocks[3].rows, [.music(MusicSpan(start: 40, end: 54))])
    }

    func testAdBreakFoldsIntoOneBand() {
        let transcript = Transcript(source: .onDevice, segments: [
            seg(0, 5, "Hello.", "A"), seg(6, 10, "Brought to you by Sailco.", "B"), seg(10.5, 14, "Use code TIDE.", "B"), seg(15, 18, "Back to it.", "A")
        ])
        let adBreak = AdBreak(start: 6, end: 14.5, score: 6)
        let blocks = TranscriptLayout.blocks(for: transcript, ads: [adBreak])
        XCTAssertEqual(blocks.map(\.start), [0, 6, 15])
        guard case .ad(let band, let hidden) = blocks[1].rows[0] else { return XCTFail("expected an ad band") }
        XCTAssertEqual(band, adBreak)
        XCTAssertEqual(hidden.map(\.text), ["Brought to you by Sailco. Use code TIDE."])
    }

    func testMusicSpansJoinAndDropShortStings() {
        let windows = [
            MusicDetection.Window(start: 0, duration: 3, confidence: 0.9),
            MusicDetection.Window(start: 1.5, duration: 3, confidence: 0.8),
            MusicDetection.Window(start: 3, duration: 3, confidence: 0.7),
            MusicDetection.Window(start: 4.5, duration: 3, confidence: 0.2),
            MusicDetection.Window(start: 100, duration: 3, confidence: 0.9)   // 3s sting
        ]
        XCTAssertEqual(MusicDetection.spans(from: windows), [MusicSpan(start: 0, end: 6)])
    }

    func testSpeakers() {
        let transcript = Transcript(source: .publisher, segments: [seg(0, 1, "a", "B"), seg(1, 2, "b", "A"), seg(2, 3, "c", "B"), seg(3, 4, "d")])
        XCTAssertEqual(transcript.speakers, ["B", "A"])
    }
}

final class TranscriptSearchTests: XCTestCase {

    func testFindsCaseAndAccentInsensitive() {
        let lines = [
            TranscriptLayout.Line(start: 10, end: 12, speaker: nil, text: "Nothing here."),
            TranscriptLayout.Line(start: 20, end: 25, speaker: nil, text: "We went to the Café by the harbour.")
        ]
        let matches = TranscriptSearch.matches(of: "cafe", in: lines)
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].time, 20)
        XCTAssertEqual(String(matches[0].snippet[matches[0].highlight]), "Café")
    }

    func testLongLinesAreShortenedAroundTheMatch() {
        let text = String(repeating: "a", count: 200) + " harbour " + String(repeating: "b", count: 200)
        let lines = [TranscriptLayout.Line(start: 0, end: 1, speaker: nil, text: text)]
        let match = TranscriptSearch.matches(of: "harbour", in: lines)[0]
        XCTAssertTrue(match.snippet.hasPrefix("…"))
        XCTAssertTrue(match.snippet.hasSuffix("…"))
        XCTAssertEqual(String(match.snippet[match.highlight]), "harbour")
    }

    func testIgnoresOneLetterQueries() {
        XCTAssertEqual(TranscriptSearch.matches(of: "a", in: [TranscriptLayout.Line(start: 0, end: 1, speaker: nil, text: "a")]), [])
    }

    func testStamp() {
        XCTAssertEqual(TimeFormat.stamp(45), "45s")
        XCTAssertEqual(TimeFormat.stamp(80), "1m 20s")
        XCTAssertEqual(TimeFormat.stamp(3725), "1h 2m 5s")
    }
}

final class AdDetectionTests: XCTestCase {

    func line(_ start: Double, _ end: Double, _ text: String) -> TranscriptLayout.Line {
        TranscriptLayout.Line(start: start, end: end, speaker: nil, text: text)
    }

    var episode: [TranscriptLayout.Line] {
        [
            line(0, 10, "Welcome to the show, today we talk tides."),
            line(10, 60, "We visit the harbour where the boats come in."),
            line(115, 119.5, "Quick break."),
            line(120, 125, "This episode is brought to you by Sailco."),
            line(125, 140, "Go to sailco.com/tide and use code TIDE for 20% off."),
            line(140, 150, "Terms apply."),
            line(150, 170, "Anyway, back to the show and the tides."),
            line(170, 230, "The tide tables are older than you'd think.")
        ]
    }

    func testFindsASponsorRead() {
        XCTAssertEqual(AdDetection.breaks(in: episode), [AdBreak(start: 115, end: 170, score: 15)])
    }

    func testOrdinaryMentionsAreNotAds() {
        XCTAssertEqual(AdDetection.breaks(in: [line(0, 10, "We visit the harbour."), line(10, 20, "Go to the end of the pier.")]), [])
    }

    func testMusicWidensTheBreak() {
        let breaks = AdDetection.breaks(in: episode, music: [MusicSpan(start: 108, end: 116), MusicSpan(start: 169, end: 175)])
        XCTAssertEqual(breaks.first?.start, 108)
        XCTAssertEqual(breaks.first?.end, 175)
    }
}

final class ChapterMakerTests: XCTestCase {

    /// 25 minutes: harbours, then baking, then football, a line every 10s.
    var lines: [TranscriptLayout.Line] {
        (0..<150).map { i in
            let start = Double(i * 10)
            let text: String
            switch start {
            case ..<500: text = "The harbour tides and boats in the harbour."
            case ..<1000: text = "Baking bread needs flour and a hot oven for bread."
            default: text = "The football match had goals and more football."
            }
            return TranscriptLayout.Line(start: start, end: start + 9, speaker: nil, text: text)
        }
    }

    func testCutsWhereTheTopicChanges() {
        let chapters = ChapterMaker.chapters(lines: lines, duration: 1500)
        XCTAssertEqual(chapters.map(\.start), [0, 500, 1000])
        XCTAssertEqual(chapters.last?.end, 1500)
        XCTAssertTrue(chapters[0].title.hasPrefix("Harbour"), chapters[0].title)
        XCTAssertTrue(chapters[1].title.hasPrefix("Bread"), chapters[1].title)
        XCTAssertTrue(chapters[2].title.hasPrefix("Football"), chapters[2].title)
    }

    func testAdBreaksBecomeChaptersAndTheTopicCarriesOn() {
        let chapters = ChapterMaker.chapters(lines: lines, ads: [AdBreak(start: 700, end: 760, score: 9)], duration: 1500)
        XCTAssertEqual(chapters.map(\.start), [0, 500, 700, 760, 1000])
        XCTAssertEqual(chapters.map(\.isAd), [false, false, true, false, false])
        XCTAssertEqual(chapters[1].end, 700)
        XCTAssertEqual(chapters[3].title, chapters[1].title)
    }
}

final class SpeakerLabelsTests: XCTestCase {

    func word(_ start: Double, _ end: Double, _ text: String) -> TranscriptSegment {
        TranscriptSegment(start: start, end: end, text: text)
    }

    func testWordsTakeTheSpeakerTheyOverlapAndAreNumberedInOrder() {
        let turns = [
            SpeakerLabels.Turn(speaker: "S7", start: 0, end: 2.0),
            SpeakerLabels.Turn(speaker: "S2", start: 2.0, end: 4.0),
            SpeakerLabels.Turn(speaker: "S7", start: 4.0, end: 6.0)
        ]
        let words = [word(0.1, 0.5, "Hi"), word(1.8, 2.6, "there"), word(2.7, 3.0, "Hello"), word(4.5, 5.0, "Again"), word(6.5, 6.8, "Bye"), word(20, 21, "Late")]
        let labelled = SpeakerLabels.assign(turns, to: words)
        XCTAssertEqual(labelled.map(\.speaker), ["Speaker 1", "Speaker 2", "Speaker 2", "Speaker 1", "Speaker 1", nil])
    }

    func testNoTurnsLeavesTranscriptAlone() {
        let words = [word(0, 1, "Hi")]
        XCTAssertEqual(SpeakerLabels.assign([], to: words), words)
    }

    func testLabelledWordsJoinIntoLinesPerSpeaker() {
        let turns = [SpeakerLabels.Turn(speaker: "A", start: 0, end: 1.2), SpeakerLabels.Turn(speaker: "B", start: 1.2, end: 3)]
        let words = [word(0, 0.4, "Hi"), word(0.4, 1.0, "there."), word(1.3, 1.6, "Hi"), word(1.6, 2.0, "too.")]
        let lines = TranscriptLayout.lines(from: SpeakerLabels.assign(turns, to: words))
        XCTAssertEqual(lines.map(\.text), ["Hi there.", "Hi too."])
        XCTAssertEqual(lines.map(\.speaker), ["Speaker 1", "Speaker 2"])
    }
}

final class AdScanPlanTests: XCTestCase {

    func testFirstSliceStartsAtThePlayhead() {
        XCTAssertEqual(AdScanPlan.nextSlice(playhead: 60, scanned: [], duration: 3600), 60...210)
    }

    func testNextSliceOverlapsTheLastOne() {
        XCTAssertEqual(AdScanPlan.nextSlice(playhead: 100, scanned: [60...210], duration: 3600), 190...340)
    }

    func testNothingToDoWhenFarEnoughAhead() {
        XCTAssertNil(AdScanPlan.nextSlice(playhead: 100, scanned: [60...400], duration: 3600))
    }

    func testStopsAtTheEnd() {
        XCTAssertEqual(AdScanPlan.nextSlice(playhead: 3500, scanned: [], duration: 3600), 3500...3600)
        XCTAssertNil(AdScanPlan.nextSlice(playhead: 3590, scanned: [3500...3600], duration: 3600))
    }

    func testJumpingAheadStartsANewRegion() {
        XCTAssertEqual(AdScanPlan.nextSlice(playhead: 2000, scanned: [0...400], duration: 3600), 2000...2150)
    }

    func testAddingJoinsTouchingSlices() {
        XCTAssertEqual(AdScanPlan.adding(190...340, to: [60...210, 2000...2150]), [60...340, 2000...2150])
    }

    func testMergingBreaksFromOverlappingSlices() {
        let merged = AdDetection.merge([AdBreak(start: 100, end: 180, score: 8)], [AdBreak(start: 170, end: 230, score: 6), AdBreak(start: 900, end: 960, score: 5)])
        XCTAssertEqual(merged, [AdBreak(start: 100, end: 230, score: 8), AdBreak(start: 900, end: 960, score: 5)])
    }
}
