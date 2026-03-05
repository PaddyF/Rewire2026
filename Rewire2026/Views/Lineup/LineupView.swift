import SwiftUI
import SwiftData

struct LineupView: View {
    @EnvironmentObject var store: ArtistStore
    @Query private var allUserData: [UserArtistData]

    @State private var searchText = ""
    @State private var selectedDay: String? = nil

    private var filteredSlots: [Slot] {
        ArtistStore.filtered(store.lineup.slots, artists: store.lineup.artists,
                             searchText: searchText, day: selectedDay)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Day filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        FilterChip(title: "ALL", isSelected: selectedDay == nil) {
                            selectedDay = nil
                        }
                        FilterChip(title: "THU", isSelected: selectedDay == "Thu", color: .dayThu) {
                            selectedDay = selectedDay == "Thu" ? nil : "Thu"
                        }
                        FilterChip(title: "FRI", isSelected: selectedDay == "Fri", color: .dayFri) {
                            selectedDay = selectedDay == "Fri" ? nil : "Fri"
                        }
                        FilterChip(title: "SAT", isSelected: selectedDay == "Sat", color: .daySat) {
                            selectedDay = selectedDay == "Sat" ? nil : "Sat"
                        }
                        FilterChip(title: "SUN", isSelected: selectedDay == "Sun", color: .daySun) {
                            selectedDay = selectedDay == "Sun" ? nil : "Sun"
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 10)
                .background(Color.rewireSurface)

                HStack {
                    Text("\(filteredSlots.count) of \(store.lineup.slots.count) acts")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.rewireMuted)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.rewireBackground)

                Divider().background(Color.rewireBorder)

                List(filteredSlots) { slot in
                    let userData = allUserData.first { $0.artistId == slot.id }
                    NavigationLink(destination: ArtistDetailView(slot: slot)) {
                        ArtistRowView(slot: slot,
                                      artists: store.lineup.artists,
                                      userData: userData)
                    }
                    .listRowBackground(Color.rewireBackground)
                    .listRowSeparatorTint(Color.rewireBorder)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.rewireBackground)
            }
            .searchable(text: $searchText, prompt: "Search artists, genres…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("REWIRE 2026")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.rewireAccent)
                        Text("The Hague · April 2026")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Color.rewireMuted)
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.rewireSurface, for: .navigationBar)
            .background(Color.rewireBackground)
        }
    }
}
