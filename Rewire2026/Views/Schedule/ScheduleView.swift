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
                // Sort by time when available, then alphabetically
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
                // Day selector
                HStack(spacing: 0) {
                    ForEach(days, id: \.self) { day in
                        let isSelected = selectedDay == day
                        Button {
                            selectedDay = day
                        } label: {
                            VStack(spacing: 4) {
                                Text(day.uppercased())
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(isSelected ? Color.dayColor(day) : Color.rewireMuted)
                                Rectangle()
                                    .fill(isSelected ? Color.dayColor(day) : Color.clear)
                                    .frame(height: 2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color.rewireSurface)

                Divider().background(Color.rewireBorder)

                if slotsForDay.isEmpty {
                    emptyDayView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: []) {
                            ForEach(slotsForDay) { slot in
                                let userData = allUserData.first { $0.artistId == slot.id }
                                NavigationLink(destination: ArtistDetailView(slot: slot)) {
                                    ScheduleSlotRow(slot: slot, userData: userData)
                                }
                                .buttonStyle(.plain)
                                Divider().background(Color.rewireBorder)
                            }
                        }
                        .padding(.bottom, 32)
                    }
                    .background(Color.rewireBackground)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("SCHEDULE")
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

    private var emptyDayView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("_ _ _")
                .font(.system(size: 24, weight: .light, design: .monospaced))
                .foregroundStyle(Color.rewireBorder)
            Text("TIMETABLE TBA")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.rewireMuted)
            Text("Check back closer to the festival")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.rewireMuted.opacity(0.6))
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.rewireBackground)
    }
}

// MARK: - Schedule slot row

private struct ScheduleSlotRow: View {
    let slot: Slot
    let userData: UserArtistData?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time column
            VStack(alignment: .trailing, spacing: 2) {
                if let time = slot.time {
                    Text(time)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.dayColor(slot.day))
                } else {
                    Text("TBA")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.rewireBorder)
                }
                if let stage = slot.stage {
                    Text(stage)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color.rewireMuted)
                        .multilineTextAlignment(.trailing)
                }
            }
            .frame(width: 56, alignment: .trailing)

            // Accent line
            Rectangle()
                .fill(Color.dayColor(slot.day))
                .frame(width: 2)
                .padding(.top, 3)

            // Content
            VStack(alignment: .leading, spacing: 5) {
                Text(slot.displayName)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.rewireText)
                    .multilineTextAlignment(.leading)

                if let project = slot.project {
                    Text(project)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.rewireMuted)
                }

                HStack(spacing: 5) {
                    if slot.isWorldPremiere { WorldPremiereBadge() }
                    if let type = slot.performanceType { TypeBadge(type: type) }
                    else if !slot.isWorldPremiere, let type = slot.type { TypeBadge(type: type) }
                }

                if let rating = userData?.mustSeeRating, rating > 0 {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: i <= rating ? "star.fill" : "star")
                                .font(.system(size: 8))
                                .foregroundStyle(i <= rating ? Color.rewireAccent : Color.rewireBorder)
                        }
                    }
                }
            }

            Spacer()

            if userData?.isBookmarked == true {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.rewireSecondary)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.rewireBackground)
    }
}
