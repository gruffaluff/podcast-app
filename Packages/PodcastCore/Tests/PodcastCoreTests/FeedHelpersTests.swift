import XCTest
@testable import PodcastCore

final class FeedDiffTests: XCTestCase {

    func ep(_ guid: String, day: Int?) -> ParsedEpisode {
        ParsedEpisode(
            guid: guid,
            title: guid,
            published: day.map { Date(timeIntervalSince1970: TimeInterval($0 * 86_400)) },
            audioURL: URL(string: "https://example.com/\(guid).mp3")!
        )
    }

    func testJustFollowedShowHasNothingFresh() {
        let result = FeedDiff.compare([ep("b", day: 10), ep("a", day: 9)], knownGUIDs: [], newestKnown: nil)
        XCTAssertEqual(result.added.map(\.guid), ["b", "a"])
        XCTAssertEqual(result.fresh, [])
    }

    func testNewReleaseIsFresh() {
        let result = FeedDiff.compare([ep("c", day: 11), ep("b", day: 10)], knownGUIDs: ["b"], newestKnown: day(10))
        XCTAssertEqual(result.added.map(\.guid), ["c"])
        XCTAssertEqual(result.fresh.map(\.guid), ["c"])
    }

    func testBackfilledOldEpisodeIsSavedButNotFresh() {
        let result = FeedDiff.compare([ep("b", day: 10), ep("old", day: 2)], knownGUIDs: ["b"], newestKnown: day(10))
        XCTAssertEqual(result.added.map(\.guid), ["old"])
        XCTAssertEqual(result.fresh, [])
    }

    func testSlightlyLateEpisodeStillCountsAsFresh() {
        let result = FeedDiff.compare([ep("late", day: 9)], knownGUIDs: ["b"], newestKnown: day(10))
        XCTAssertEqual(result.fresh.map(\.guid), ["late"])
    }

    func testDuplicateGuidsInFeedAreAddedOnce() {
        let result = FeedDiff.compare([ep("c", day: 11), ep("c", day: 11)], knownGUIDs: [], newestKnown: day(10))
        XCTAssertEqual(result.added.map(\.guid), ["c"])
    }

    private func day(_ n: Int) -> Date { Date(timeIntervalSince1970: TimeInterval(n * 86_400)) }
}

final class DirectoryTests: XCTestCase {

    func testSearchURL() {
        let url = Directory.searchURL(term: "sea stories", country: "GB", limit: 10)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(url.host, "itunes.apple.com")
        XCTAssertTrue(items.contains(URLQueryItem(name: "term", value: "sea stories")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "media", value: "podcast")))
        XCTAssertTrue(items.contains(URLQueryItem(name: "limit", value: "10")))
    }

    func testDecodeDropsShowsWithoutFeeds() throws {
        let json = """
        {"resultCount": 2, "results": [
          {"collectionId": 1, "collectionName": "Tidewater Weekly", "artistName": "Harbour Audio",
           "feedUrl": "https://example.com/feed.xml", "artworkUrl600": "https://example.com/600.jpg",
           "primaryGenreName": "Society & Culture"},
          {"collectionId": 2, "collectionName": "Apple-only show"}
        ]}
        """
        let shows = try Directory.decodeSearch(Data(json.utf8))
        XCTAssertEqual(shows.map(\.collectionName), ["Tidewater Weekly"])
        XCTAssertEqual(shows[0].feedURL, URL(string: "https://example.com/feed.xml"))
        XCTAssertEqual(shows[0].artworkURL, URL(string: "https://example.com/600.jpg"))
    }
}

final class TextFormatTests: XCTestCase {

    func testLength() {
        XCTAssertEqual(TimeFormat.length(45 * 60), "45m")
        XCTAssertEqual(TimeFormat.length(72 * 60), "1h 12m")
        XCTAssertEqual(TimeFormat.length(2 * 3600), "2h")
        XCTAssertEqual(TimeFormat.length(20), "1m")
        XCTAssertEqual(TimeFormat.length(0), "")
    }

