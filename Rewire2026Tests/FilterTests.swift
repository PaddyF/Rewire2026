import XCTest
@testable import Rewire2026

final class FilterTests: XCTestCase {

    // Fixture artists (slug → Artist)
    let artists: [String: Artist] = [
        "tortoise":   Artist(name: "Tortoise",   genres: "Post-Rock, Krautrock, IDM",
                             latest: nil, topRated: nil, notes: "Chicago legends."),
        "kim-gordon": Artist(name: "Kim Gordon", genres: "Noise Rock, Art Rock",
                             latest: nil, topRated: nil, notes: "World premiere of PLAY ME."),
        "blawan":     Artist(name: "Blawan",     genres: "Industrial Techno, UK Bass",
                             latest: nil, topRated: nil, notes: "Special live set."),
        "park-jiha":  Artist(name: "Park Jiha",  genres: "Post-Minimalism, Ambient",
                             latest: nil, topRated: nil, notes: "Plays piri and saenghwang."),
    ]

    // Fixture slots
    var slots: [Slot] {[
        Slot(displayName: "Tortoise",   day: nil, time: nil, stage: nil, wave: "W1",
             type: "Live",          isCollab: false, artistIds: ["tortoise"],   project: nil,
             collabNotes: nil, collabLatest: nil, collabTopRated: nil),
        Slot(displayName: "Kim Gordon", day: nil, time: nil, stage: nil, wave: "W2",
             type: "World Premiere", isCollab: false, artistIds: ["kim-gordon"], project: nil,
             collabNotes: nil, collabLatest: nil, collabTopRated: nil),
        Slot(displayName: "Blawan",     day: nil, time: nil, stage: nil, wave: "W1",
             type: "Live Set",      isCollab: false, artistIds: ["blawan"],     project: nil,
             collabNotes: nil, collabLatest: nil, collabTopRated: nil),
        Slot(displayName: "Park Jiha",  day: nil, time: nil, stage: nil, wave: "W2",
             type: "Live (solo)",   isCollab: false, artistIds: ["park-jiha"],  project: nil,
             collabNotes: nil, collabLatest: nil, collabTopRated: nil),
    ]}

    // MARK: - No filter

    func testNoFilterReturnsAll() {
        XCTAssertEqual(ArtistStore.filtered(slots, artists: artists, searchText: "", wave: nil).count, 4)
    }

    func testResultsAreSortedByDisplayName() {
        let result = ArtistStore.filtered(slots, artists: artists, searchText: "", wave: nil)
        let names = result.map(\.displayName)
        XCTAssertEqual(names, names.sorted(using: .localizedStandard))
    }

    // MARK: - Wave filter

    func testWave1Filter() {
        let result = ArtistStore.filtered(slots, artists: artists, searchText: "", wave: "W1")
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.wave == "W1" })
    }

    func testWave3FilterReturnsEmpty() {
        let result = ArtistStore.filtered(slots, artists: artists, searchText: "", wave: "W3")
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Search

    func testSearchByDisplayName() {
        let result = ArtistStore.filtered(slots, artists: artists, searchText: "Tortoise", wave: nil)
        XCTAssertEqual(result.map(\.displayName), ["Tortoise"])
    }

    func testSearchIsCaseInsensitive() {
        let a = ArtistStore.filtered(slots, artists: artists, searchText: "tortoise", wave: nil)
        let b = ArtistStore.filtered(slots, artists: artists, searchText: "TORTOISE", wave: nil)
        XCTAssertEqual(a.count, b.count)
    }

    func testSearchByArtistGenre() {
        // "Post-Rock" is in tortoise's genres (resolved via artistIds)
        let result = ArtistStore.filtered(slots, artists: artists, searchText: "Post-Rock", wave: nil)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.displayName, "Tortoise")
    }

    func testSearchByArtistNotes() {
        // "piri" is in park-jiha's notes
        let result = ArtistStore.filtered(slots, artists: artists, searchText: "piri", wave: nil)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.displayName, "Park Jiha")
    }

    func testSearchNoMatch() {
        XCTAssertTrue(ArtistStore.filtered(slots, artists: artists, searchText: "zzznomatch", wave: nil).isEmpty)
    }

    // MARK: - Combined

    func testSearchAndWave() {
        // "Kim Gordon" is W2 — should not appear when restricted to W1
        let result = ArtistStore.filtered(slots, artists: artists, searchText: "Kim Gordon", wave: "W1")
        XCTAssertTrue(result.isEmpty)
    }
}
