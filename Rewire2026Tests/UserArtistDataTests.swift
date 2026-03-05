import XCTest
import SwiftData
@testable import Rewire2026

/// Tests that UserArtistData persists correctly using an in-memory SwiftData store.
@MainActor
final class UserArtistDataTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: UserArtistData.self, configurations: config)
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    // MARK: - Defaults

    func testDefaultValues() {
        let data = UserArtistData(artistId: "test-artist")
        XCTAssertEqual(data.artistId, "test-artist")
        XCTAssertEqual(data.mustSeeRating, 0)
        XCTAssertEqual(data.personalNotes, "")
        XCTAssertFalse(data.isBookmarked)
    }

    // MARK: - Persistence

    func testRatingPersists() throws {
        let data = UserArtistData(artistId: "tortoise")
        context.insert(data)
        data.mustSeeRating = 4
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<UserArtistData>())
        let item = try XCTUnwrap(fetched.first { $0.artistId == "tortoise" })
        XCTAssertEqual(item.mustSeeRating, 4)
    }

    func testBookmarkPersists() throws {
        let data = UserArtistData(artistId: "blawan")
        context.insert(data)
        data.isBookmarked = true
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<UserArtistData>())
        let item = try XCTUnwrap(fetched.first { $0.artistId == "blawan" })
        XCTAssertTrue(item.isBookmarked)
    }

    func testNotesPersist() throws {
        let data = UserArtistData(artistId: "kim-gordon")
        context.insert(data)
        data.personalNotes = "Must see — front row if possible"
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<UserArtistData>())
        let item = try XCTUnwrap(fetched.first { $0.artistId == "kim-gordon" })
        XCTAssertEqual(item.personalNotes, "Must see — front row if possible")
    }

    func testRatingReset() throws {
        let data = UserArtistData(artistId: "test-artist")
        context.insert(data)
        data.mustSeeRating = 5
        try context.save()

        data.mustSeeRating = 0
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<UserArtistData>())
        let item = try XCTUnwrap(fetched.first { $0.artistId == "test-artist" })
        XCTAssertEqual(item.mustSeeRating, 0)
    }

    // MARK: - Multiple records

    func testMultipleArtistsStoredIndependently() throws {
        let a = UserArtistData(artistId: "artist-a")
        let b = UserArtistData(artistId: "artist-b")
        context.insert(a)
        context.insert(b)
        a.mustSeeRating = 5
        a.isBookmarked = true
        b.mustSeeRating = 2
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<UserArtistData>())
        XCTAssertEqual(fetched.count, 2)

        let fetchedA = try XCTUnwrap(fetched.first { $0.artistId == "artist-a" })
        let fetchedB = try XCTUnwrap(fetched.first { $0.artistId == "artist-b" })
        XCTAssertEqual(fetchedA.mustSeeRating, 5)
        XCTAssertTrue(fetchedA.isBookmarked)
        XCTAssertEqual(fetchedB.mustSeeRating, 2)
        XCTAssertFalse(fetchedB.isBookmarked)
    }
}