    func testClock() {
        XCTAssertEqual(TimeFormat.clock(245), "4:05")
        XCTAssertEqual(TimeFormat.clock(3723), "1:02:03")
        XCTAssertEqual(TimeFormat.clock(.nan), "0:00")
    }

    func testAgo() {
        let now = Date(timeIntervalSince1970: 1_740_903_300)
        XCTAssertEqual(TimeFormat.ago(now.addingTimeInterval(-30), now: now), "Just now")
        XCTAssertEqual(TimeFormat.ago(now.addingTimeInterval(-4 * 3600), now: now), "4h ago")
        XCTAssertEqual(TimeFormat.ago(now.addingTimeInterval(-3 * 86_400), now: now), "3d ago")
    }

    func testNotesKeepParagraphsListsAndLinks() {
        let html = "<p>Stories from the <b>coast</b>.</p><p>This week:<br>tides</p><ul><li>One</li><li>Two</li></ul><p>More at <a href=\"https://example.com/x\">our site</a> and <a href='https://e.com'>https://e.com</a></p>"
        XCTAssertEqual(PlainText.notesFromHTML(html), "Stories from the coast.\n\nThis week:\ntides\n\n• One\n• Two\n\nMore at our site (https://example.com/x) and https://e.com")
    }

    func testPlainTextNotesKeepTheirLineBreaks() {
        XCTAssertEqual(PlainText.notesFromHTML("Line one\r\n\r\n\r\nLine   two &amp; more\n"), "Line one\n\nLine two & more")
    }

    func testPlainTextFromHTML() {
        XCTAssertEqual(PlainText.fromHTML("<p>Stories from the <b>coast</b>.</p><p>Every week.</p>"), "Stories from the coast. Every week.")
        XCTAssertEqual(PlainText.fromHTML("Fish &amp; chips &#8211; &#x2014; &rsquo;"), "Fish & chips – — ’")
        XCTAssertEqual(PlainText.fromHTML("AT&T and &unknown; stay"), "AT&T and &unknown; stay")
    }
}

final class DownloadNamingTests: XCTestCase {

    func testNameIsStableAndKeepsAudioExtension() {
        let url = URL(string: "https://cdn.example.com/show/ep%201.m4a?token=abc")!
        let name = DownloadNaming.fileName(episodeID: "https://example.com/feed.xml|ep-1", audioURL: url)
        XCTAssertEqual(name, DownloadNaming.fileName(episodeID: "https://example.com/feed.xml|ep-1", audioURL: url))
        XCTAssertTrue(name.hasSuffix(".m4a"))
        XCTAssertEqual(name.count, 16 + 4)
        XCTAssertFalse(name.contains("/"))
    }

    func testDifferentEpisodesGetDifferentNames() {
        let url = URL(string: "https://cdn.example.com/a.mp3")!
        XCTAssertNotEqual(
            DownloadNaming.fileName(episodeID: "feed|1", audioURL: url),
            DownloadNaming.fileName(episodeID: "feed|2", audioURL: url)
        )
    }

    func testUnknownExtensionFallsBackToMP3() {
        let url = URL(string: "https://tracking.example.com/redirect/12345")!
        XCTAssertTrue(DownloadNaming.fileName(episodeID: "x", audioURL: url).hasSuffix(".mp3"))
    }

    func testKnownHash() {
        // FNV-1a 64 of the empty string is its offset basis.
        XCTAssertEqual(DownloadNaming.stableHash(""), "cbf29ce484222325")
    }
}

final class DownloadCleanupTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_000_000)

    func testUnplayedIsKept() {
        XCTAssertFalse(DownloadCleanup.shouldDelete(played: false, playedAt: nil, keepFor24Hours: false, now: now))
    }

    func testPlayedIsDeletedStraightAwayByDefault() {
        XCTAssertTrue(DownloadCleanup.shouldDelete(played: true, playedAt: now, keepFor24Hours: false, now: now))
    }

    func testPlayedIsKeptFor24HoursWhenSettingOn() {
        XCTAssertFalse(DownloadCleanup.shouldDelete(played: true, playedAt: now.addingTimeInterval(-23 * 3600), keepFor24Hours: true, now: now))
        XCTAssertTrue(DownloadCleanup.shouldDelete(played: true, playedAt: now.addingTimeInterval(-25 * 3600), keepFor24Hours: true, now: now))
    }
}

