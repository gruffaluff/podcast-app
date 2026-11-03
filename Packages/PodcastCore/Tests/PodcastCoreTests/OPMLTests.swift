import XCTest
@testable import PodcastCore

final class OPMLTests: XCTestCase {

    func testReadsShowsIncludingFoldersAndSkipsRepeats() throws {
        let file = """
        <?xml version="1.0" encoding="utf-8"?>
        <opml version="1.0">
          <head><title>Pocket Casts Feeds</title></head>
          <body>
            <outline text="feeds">
              <outline type="rss" text="Tidewater Weekly" xmlUrl="https://example.com/tide.xml" />
              <outline text="Folder">
                <outline type="rss" title="Field Notes &amp; More" xmlURL="feed://example.org/fn" />
              </outline>
              <outline type="rss" text="Tidewater again" xmlUrl="https://example.com/tide.xml" />
              <outline text="Not a show" />
            </outline>
          </body>
        </opml>
        """
        let shows = try OPML.parse(Data(file.utf8))
        XCTAssertEqual(shows.map(\.title), ["Tidewater Weekly", "Field Notes & More"])
        XCTAssertEqual(shows.map(\.feedURL.absoluteString), ["https://example.com/tide.xml", "https://example.org/fn"])
    }

    func testFileWithoutShowsIsAnError() {
        XCTAssertThrowsError(try OPML.parse(Data("<opml><body></body></opml>".utf8)))
        XCTAssertThrowsError(try OPML.parse(Data("not xml at all".utf8)))
    }

    func testExportReadsBackTheSame() throws {
        let shows = [
            OPML.Show(title: "Elis & John's \"Show\" <live>", feedURL: URL(string: "https://example.com/a.xml?x=1&y=2")!),
            OPML.Show(title: "Second", feedURL: URL(string: "http://example.net/b")!),
        ]
        let text = OPML.make(shows, date: Date(timeIntervalSince1970: 0))
        XCTAssertTrue(text.contains("<dateCreated>Thu, 01 Jan 1970 00:00:00 GMT</dateCreated>"))
        XCTAssertEqual(try OPML.parse(Data(text.utf8)), shows)
    }
}
