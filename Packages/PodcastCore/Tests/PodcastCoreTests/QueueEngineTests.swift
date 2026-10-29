import XCTest
@testable import PodcastCore

final class QueueEngineTests: XCTestCase {

    // Shows: LS (Top, rank 1), TW (Top, rank 2), ND (Top, unranked), FN (Bottom), SM (Off)
    let settings = QueueSettings(
        modes: ["LS": .top, "TW": .top, "ND": .top, "FN": .bottom, "SM": .off],
        topRank: ["LS", "TW"],
        keepShowOrder: true
    )

    func ep(_ id: String, _ show: String, day: Int) -> Episode {
        Episode(id: id, showID: show, title: id, published: Date(timeIntervalSince1970: TimeInterval(day * 86_400)))
    }

    func auto(_ e: Episode) -> QueueItem { QueueItem(episode: e, source: .auto) }
    func manual(_ e: Episode) -> QueueItem { QueueItem(episode: e, source: .manual) }
    func ids(_ q: [QueueItem]) -> [String] { q.map(\.episode.id) }

    // MARK: Top shows

    func testTopShowWithNothingQueuedGoesToTop() {
        let q = [auto(ep("fn1", "FN", day: 1))]
        let result = QueueEngine.addNewEpisode(ep("ls1", "LS", day: 2), to: q, settings: settings)
        XCTAssertEqual(ids(result), ["ls1", "fn1"])
    }

    func testTopShowGoesAfterItsOwnOlderEpisodes() {
        // Paul's example: new Tidewater lands after the two Tidewater already queued.
        let q = [auto(ep("tw1", "TW", day: 1)), auto(ep("tw2", "TW", day: 2)), manual(ep("sm1", "SM", day: 1)), auto(ep("fn1", "FN", day: 1))]
        let result = QueueEngine.addNewEpisode(ep("tw3", "TW", day: 3), to: q, settings: settings)
        XCTAssertEqual(ids(result), ["tw1", "tw2", "tw3", "sm1", "fn1"])
    }

    func testFavouriteShowGoesAboveLowerRankedShow() {
        let q = [auto(ep("tw1", "TW", day: 1)), auto(ep("tw2", "TW", day: 2))]
        let result = QueueEngine.addNewEpisode(ep("ls1", "LS", day: 3), to: q, settings: settings)
        XCTAssertEqual(ids(result), ["ls1", "tw1", "tw2"])
    }

    func testLowerRankedShowGoesBelowFavourite() {
        let q = [auto(ep("ls1", "LS", day: 1)), auto(ep("fn1", "FN", day: 1))]
        let result = QueueEngine.addNewEpisode(ep("tw1", "TW", day: 2), to: q, settings: settings)
        XCTAssertEqual(ids(result), ["ls1", "tw1", "fn1"])
    }

    func testUnrankedTopShowGoesAfterRankedTopShows() {
        let q = [auto(ep("ls1", "LS", day: 1)), auto(ep("tw1", "TW", day: 1)), auto(ep("fn1", "FN", day: 1))]
        let result = QueueEngine.addNewEpisode(ep("nd1", "ND", day: 2), to: q, settings: settings)
        XCTAssertEqual(ids(result), ["ls1", "tw1", "nd1", "fn1"])
    }

    func testTopShowGoesBelowManualPlayNext() {
        let q = [manual(ep("sm1", "SM", day: 1)), auto(ep("tw1", "TW", day: 1))]
        let result = QueueEngine.addNewEpisode(ep("ls1", "LS", day: 2), to: q, settings: settings)
        XCTAssertEqual(ids(result), ["sm1", "ls1", "tw1"])
    }

    func testNewEpisodeFollowsOlderSiblingEvenIfFurtherDown() {
        // An older LS episode was added manually lower down; the new one still goes after it.
        let q = [auto(ep("tw1", "TW", day: 1)), manual(ep("ls1", "LS", day: 1)), auto(ep("fn1", "FN", day: 1))]
        let result = QueueEngine.addNewEpisode(ep("ls2", "LS", day: 5), to: q, settings: settings)
        XCTAssertEqual(ids(result), ["tw1", "ls1", "ls2", "fn1"])
    }

    func testOlderBackfilledEpisodeGoesBeforeNewerSibling() {
        let q = [auto(ep("tw2", "TW", day: 2))]
        let result = QueueEngine.addNewEpisode(ep("tw1", "TW", day: 1), to: q, settings: settings)
        XCTAssertEqual(ids(result), ["tw1", "tw2"])
    }

    // MARK: Bottom and Off

    func testBottomShowAppends() {
        let q = [auto(ep("ls1", "LS", day: 1))]
        let result = QueueEngine.addNewEpisode(ep("fn1", "FN", day: 2), to: q, settings: settings)
        XCTAssertEqual(ids(result), ["ls1", "fn1"])
    }

