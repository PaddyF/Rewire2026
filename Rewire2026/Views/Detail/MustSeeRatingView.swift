import SwiftUI

struct MustSeeRatingView: View {
    let rating: Int
    let onRating: (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { star in
                Button {
                    onRating(rating == star ? 0 : star)
                } label: {
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .font(.system(size: 32))
                        .foregroundStyle(star <= rating ? Color.rewireAccent : Color.rewireMuted)
                        .shadow(color: Color.rewireAccent.opacity(star <= rating ? 0.5 : 0), radius: 6)
                        .scaleEffect(star <= rating ? 1.05 : 1.0)
                        .animation(.spring(duration: 0.2), value: rating)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
