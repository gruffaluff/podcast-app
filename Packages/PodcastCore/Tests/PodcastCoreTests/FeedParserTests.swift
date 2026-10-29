import XCTest
@testable import PodcastCore

final class FeedParserTests: XCTestCase {

    let sampleFeed = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0"
         xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd"
         xmlns:podcast="https://podcastindex.org/namespace/1.0"
         xmlns:content="http://purl.org/rss/1.0/modules/content/">
      <channel>
        <title>Tidewater Weekly</title>
        <link>https://example.com/tidewater</link>
        <description><![CDATA[<p>Stories from the <b>coast</b>.</p>]]></description>
        <itunes:author>Harbour Audio</itunes:author>
        <itunes:image href="https://example.com/art.jpg"/>
        <image>
          <url>https://example.com/small.jpg</url>
          <title>Tidewater Weekly</title>
        </image>
        <item>
          <title>Harbour lights</title>
          <guid isPermaLink="false">tw-2</guid>
          <pubDate>Wed, 1 Jan 2025 09:30:00 GMT</pubDate>
          <description>Second &amp; newest.</description>
          <enclosure url="https://cdn.example.com/tw2.mp3" length="12345" type="audio/mpeg"/>
          <itunes:duration>1:02:03</itunes:duration>
          <itunes:image href="https://example.com/tw2.jpg"/>
          <podcast:transcript url="https://example.com/tw2.vtt" type="text/vtt" language="en"/>
          <podcast:chapters url="https://example.com/tw2.json" type="application/json+chapters"/>
        </item>
        <item>
          <title>Low tide, high stakes</title>
          <pubDate>Tue, 08 Oct 2024 10:00:00 +0000</pubDate>
          <content:encoded><![CDATA[<p>The first one.</p>]]></content:encoded>
          <enclosure url="https://cdn.example.com/tw1.mp3" type="audio/mpeg"/>
          <itunes:duration>2700</itunes:duration>
        </item>
        <item>
          <title>A blog post with no audio</title>
          <guid>post-1</guid>
        </item>
      </channel>
    </rss>
    """

    func testReadsShowDetails() throws {
        let feed = try FeedParser.parse(Data(sampleFeed.utf8))
        XCTAssertEqual(feed.title, "Tidewater Weekly")
        XCTAssertEqual(feed.author, "Harbour Audio")
        XCTAssertEqual(feed.summary, "<p>Stories from the <b>coast</b>.</p>")
        XCTAssertEqual(feed.artworkURL, URL(string: "https://example.com/art.jpg"))
        XCTAssertEqual(feed.link, URL(string: "https://example.com/tidewater"))
    }

    func testReadsEpisodesAndSkipsItemsWithoutAudio() throws {
        let feed = try FeedParser.parse(Data(sampleFeed.utf8))
        XCTAssertEqual(feed.episodes.map(\.title), ["Harbour lights", "Low tide, high stakes"])

        let newest = feed.episodes[0]
        XCTAssertEqual(newest.guid, "tw-2")
        XCTAssertEqual(newest.summary, "Second & newest.")
        XCTAssertEqual(newest.published, Date(timeIntervalSince1970: 1_735_723_800))
        XCTAssertEqual(newest.audioURL, URL(string: "https://cdn.example.com/tw2.mp3"))
        XCTAssertEqual(newest.audioType, "audio/mpeg")
        XCTAssertEqual(newest.audioBytes, 12345)
        XCTAssertEqual(newest.duration, 3723)
        XCTAssertEqual(newest.artworkURL, URL(string: "https://example.com/tw2.jpg"))
        XCTAssertEqual(newest.transcripts, [TranscriptLink(url: URL(string: "https://example.com/tw2.vtt")!, type: "text/vtt", language: "en")])
        XCTAssertEqual(newest.chaptersURL, URL(string: "https://example.com/tw2.json"))
    }

    func testEpisodeWithoutGuidUsesAudioURL() throws {
        let feed = try FeedParser.parse(Data(sampleFeed.utf8))
        let oldest = feed.episodes[1]
        XCTAssertEqual(oldest.guid, "https://cdn.example.com/tw1.mp3")
        XCTAssertEqual(oldest.summary, "<p>The first one.</p>")
        XCTAssertEqual(oldest.published, Date(timeIntervalSince1970: 1_728_381_600))
        XCTAssertEqual(oldest.duration, 2700)
        XCTAssertNil(oldest.artworkURL)
    }

    func testFallsBackToRSSImage() throws {
        let xml = """
        <rss version="2.0"><channel><title>Plain</title>
        <image><url>https://example.com/small.jpg</url></image>
        </channel></rss>
        """
        let feed = try FeedParser.parse(Data(xml.utf8))
        XCTAssertEqual(feed.artworkURL, URL(string: "https://example.com/small.jpg"))
        XCTAssertTrue(feed.episodes.isEmpty)
    }

    func testWebPageIsNotAFeed() {
        let html = "<html><head><title>Hello</title></head><body>Not a feed</body></html>"
        XCTAssertThrowsError(try FeedParser.parse(Data(html.utf8))) { error in
            XCTAssertEqual(error as? FeedError, .notAFeed)
        }
    }

    // MARK: Dates and durations

    func testDates() {
        XCTAssertEqual(FeedDates.date(from: "Tue, 08 Oct 2024 10:00:00 +0000"), Date(timeIntervalSince1970: 1_728_381_600))
        XCTAssertEqual(FeedDates.date(from: "Mon, 06 Jan 2025 05:00:00 -0500"), Date(timeIntervalSince1970: 1_736_157_600))
        XCTAssertEqual(FeedDates.date(from: "Wed, 1 Jan 2025 09:30:00 GMT"), Date(timeIntervalSince1970: 1_735_723_800))
        // Wrong day name, as some feeds have.
        XCTAssertEqual(FeedDates.date(from: "Fri, 08 Oct 2024 10:00:00 +0000"), Date(timeIntervalSince1970: 1_728_381_600))
        XCTAssertEqual(FeedDates.date(from: "2025-03-02T08:15:00Z"), Date(timeIntervalSince1970: 1_740_903_300))
        XCTAssertNil(FeedDates.date(from: "sometime soon"))
    }

    func testDurations() {
        XCTAssertEqual(FeedDates.duration(from: "3723"), 3723)
        XCTAssertEqual(FeedDates.duration(from: "62:03"), 3723)
        XCTAssertEqual(FeedDates.duration(from: "1:02:03"), 3723)
        XCTAssertNil(FeedDates.duration(from: ""))
        XCTAssertNil(FeedDates.duration(from: "about an hour"))
    }
}
