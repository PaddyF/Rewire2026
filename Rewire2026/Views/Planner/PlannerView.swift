import SwiftUI
import SwiftData

struct PlannerView: View {
    @EnvironmentObject var store: ArtistStore
    @Query private var allUserData: [UserArtistData]

    private var hasTimetable: Bool {
        store.lineup.slots.contains { $0.day != nil }
    }

    private var myPicks: [(slot: Slot, userData: UserArtistData)] {
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
                if hasTimetable {
                    ScheduleGridView()
                } else {
                    preTimetableView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("PLANNER")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.rewireAccent)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.rewireSurface, for: .navigationBar)
            .background(Color.rewireBackground)
        }
    }

    private var preTimetableView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.rewireAccent)
                        Text("TIMETABLE COMING SOON")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.rewireAccent)
                    }
                    Text("The full schedule (day, stage, times) hasn't been released yet. Once it drops, this screen will show a day-by-day grid with conflict detection.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.rewireMuted)
                        .lineSpacing(4)
                }
                .padding(16)
                .background(Color.rewireSurface)
                .overlay(Rectangle().stroke(Color.rewireAccent.opacity(0.3), lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.top, 16)

                if myPicks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "star.circle")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.rewireMuted)
                        Text("No picks yet")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(Color.rewireMuted)
                        Text("Rate or bookmark artists in the Lineup tab to see them here.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.rewireMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("YOUR PICKS SO FAR")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.rewireMuted)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)

                        ForEach(myPicks, id: \.slot.id) { item in
                            PlannerPickRow(slot: item.slot, userData: item.userData)
                            Rectangle().fill(Color.rewireBorder).frame(height: 1)
                        }
                    }
                }
            }
        }
        .background(Color.rewireBackground)
    }
}

struct PlannerPickRow: View {
    let slot: Slot
    let userData: UserArtistData

    var body: some View {
        HStack(spacing: 10) {
            DayBadge(day: slot.day)
            VStack(alignment: .leading, spacing: 2) {
                Text(slot.displayName)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.rewireText)
                if let type = slot.type {
                    Text(type)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.rewireMuted)
                }
            }
            Spacer()
            if userData.mustSeeRating > 0 {
                HStack(spacing: 1) {
                    ForEach(1...5, id: \.self) { i in
                        Image(systemName: i <= userData.mustSeeRating ? "star.fill" : "star")
                            .font(.system(size: 9))
                            .foregroundStyle(i <= userData.mustSeeRating ? Color.rewireAccent : Color.rewireBorder)
                    }
                }
            }
            if userData.isBookmarked {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.rewireSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct ScheduleGridView: View {
    var body: some View {
        Text("Schedule grid")
            .foregroundStyle(Color.rewireMuted)
    }
}
