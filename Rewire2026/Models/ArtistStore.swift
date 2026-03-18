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

    // Conflict detection: returns bookmarked/rated slots that overlap this slot on the same day.
    // Assumes 60-minute durations. Returns [] if slot has no day or time.
    func conflicts(for slot: Slot, allUserData: [UserArtistData]) -> [Slot] {
        guard let day = slot.day, let time = slot.time, !day.contains("–") else { return [] }
        guard let slotMins = parseMinutes(time) else { return [] }
        let pickedIds = Set(allUserData
            .filter { $0.isBookmarked || $0.mustSeeRating > 0 }
            .map { $0.artistId })
        return lineup.slots.filter { other in
            guard other.id != slot.id,
                  pickedIds.contains(other.id),
                  let otherDay = other.day,
                  let otherTime = other.time,
                  otherDay == day,
                  !otherDay.contains("–"),
                  let otherMins = parseMinutes(otherTime)
            else { return false }
            return abs(slotMins - otherMins) < 60
        }
    }

    private func parseMinutes(_ time: String) -> Int? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return parts[0] * 60 + parts[1]
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
