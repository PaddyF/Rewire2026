import SwiftUI
import SwiftData

struct LineupView: View {
    @EnvironmentObject var store: ArtistStore
    @Query private var allUserData: [UserArtistData]

    @State private var searchText = ""
    @State private var selectedWave: String? = nil

    private var filteredSlots: [Slot] {
        ArtistStore.filtered(store.lineup.slots, artists: store.lineup.artists,
                             searchText: searchText, wave: selectedWave)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Wave filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        FilterChip(title: "ALL", isSelected: selectedWave == nil) {
                            selectedWave = nil
                        }
                        FilterChip(title: "WAVE 1", isSelected: selectedWave == "W1", color: .rewireAccent) {
                            selectedWave = selectedWave == "W1" ? nil : "W1"
                        }
                        FilterChip(title: "WAVE 2", isSelected: selectedWave == "W2", color: .rewireSecondary) {
                            selectedWave = selectedWave == "W2" ? nil : "W2"
                        }
                        FilterChip(title: "WAVE 3", isSelected: selectedWave == "W3", color: .rewireTertiary) {
                            selectedWave = selectedWave == "W3" ? nil : "W3"
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