final class PlayerOptionsTests: XCTestCase {
    func testScrubSpeedSlowsAsTheFingerMovesDown() {
        XCTAssertEqual(PlayerOptions.scrubSpeed(below: -10).factor, 1)
        XCTAssertEqual(PlayerOptions.scrubSpeed(below: 39).factor, 1)
        XCTAssertEqual(PlayerOptions.scrubSpeed(below: 40).factor, 0.5)
        XCTAssertEqual(PlayerOptions.scrubSpeed(below: 100).factor, 0.25)
        XCTAssertEqual(PlayerOptions.scrubSpeed(below: 300).factor, 0.125)
        XCTAssertEqual(PlayerOptions.scrubSpeed(below: 300).label, "FINE SCRUBBING")
    }


    func testSpeeds() {
        XCTAssertEqual(PlayerOptions.speeds.first, 1.0)
        XCTAssertEqual(PlayerOptions.speeds.last, 2.0)
        XCTAssertEqual(PlayerOptions.speeds.count, 11)
        XCTAssertEqual(PlayerOptions.speedLabel(1.0), "1×")
        XCTAssertEqual(PlayerOptions.speedLabel(1.5), "1.5×")
        XCTAssertEqual(PlayerOptions.speedLabel(2.0), "2×")
    }

    func testSkipLengths() {
        XCTAssertEqual(PlayerOptions.validSkip(30), 30)
        XCTAssertEqual(PlayerOptions.validSkip(7), 10)
    }
}

final class ColorContrastTests: XCTestCase {

    func testKnownRatios() {
        XCTAssertEqual(ColorContrast.ratio(.white, RGB(r: 0, g: 0, b: 0)), 21, accuracy: 0.01)
        XCTAssertEqual(ColorContrast.ratio(.white, .white), 1, accuracy: 0.001)
    }

    func testPaleArtworkIsDarkenedUntilTextIsReadable() {
        let pale = RGB(r: 0.95, g: 0.88, b: 0.60)
        let background = ColorContrast.themedBackground(from: pale)
        XCTAssertTrue(ColorContrast.passes(background))
        XCTAssertGreaterThanOrEqual(ColorContrast.ratio(.white, background), 4.5)
        // Keeps the hue: red stays the strongest channel.
        XCTAssertGreaterThan(background.r, background.b)
    }

    func testDarkArtworkIsLeftAlone() {
        let navy = RGB(r: 0.1, g: 0.15, b: 0.3)
        XCTAssertEqual(ColorContrast.themedBackground(from: navy), navy)
    }
}

final class ChaptersTests: XCTestCase {

    func testParsesJSONChapters() throws {
        let json = """
        {"version": "1.2.0", "chapters": [
          {"startTime": 95.5, "title": "The harbour", "img": "https://example.com/c2.jpg"},
          {"startTime": 0, "title": "Intro"},
          {"startTime": 60, "title": "Hidden marker", "toc": false},
          {"startTime": 300, "title": "  ", "url": "https://example.com/more"}
        ]}
        """
        let chapters = try Chapters.parseJSON(Data(json.utf8))
        XCTAssertEqual(chapters.map(\.title), ["Intro", "The harbour", "Chapter 3"])
        XCTAssertEqual(chapters.map(\.start), [0, 95.5, 300])
        XCTAssertEqual(chapters[0].end, 95.5)
        XCTAssertEqual(chapters[1].end, 300)
        XCTAssertNil(chapters[2].end)
        XCTAssertEqual(chapters[1].imageURL, URL(string: "https://example.com/c2.jpg"))
        XCTAssertEqual(chapters[2].link, URL(string: "https://example.com/more"))
    }

