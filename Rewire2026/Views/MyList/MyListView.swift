import SwiftUI
import SwiftData

struct MyListView: View {
    @EnvironmentObject var store: ArtistStore
    @Query private var allUserData: [UserArtistData]

    private var myList: [(slot: Slot, userData: UserArtistData)] {
        allUserData
            .filter { $0.isBookmarked || $0.mustSeeRating > 0 }
            .compactMap { ud in
                guard let slot = store.lineup.slots.first(where: { $0.id == ud.artistId }) else { return nil }
                return (slot, ud)
            }
            .sorted { $0.userData.mustSeeRating > $1.userData.mustSeeRating }
    }

    var body: some View {
        NavigationStack {
            Group {
                if myList.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(myList, id: \.slot.id) { item in
                                NavigationLink(destination: ArtistDetailView(slot: item.slot)) {
                                    MyListRowView(slot: item.slot, userData: item.userData)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .background(Color.rewireBackground)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("MY LIST")
                        .font(.rewireTitle(15))
                        .foregroundStyle(Color.rewireAccent)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.rewireSurface, for: .navigationBar)
            .background(Color.rewireBackground)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "star")
                .font(.system(size: 48))
                .foregroundStyle(Color.rewireMuted)
            Text("No picks yet")
                .font(.rewireTitle(16))
                .foregroundStyle(Color.rewireText)
            Text("Bookmark artists or give them a Must See rating to build your list.")
                .font(.rewireBody(13))
                .foregroundStyle(Color.rewireMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.rewireBackground)
    }
}

struct MyListRowView: View {
    let slot: Slot
    let userData: UserArtistData

    private var dayColor: Color { Color.slotDayColor(slot.day) }

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(dayColor)
                .frame(width: 3)
                .padding(.vertical, 6)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(slot.displayName)
                            .font(.rewireTitle(14))
                            .foregroundStyle(Color.rewireText)
                        if let project = slot.project, !project.isEmpty {
                            Text(project)
                                .font(.rewireBody(11))
                                .foregroundStyle(Color.rewireMuted)
                        }
                    }
                    Spacer()
                    DayBadge(day: slot.day)
                }

                HStack {
                    if userData.mustSeeRating > 0 {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { i in
                                Image(systemName: i <= userData.mustSeeRating ? "star.fill" : "star")
                                    .font(.system(size: 11))
                                    .foregroundStyle(i <= userData.mustSeeRating ? Color.rewireAccent : Color.rewireBorder)
                                    .shadow(color: Color.rewireAccent.opacity(i <= userData.mustSeeRating ? 0.4 : 0), radius: 4)
                            }
                        }
                    }
                    if userData.isBookmarked {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.rewireSecondary)
                    }
                    Spacer()
                    if !userData.personalNotes.isEmpty {
                        Text(userData.personalNotes)
                            .font(.rewireBody(11))
                            .foregroundStyle(Color.rewireMuted)
                            .lineLimit(1)
                            .frame(maxWidth: 160, alignment: .trailing)
                    }
                }
            }
            .padding(10)
        }
        .cardStyle(dayColor: dayColor)
    }
}
