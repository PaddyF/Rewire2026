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
                    List(myList, id: \.slot.id) { item in
                        NavigationLink(destination: ArtistDetailView(slot: item.slot)) {
                            MyListRowView(slot: item.slot, userData: item.userData)
                        }
                        .listRowBackground(Color.rewireBackground)
                        .listRowSeparatorTint(Color.rewireBorder)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.rewireBackground)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("MY LIST")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
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
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.rewireText)
            Text("Bookmark artists or give them a Must See rating to build your list.")
                .font(.system(size: 13))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
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

            HStack {
                if userData.mustSeeRating > 0 {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: i <= userData.mustSeeRating ? "star.fill" : "star")
                                .font(.system(size: 11))
                                .foregroundStyle(i <= userData.mustSeeRating ? Color.rewireAccent : Color.rewireBorder)
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
                        .font(.system(size: 11))
                        .foregroundStyle(Color.rewireMuted)
                        .lineLimit(1)
                        .frame(maxWidth: 160, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
