import SwiftUI
import SwiftData

struct ScheduleView: View {
    @EnvironmentObject var store: ArtistStore
    @Query private var allUserData: [UserArtistData]

    @State private var selectedDay: String = "Thu"

    private let days = ["Thu", "Fri", "Sat", "Sun"]

    private var slotsForDay: [Slot] {
        store.lineup.slots
            .filter { $0.day?.contains(selectedDay) == true }
            .sorted {
                switch ($0.time, $1.time) {
                case let (a?, b?): return a < b
                case (nil, _?):   return false
                case (_?, nil):   return true
                default:          return $0.displayName.localizedCompare($1.displayName) == .orderedAscending
                }
            }
    }

    private var tbaSlots: [Slot] {
        store.lineup.slots
            .filter { $0.day == nil }
            .sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DaySelector(days: days, selectedDay: $selectedDay)
                Divider().background(Color.rewireBorder)

                if slotsForDay.isEmpty {
                    emptyDayView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(slotsForDay) { slot in
                                let userData = allUserData.first { $0.artistId == slot.id }
                                NavigationLink(destination: ArtistDetailView(slot: slot)) {
                                    ScheduleSlotRow(slot: slot, userData: userData)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.bottom, 24)
                    }
                    .background(Color.rewireBackground)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("SCHEDULE")
                            .font(.rewireTitle(15))
                            .foregroundStyle(Color.rewireAccent)
                        Text("The Hague · April 2026")
                            .font(.rewireBody(9))
                            .foregroundStyle(Color.rewireMuted)
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.rewireSurface, for: .navigationBar)
            .background(Color.rewireBackground)
        }
    }

    private var emptyDayView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("_ _ _")
                .font(.system(size: 24, weight: .light, design: .monospaced))
                .foregroundStyle(Color.rewireBorder)
            Text("TIMETABLE TBA")
                .font(.rewireData(12, weight: .bold))
                .foregroundStyle(Color.rewireMuted)
            Text("Check back closer to the festival")
                .font(.rewireBody(11))
                .foregroundStyle(Color.rewireMuted.opacity(0.6))
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.rewireBackground)
    }
}
