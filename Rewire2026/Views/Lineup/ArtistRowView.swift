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

    private var thumbnailUrl: URL? {
        slot.artistIds.first.flatMap { artists[$0]?.imageUrl }.flatMap { URL(string: $0) }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Thumbnail — only shown when image_url is populated
            if let url = thumbnailUrl {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .empty:
                        Color.rewireSurface
                    default:
                        Color.rewireSurface
                    }
                }
                .frame(width: 48, height: 48)
                .clipped()
            }

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
                DayBadge(day: slot.day)
            }

            if !genrePreview.isEmpty {
                Text(genrePreview)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.rewireMuted)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                if slot.isWorldPremiere { WorldPremiereBadge() }
                if let type = slot.performanceType { TypeBadge(type: type) }
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
        } // HStack
        .padding(.vertical, 4)
    }
}
