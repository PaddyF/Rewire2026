import XCTest
@testable import Rewire2026

final class ArtistDataTests: XCTestCase {

    var lineup: Lineup!

    override func setUpWithError() throws {
        let bundle = Bundle(for: type(of: self))
        let url = try XCTUnwrap(
            bundle.url(forResource: "lineup", withExtension: "json"),
            "lineup.json not found in test bundle"
        )
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        lineup = try decoder.decode(Lineup.self, from: data)
    }

    // MARK: - Counts

    func testArtistCount() {
        XCTAssertEqual(lineup.artists.count, 166)
    }

    func testSlotCount() {
        XCTAssertEqual(lineup.slots.count, 128)
    }

    // MARK: - Slots

    func testWaveDistribution() {
        let counts = Dictionary(grouping: lineup.slots, by: \.wave).mapValues(\.count)
        XCTAssertEqual(counts["W1"], 45)
        XCTAssertEqual(counts["W2"], 29)
        XCTAssertEqual(counts["W3"], 54)
    }

    func testAllWavesAreValid() {
        let valid = Set(["W1", "W2", "W3"])
        let bad = lineup.slots.filter { !valid.contains($0.wave) }
        XCTAssertTrue(bad.isEmpty, "Invalid waves: \(bad.map { "\($0.displayName): \($0.wave)" })")
    }

    func testSlotIdsAreUnique() {
        let ids = lineup.slots.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Duplicate slot display names found")
    }

    func testCollabCount() {
        let collabs = lineup.slots.filter(\.isCollab)
        XCTAssertEqual(collabs.count, 40)
    }

    func testAllArtistIdsResolve() {
        let missing = lineup.slots.flatMap(\.artistIds).filter { lineup.artists[$0] == nil }
        XCTAssertTrue(missing.isEmpty, "Unresolved artist_ids: \(missing)")
    }

    func testPlusTicketSlots() {
        let plus = lineup.slots.filter(\.requiresPlusTicket).map(\.displayName).sorted()
        XCTAssertEqual(plus, ["Einstürzende Neubauten", "Oneohtrix Point Never"])
    }

    // MARK: - Artists

    func testAllArtistNamesNonEmpty() {
        let empty = lineup.artists.filter { $0.value.name.isEmpty }
        XCTAssertTrue(empty.isEmpty, "Artists with empty names: \(empty.keys)")
    }

    // MARK: - Spot checks

    func testActressSuzanneCiani() throws {
        let slot = try XCTUnwrap(lineup.slots.first { $0.displayName == "Actress & Suzanne Ciani" })
        XCTAssertTrue(slot.isCollab)
        XCTAssertEqual(slot.wave, "W1")
        XCTAssertEqual(slot.type, "World Premiere")
        XCTAssertEqual(slot.artistIds, ["actress", "suzanne-ciani"])
        XCTAssertFalse(slot.requiresPlusTicket)

        let actress = try XCTUnwrap(lineup.artists["actress"])
        XCTAssertEqual(actress.name, "Actress")
        XCTAssertEqual(actress.topRated?.title, "Splazsh")
        XCTAssertEqual(actress.topRated?.rating, 3.47)
    }

    func testOneohtrixPointNever() throws {
        let slot = try XCTUnwrap(lineup.slots.first { $0.displayName == "Oneohtrix Point Never" })
        XCTAssertEqual(slot.wave, "W1")
        XCTAssertTrue(slot.requiresPlusTicket)
        XCTAssertFalse(slot.isCollab)
    }

    func testGenreListSplitting() throws {
        let artist = try XCTUnwrap(lineup.artists["actress"])
        XCTAssertFalse(artist.genreList.isEmpty)
        XCTAssertTrue(artist.genreList.allSatisfy { $0 == $0.trimmingCharacters(in: .whitespaces) },
                      "Genre list items should have no leading/trailing whitespace")
    }
}