    func testLastChapterEndsAtEpisodeEnd() {
        let chapters = Chapters.tidy([Chapter(start: 0, title: "A"), Chapter(start: 50, title: "B")], duration: 120)
        XCTAssertEqual(chapters.map(\.end), [50, 120])
        XCTAssertEqual(chapters[1].length, 70)
    }

    func testCurrentChapter() {
        let chapters = Chapters.tidy([Chapter(start: 10, title: "A"), Chapter(start: 50, title: "B")], duration: 120)
        XCTAssertNil(Chapters.index(at: 5, in: chapters))
        XCTAssertEqual(Chapters.index(at: 10, in: chapters), 0)
        XCTAssertEqual(Chapters.index(at: 49, in: chapters), 0)
        XCTAssertEqual(Chapters.index(at: 51, in: chapters), 1)
    }
}

final class AudioProcessingTests: XCTestCase {

    func testQuietSpeechIsLiftedAndLoudIsEvened() {
        var quiet = [Float](repeating: 0, count: 4800)
        var loud = [Float](repeating: 0, count: 4800)
        for i in 0..<4800 {
            let wave = Float(sin(Double(i) * 2 * .pi * 200 / 48_000))
            quiet[i] = 0.03 * wave
            loud[i] = 0.6 * wave
        }
        var boostQuiet = VoiceBoost()
        var boostLoud = VoiceBoost()
        quiet.withUnsafeMutableBufferPointer { boostQuiet.process($0, sampleRate: 48_000) }
        loud.withUnsafeMutableBufferPointer { boostLoud.process($0, sampleRate: 48_000) }
        let quietPeak = quiet[2400...].map(abs).max()!
        let loudPeak = loud[2400...].map(abs).max()!
        XCTAssertGreaterThan(quietPeak, 0.06)        // louder than before
        XCTAssertLessThan(loudPeak / quietPeak, 20)   // was 20× apart
        XCTAssertLessThanOrEqual(loudPeak, 1)         // never clips
    }

    func testSoftLimitStaysUnderFullScale() {
        XCTAssertEqual(VoiceBoost.softLimit(0.5), 0.5)
        XCTAssertLessThan(VoiceBoost.softLimit(5), 1)
        XCTAssertGreaterThan(VoiceBoost.softLimit(-5), -1)
    }

    func testSilenceDetectorWaitsForARealPause() {
        var detector = SilenceDetector()
        XCTAssertFalse(detector.feed(rms: 0.1, duration: 0.1))   // speech
        XCTAssertFalse(detector.feed(rms: 0.001, duration: 0.1)) // short gap
        XCTAssertFalse(detector.feed(rms: 0.001, duration: 0.1))
        XCTAssertTrue(detector.feed(rms: 0.001, duration: 0.15)) // now a pause
        XCTAssertFalse(detector.feed(rms: 0.1, duration: 0.05))  // speech again
    }

    func testRMS() {
        let samples: [Float] = [0.5, -0.5, 0.5, -0.5]
        samples.withUnsafeBufferPointer { XCTAssertEqual(SilenceDetector.rms($0), 0.5, accuracy: 0.0001) }
    }

    func testTrimRate() {
        XCTAssertEqual(SilenceDetector.trimRate(forSpeed: 1), 2.5)
        XCTAssertEqual(SilenceDetector.trimRate(forSpeed: 2), 4)
    }
}

final class ChartTests: XCTestCase {

    func testTopChart() throws {
        let json = """
        {"feed": {"title": "Top Shows", "results": [
          {"artistName": "Harbour Audio", "id": "123", "name": "Tidewater Weekly", "kind": "podcasts",
           "artworkUrl100": "https://is1.mzstatic.com/image/thumb/a/b/100x100bb.png",
           "genres": [{"genreId": "1324", "name": "Society & Culture"}]},
          {"id": "456", "name": "No Extras"}
        ]}}
        """
        let items = try Directory.decodeTopChart(Data(json.utf8))
        XCTAssertEqual(items.map(\.title), ["Tidewater Weekly", "No Extras"])
        XCTAssertEqual(items[0].appleID, "123")
        XCTAssertEqual(items[0].genre, "Society & Culture")
        XCTAssertEqual(items[0].artworkURL?.absoluteString, "https://is1.mzstatic.com/image/thumb/a/b/600x600bb.png")
        XCTAssertNil(items[0].feedURL)
    }

