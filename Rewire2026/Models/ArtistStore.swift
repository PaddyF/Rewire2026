import Foundation

@MainActor
class ArtistStore: ObservableObject {
    static let shared = ArtistStore()

    @Published private(set) var lineup = Lineup(artists: [:], slots: [])

    init() {
        load()
    }

    private func load() {
        guard let url = Bundle.main.url(forResource: "lineup", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("ArtistStore: lineup.json not found in bundle")
            return
        }
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            lineup = try decoder.decode(Lineup.self, from: data)
        } catch {
            print("ArtistStore: decode error — \(error)")
        }
    }

    // Pure filter used by LineupView and tests
    static func filtered(
        _ slots: [Slot],
        artists: [String: Artist],
        searchText: String,
        day: String?
    ) -> [Slot] {
        slots.filter { slot in
            if let day, !(slot.day?.contains(day) ?? false) { return false }
            guard !searchText.isEmpty else { return true }
            let q = searchText.lowercased()
            let participantText = slot.artistIds
                .compactMap { artists[$0] }
                .flatMap { [$0.genres ?? "", $0.notes ?? ""] }
                .joined(separator: " ")
            let haystack = [slot.displayName, slot.project ?? "", slot.collabNotes ?? "", participantText]
                .joined(separator: " ").lowercased()
            return haystack.contains(q)
        }
        .sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
    }
}
