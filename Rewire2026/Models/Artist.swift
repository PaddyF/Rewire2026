import Foundation

// MARK: - Release

struct Release: Codable {
    let title: String?
    let year: Int?
    let label: String?
    let artist: String?
    let note: String?
    let rating: Double?
    let votes: Int?
}

// MARK: - Artist  (individual musician, keyed by slug in lineup.json)

struct Artist: Codable {
    let name: String
    let genres: String?
    let latest: Release?
    let topRated: Release?   // JSON key: top_rated (decoded via .convertFromSnakeCase)
    let notes: String?

    var genreList: [String] {
        genres?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
    }
}

// MARK: - Slot  (one performance / line-up entry)

struct Slot: Codable {
    let displayName: String   // JSON: display_name
    let day: String?
    let time: String?
    let stage: String?
    let wave: String          // "W1" | "W2" | "W3"
    let type: String?
    let isCollab: Bool        // JSON: is_collab
    let artistIds: [String]   // JSON: artist_ids
    let project: String?
    let collabNotes: String?  // JSON: collab_notes
    let collabLatest: Release?    // JSON: collab_latest
    let collabTopRated: Release?  // JSON: collab_top_rated

    var requiresPlusTicket: Bool {
        (type ?? "").lowercased().contains("plus ticket")
    }
}

extension Slot: Identifiable {
    var id: String { displayName }
}

// MARK: - Lineup  (top-level JSON object)

struct Lineup: Codable {
    let artists: [String: Artist]  // slug → Artist
    let slots: [Slot]
}