    func testGenreChartListAndSingleEntry() throws {
        let list = """
        {"feed": {"entry": [
          {"im:name": {"label": "Small Machines"}, "im:artist": {"label": "Chip Co"},
           "im:image": [{"label": "https://x/55x55bb.png"}, {"label": "https://x/170x170bb.png"}],
           "id": {"label": "https://podcasts.apple.com/gb/podcast/id789", "attributes": {"im:id": "789"}},
           "category": {"attributes": {"im:id": "1318", "term": "Technology", "label": "Technology"}}}
        ]}}
        """
        let items = try Directory.decodeGenreChart(Data(list.utf8))
        XCTAssertEqual(items, [DirectoryItem(appleID: "789", title: "Small Machines", artist: "Chip Co",
                                             artworkURL: URL(string: "https://x/600x600bb.png"), genre: "Technology")])
        let single = list
            .replacingOccurrences(of: "\"entry\": [", with: "\"entry\": ")
            .replacingOccurrences(of: "}}}\n]}}", with: "}}}\n}}")
        XCTAssertEqual(try Directory.decodeGenreChart(Data(single.utf8)).map(\.appleID), ["789"])
    }

    func testAppleIDFromApplePodcastsLink() {
        XCTAssertEqual(Directory.appleID(fromLink: URL(string: "https://podcasts.apple.com/gb/podcast/elis-james-and-john-robins/id1465290044")!), "1465290044")
        XCTAssertEqual(Directory.appleID(fromLink: URL(string: "https://podcasts.apple.com/gb/podcast/x/id1465290044?i=1000123")!), "1465290044")
        XCTAssertNil(Directory.appleID(fromLink: URL(string: "https://example.com/feed/id1465290044")!))
    }

    func testLookupURLAndGenres() {
        XCTAssertTrue(Directory.lookupURL(appleID: "123").absoluteString.contains("id=123"))
        XCTAssertEqual(PodcastGenre.named("technology")?.id, "1318")
        XCTAssertNil(PodcastGenre.named("Knitting"))
    }
}

final class ClipsTests: XCTestCase {

    func testDefaultLengthRoundsUpWithinLimits() {
        XCTAssertEqual(Clips.defaultLength(lineStart: 10, lineEnd: 21), 15)
        XCTAssertEqual(Clips.defaultLength(lineStart: 10, lineEnd: 11), 5)
        XCTAssertEqual(Clips.defaultLength(lineStart: 0, lineEnd: 90), 30)
    }

    func testRangeStaysInsideTheEpisode() {
        XCTAssertEqual(Clips.range(start: 100, length: 15, duration: 600), 100...115)
        XCTAssertEqual(Clips.range(start: 595, length: 15, duration: 600), 585...600)
        XCTAssertEqual(Clips.range(start: 10, length: 99, duration: nil), 10...40)
    }

    func testShareText() {
        let text = Clips.shareText(quote: "Hello there", show: "Tidewater Weekly", episode: "Harbour lights", at: 1111, link: URL(string: "https://example.com/ep"))
        XCTAssertEqual(text, "“Hello there”\n— Tidewater Weekly, Harbour lights (18:31)\nListen from 18:31: https://example.com/ep")
    }

    func testWaveform() {
        let samples: [Float] = [0, 0, 0.5, -0.5, 1, -1]
        let bars = Clips.waveform(samples, count: 3)
        XCTAssertEqual(bars.count, 3)
        XCTAssertEqual(bars[2], 1, accuracy: 0.0001)
        XCTAssertEqual(bars[1], 0.5, accuracy: 0.0001)
        XCTAssertEqual(bars[0], 0.08, accuracy: 0.0001)
    }
}
