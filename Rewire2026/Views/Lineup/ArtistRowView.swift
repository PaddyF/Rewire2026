import SwiftUI

struct ArtistRowView: View {
    let slot: Slot
    let artists: [String: Artist]
    let userData: UserArtistData?

    // Genres from first participant (good enough for the row)
    private var genrePreview: String {
        slot.artistIds.first
            .flatMap { artists[$0]?.genreList.prefix(3) }
            .map { $0.joined(separator: " · ") } ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.displayName)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.rewireText)
                    if let project = slot.project, !project.isEmpty {
                        Text(project)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.rewireMuted)
                    }
                }
                Spacer()
                WaveBadge(wave: slot.wave)
            }

            if !genrePreview.isEmpty {
                Text(genrePreview)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.rewireMuted)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                if let type = slot.type {
                    TypeBadge(type: type)
                }
                Spacer()
                if let rating = userData?.mustSeeRating, rating > 0 {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: i <= rating ? "star.fill" : "star")
                                .font(.system(size: 9))
                                .foregroundStyle(i <= rating ? Color.rewireAccent : Color.rewireBorder)
                        }
                    }
                }
                if userData?.isBookmarked == true {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.rewireSecondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
