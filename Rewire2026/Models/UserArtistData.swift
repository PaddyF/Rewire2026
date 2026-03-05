import SwiftData

@Model
final class UserArtistData {
    var artistId: String
    var mustSeeRating: Int   // 0 = unrated, 1–5
    var personalNotes: String
    var isBookmarked: Bool

    init(artistId: String) {
        self.artistId = artistId
        self.mustSeeRating = 0
        self.personalNotes = ""
        self.isBookmarked = false
    }
}
