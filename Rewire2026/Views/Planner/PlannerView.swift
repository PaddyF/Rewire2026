import SwiftUI
import SwiftData

struct PlannerView: View {
    @EnvironmentObject var store: ArtistStore
    @Query private var allUserData: [UserArtistData]
    @State private var showTimeline = true

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
                    if showTimeline {
                        TimelineView()
                    } else {
                        ScheduleGridView()
                    }
                } else {
                    preTimetableView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("PLANNER")
                        .font(.rewireTitle(15))
                        .foregroundStyle(Color.rewireAccent)
                }
                if hasTimetable {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showTimeline.toggle()
                        } label: {
                            Image(systemName: showTimeline ? "list.bullet" : "calendar.day.timeline.leading")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.rewireAccent)
                        }
                    }
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
                            .font(.rewireData(13, weight: .bold))
                            .foregroundStyle(Color.rewireAccent)
                    }
                    Text("The full schedule (day, stage, times) hasn't been released yet. Once it drops, this screen will show a day-by-day grid with conflict detection.")
                        .font(.rewireBody(13))
                        .foregroundStyle(Color.rewireMuted)
                        .lineSpacing(4)
                }
                .padding(16)
                .cardStyle(dayColor: .rewireAccent)
                .padding(.horizontal, 16)
                .padding(.top, 16)

                if myPicks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "star.circle")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.rewireMuted)
                        Text("No picks yet")
                            .font(.rewireTitle(14))
                            .foregroundStyle(Color.rewireMuted)
                        Text("Rate or bookmark artists in the Lineup tab to see them here.")
                            .font(.rewireBody(12))
                            .foregroundStyle(Color.rewireMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YOUR PICKS SO FAR").sectionHeader()
                            .padding(.horizontal, 16)

                        LazyVStack(spacing: 8) {
                            ForEach(myPicks, id: \.slot.id) { item in
                                PlannerPickRow(slot: item.slot, userData: item.userData)
                            }
                        }
                        .padding(.horizontal, 16)
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

    private var dayColor: Color { Color.slotDayColor(slot.day) }

    var body: some View {
        HStack(spacing: 10) {
            DayBadge(day: slot.day)
            VStack(alignment: .leading, spacing: 2) {
                Text(slot.displayName)
                    .font(.rewireTitle(13))
                    .foregroundStyle(Color.rewireText)
                if let type = slot.type {
                    Text(type)
                        .font(.rewireBody(11))
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
        .padding(12)
        .cardStyle(dayColor: dayColor)
    }
}

struct ScheduleGridView: View {
    @EnvironmentObject var store: ArtistStore
    @Query private var allUserData: [UserArtistData]
    @State private var selectedDay: String = "Thu"

    private let days = ["Thu", "Fri", "Sat", "Sun"]

    private var picksPerDay: [String: Int] {
        var counts: [String: Int] = [:]
        for day in days {
            counts[day] = store.lineup.slots
                .filter { pickedSlotIds.contains($0.id) && $0.day?.contains(day) == true }
                .count
        }
        return counts
    }

    private var pickedSlotIds: Set<String> {
        Set(allUserData.filter { $0.isBookmarked || $0.mustSeeRating > 0 }.map { $0.artistId })
    }

    private var picksForDay: [Slot] {
        store.lineup.slots
            .filter { pickedSlotIds.contains($0.id) && $0.day?.contains(selectedDay) == true }
            .sorted {
                switch ($0.time, $1.time) {
                case let (a?, b?): return a < b
                case (nil, _?):   return false
                case (_?, nil):   return true
                default:          return $0.displayName.localizedCompare($1.displayName) == .orderedAscending
                }
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            DaySelector(days: days, selectedDay: $selectedDay, picksPerDay: picksPerDay)
            Divider().background(Color.rewireBorder)

            if picksForDay.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Text("_ _ _")
                        .font(.system(size: 24, weight: .light, design: .monospaced))
                        .foregroundStyle(Color.rewireBorder)
                    Text("NO PICKS FOR \(selectedDay.uppercased())")
                        .font(.rewireData(12, weight: .bold))
                        .foregroundStyle(Color.rewireMuted)
                    Text("Rate or bookmark artists in the Lineup tab")
                        .font(.rewireBody(11))
                        .foregroundStyle(Color.rewireMuted.opacity(0.6))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(Color.rewireBackground)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        // Conflict banner
                        let dayConflicts = picksForDay.filter { !store.conflicts(for: $0, allUserData: allUserData).isEmpty }
                        if !dayConflicts.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color.orange)
                                Text("\(dayConflicts.count) conflicting \(dayConflicts.count == 1 ? "pick" : "picks")")
                                    .font(.rewireData(12))
                                    .foregroundStyle(Color.orange)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.4), lineWidth: 1))
                        }

                        ForEach(Array(picksForDay.enumerated()), id: \.element.id) { index, slot in
                            let userData = allUserData.first { $0.artistId == slot.id }
                            let conflicts = store.conflicts(for: slot, allUserData: allUserData)
                            NavigationLink(destination: ArtistDetailView(slot: slot)) {
                                ScheduleSlotRow(slot: slot, userData: userData)
                                    .overlay(alignment: .topTrailing) {
                                        if !conflicts.isEmpty {
                                            HStack(spacing: 2) {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .font(.system(size: 9))
                                                Text("\(conflicts.count)")
                                                    .font(.rewireData(9, weight: .bold))
                                            }
                                            .foregroundStyle(Color.orange)
                                            .padding(6)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)

                            // Gap indicator
                            if index < picksForDay.count - 1 {
                                let next = picksForDay[index + 1]
                                GapIndicator(from: slot, to: next)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.bottom, 24)
                }
                .background(Color.rewireBackground)
            }
        }
    }

    private func minutesBetween(_ a: Slot, _ b: Slot) -> Int? {
        guard let t1 = a.time, let t2 = b.time else { return nil }
        let p1 = t1.split(separator: ":").compactMap { Int($0) }
        let p2 = t2.split(separator: ":").compactMap { Int($0) }
        guard p1.count == 2, p2.count == 2 else { return nil }
        return (p2[0] * 60 + p2[1]) - (p1[0] * 60 + p1[1])
    }

    private func walkTimeBetween(_ a: Slot, _ b: Slot) -> Int? {
        guard let sa = a.stage, let sb = b.stage else { return nil }
        return VenueWalkTimes.walkingMinutes(fromStage: sa, toStage: sb)
    }

    private func GapIndicator(from a: Slot, to b: Slot) -> some View {
        let gap = minutesBetween(a, b)
        let walk = walkTimeBetween(a, b)
        let showWalk = walk != nil && walk! > 0

        return Group {
            if let gap, gap > 60 || (showWalk && gap > 0) {
                let hours = gap / 60
                let mins = gap % 60
                let gapText = hours > 0
                    ? (mins > 0 ? "\(hours)h \(mins)m gap" : "\(hours)h gap")
                    : "\(mins)m gap"

                if showWalk {
                    let walkMins = walk!
                    let buffer = gap - walkMins
                    let walkColor: Color = buffer <= 0
                        ? .rewireTertiary
                        : buffer <= 15 ? .orange : .rewireMuted.opacity(0.5)

                    HStack(spacing: 4) {
                        Text(gapText)
                            .foregroundStyle(Color.rewireMuted.opacity(0.5))
                        Text("·")
                            .foregroundStyle(Color.rewireMuted.opacity(0.3))
                        Image(systemName: "figure.walk")
                            .foregroundStyle(walkColor)
                        Text("\(walkMins) min")
                            .foregroundStyle(walkColor)
                    }
                    .font(.rewireData(10))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                } else {
                    if gap > 60 {
                        Text(gapText)
                            .font(.rewireData(10))
                            .foregroundStyle(Color.rewireMuted.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                }
            }
        }
    }
}