    func testBottomShowStaysAfterItsOlderEpisodeNotAtEnd() {
        let q = [auto(ep("fn1", "FN", day: 1)), manual(ep("sm1", "SM", day: 1))]
        let result = QueueEngine.addNewEpisode(ep("fn2", "FN", day: 2), to: q, settings: settings)
        XCTAssertEqual(ids(result), ["fn1", "fn2", "sm1"])
    }

    func testOffShowIsIgnored() {
        let q = [auto(ep("ls1", "LS", day: 1))]
        let result = QueueEngine.addNewEpisode(ep("sm9", "SM", day: 2), to: q, settings: settings)
        XCTAssertEqual(ids(result), ["ls1"])
    }

    func testAlreadyQueuedEpisodeIsNotDuplicated() {
        let e = ep("ls1", "LS", day: 1)
        let result = QueueEngine.addNewEpisode(e, to: [auto(e)], settings: settings)
        XCTAssertEqual(ids(result), ["ls1"])
    }

    func testSeveralNewEpisodesAreAddedOldestFirst() {
        let new = [ep("tw3", "TW", day: 3), ep("tw1", "TW", day: 1), ep("tw2", "TW", day: 2)]
        let result = QueueEngine.addNewEpisodes(new, to: [], settings: settings)
        XCTAssertEqual(ids(result), ["tw1", "tw2", "tw3"])
    }

    // MARK: Manual adds

    func testPlayNextGoesToTop() {
        let q = [auto(ep("ls1", "LS", day: 1))]
        let result = QueueEngine.playNext(ep("sm1", "SM", day: 1), in: q, settings: settings)
        XCTAssertEqual(ids(result), ["sm1", "ls1"])
    }

    func testPlayNextKeepsShowOrder() {
        let q = [auto(ep("ls1", "LS", day: 1)), auto(ep("tw1", "TW", day: 1)), auto(ep("tw2", "TW", day: 2))]
        let result = QueueEngine.playNext(ep("tw3", "TW", day: 3), in: q, settings: settings)
        XCTAssertEqual(ids(result), ["ls1", "tw1", "tw2", "tw3"])
    }

    func testPlayNextIgnoresShowOrderWhenSettingOff() {
        var loose = settings
        loose.keepShowOrder = false
        let q = [auto(ep("tw1", "TW", day: 1))]
        let result = QueueEngine.playNext(ep("tw2", "TW", day: 2), in: q, settings: loose)
        XCTAssertEqual(ids(result), ["tw2", "tw1"])
    }

    func testPlayLastKeepsShowOrder() {
        let q = [auto(ep("tw2", "TW", day: 2)), auto(ep("fn1", "FN", day: 1))]
        let result = QueueEngine.playLast(ep("tw1", "TW", day: 1), in: q, settings: settings)
        XCTAssertEqual(ids(result), ["tw1", "tw2", "fn1"])
    }

    func testPlayNextSeveralKeepsThemOldestFirst() {
        let q = [auto(ep("fn1", "FN", day: 1))]
        let result = QueueEngine.playNext([ep("sm3", "SM", day: 3), ep("sm1", "SM", day: 1)], in: q, settings: settings)
        XCTAssertEqual(ids(result), ["sm1", "sm3", "fn1"])
    }

    // MARK: Completion and ranking

    func testCompletionRemovesEpisode() {
        let q = [auto(ep("ls1", "LS", day: 1)), auto(ep("tw1", "TW", day: 1))]
        XCTAssertEqual(ids(QueueEngine.complete("ls1", in: q)), ["tw1"])
    }

    func testReRankingResortsTopEpisodesOnly() {
        let q = [auto(ep("ls1", "LS", day: 1)), auto(ep("tw1", "TW", day: 1)), auto(ep("tw2", "TW", day: 2)), manual(ep("sm1", "SM", day: 1)), auto(ep("fn1", "FN", day: 1))]
        var swapped = settings
        swapped.topRank = ["TW", "LS"]
        let result = QueueEngine.applyRanking(to: q, settings: swapped)
        XCTAssertEqual(ids(result), ["tw1", "tw2", "ls1", "sm1", "fn1"])
    }

    // MARK: Keep playing new episodes

    func testContinuationPrefersFavouriteTopShowOldestFirst() {
        let candidates = [ep("fn1", "FN", day: 1), ep("tw2", "TW", day: 5), ep("ls2", "LS", day: 4), ep("ls1", "LS", day: 3)]
        XCTAssertEqual(QueueEngine.continuation(from: candidates, settings: settings)?.id, "ls1")
    }

    func testContinuationIgnoresOffShowsAndCanBeEmpty() {
        XCTAssertNil(QueueEngine.continuation(from: [ep("sm1", "SM", day: 1)], settings: settings))
        XCTAssertNil(QueueEngine.continuation(from: [], settings: settings))
    }
}
