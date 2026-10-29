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

    func testPlainTextFromHTML() {
        XCTAssertEqual(PlainText.fromHTML("<p>Stories from the <b>coast</b>.</p><p>Every week.</p>"), "Stories from the coast. Every week.")
        XCTAssertEqual(PlainText.fromHTML("Fish &amp; chips &#8211; &#x2014; &rsquo;"), "Fish & chips – — ’")
        XCTAssertEqual(PlainText.fromHTML("AT&T and &unknown; stay"), "AT&T and &unknown; stay")
    }
}
