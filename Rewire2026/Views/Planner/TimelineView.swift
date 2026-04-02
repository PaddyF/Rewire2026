import SwiftUI
import SwiftData

// MARK: - Layout model

private struct LayoutSlot: Identifiable {
    let slot: Slot
    let userData: UserArtistData?
    let startMinutes: Int
    let endMinutes: Int
    var lane: Int = 0

    var id: String { slot.id }

    var xPosition: CGFloat {
        CGFloat(startMinutes - 720) * TimelineConstants.ptPerMinute
    }
    var width: CGFloat {
        CGFloat(endMinutes - startMinutes) * TimelineConstants.ptPerMinute
    }
    var yPosition: CGFloat {
        TimelineConstants.rulerHeight + CGFloat(lane) * TimelineConstants.laneOffset
    }
}

private enum TimelineConstants {
    static let ptPerHour: CGFloat = 140
    static let ptPerMinute: CGFloat = ptPerHour / 60
    static let slotHeight: CGFloat = 56
    static let laneOffset: CGFloat = 62
    static let rulerHeight: CGFloat = 30
    static let startMinutes = 720   // 12:00
    static let endMinutes = 1740    // 05:00 next day (29h)
    static let totalWidth: CGFloat = CGFloat(endMinutes - startMinutes) * ptPerMinute
}

// MARK: - TimelineView

struct TimelineView: View {
    @EnvironmentObject var store: ArtistStore
    @Query private var allUserData: [UserArtistData]
    @State private var selectedDay: String = "Thu"

    private let days = ["Thu", "Fri", "Sat", "Sun"]

    private var pickedSlotIds: Set<String> {
        Set(allUserData.filter { $0.isBookmarked || $0.mustSeeRating > 0 }.map { $0.artistId })
    }

    private var picksPerDay: [String: Int] {
        var counts: [String: Int] = [:]
        for day in days {
            counts[day] = store.lineup.slots
                .filter { pickedSlotIds.contains($0.id) && $0.day?.contains(day) == true }
                .count
        }
        return counts
    }

    private var layoutSlots: [LayoutSlot] {
        let dayPicks = store.lineup.slots
            .filter { slot in
                guard pickedSlotIds.contains(slot.id),
                      let day = slot.day, day.contains(selectedDay), !day.contains("–"),
                      slot.time != nil else { return false }
                return true
            }
            .compactMap { slot -> LayoutSlot? in
                guard let mins = parseMinutes(slot.time!) else { return nil }
                let ud = allUserData.first { $0.artistId == slot.id }
                return LayoutSlot(slot: slot, userData: ud, startMinutes: max(mins, 720), endMinutes: max(mins, 720) + 60)
            }
            .sorted { $0.startMinutes < $1.startMinutes }

        return assignLanes(dayPicks)
    }

    var body: some View {
        VStack(spacing: 0) {
            DaySelector(days: days, selectedDay: $selectedDay, picksPerDay: picksPerDay)
            Divider().background(Color.rewireBorder)

            if layoutSlots.isEmpty {
                emptyState
            } else {
                TimelineContent(
                    layoutSlots: layoutSlots,
                    selectedDay: selectedDay
                )
            }
        }
    }

    private var emptyState: some View {
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
    }

    // MARK: - Lane assignment

    private func assignLanes(_ slots: [LayoutSlot]) -> [LayoutSlot] {
        var result = slots
        var laneEnds: [Int] = []

        for i in result.indices {
            var assigned = false
            for lane in laneEnds.indices {
                if result[i].startMinutes >= laneEnds[lane] {
                    result[i].lane = lane
                    laneEnds[lane] = result[i].endMinutes
                    assigned = true
                    break
                }
            }
            if !assigned {
                result[i].lane = laneEnds.count
                laneEnds.append(result[i].endMinutes)
            }
        }
        return result
    }

    private func parseMinutes(_ time: String) -> Int? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        var total = parts[0] * 60 + parts[1]
        if parts[0] < 12 { total += 24 * 60 }
        return total
    }
}

// MARK: - Timeline Content

private struct TimelineContent: View {
    let layoutSlots: [LayoutSlot]
    let selectedDay: String

    @State private var nowMinutes: Int? = nil
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private static let dayDates: [String: String] = [
        "Thu": "2026-04-23", "Fri": "2026-04-24",
        "Sat": "2026-04-25", "Sun": "2026-04-26"
    ]

    private var maxLane: Int {
        layoutSlots.map(\.lane).max() ?? 0
    }

    private var contentHeight: CGFloat {
        TimelineConstants.rulerHeight + CGFloat(maxLane + 1) * TimelineConstants.laneOffset + 20
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    HourGridlines()
                    TimeRuler()
                    WalkingConnectors(layoutSlots: layoutSlots, day: selectedDay)

                    ForEach(layoutSlots) { ls in
                        TimelineSlotBlock(layoutSlot: ls, day: selectedDay)
                            .id(ls.id)
                    }

                    if let now = nowMinutes {
                        NowLine(minutes: now, height: contentHeight, day: selectedDay)
                    }
                }
                .frame(width: TimelineConstants.totalWidth, height: max(contentHeight, 140))
                .padding(.trailing, 40)
            }
            .background(Color.rewireBackground)
            .onAppear {
                updateNow()
                scrollToFirst(proxy: proxy)
            }
            .onChange(of: selectedDay) {
                updateNow()
                scrollToFirst(proxy: proxy)
            }
            .onReceive(timer) { _ in updateNow() }
        }
    }

    private func scrollToFirst(proxy: ScrollViewProxy) {
        if let first = layoutSlots.first {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                proxy.scrollTo(first.id, anchor: .leading)
            }
        }
    }

    private func updateNow() {
        guard let dateStr = Self.dayDates[selectedDay] else { nowMinutes = nil; return }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        guard let dayStart = fmt.date(from: dateStr) else { nowMinutes = nil; return }

        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        var comps = cal.dateComponents(in: TimeZone(identifier: "Europe/Amsterdam")!, from: dayStart)
        comps.hour = 12; comps.minute = 0
        guard let windowStart = cal.date(from: comps) else { nowMinutes = nil; return }
        comps.hour = 5; comps.minute = 0
        comps.day = (comps.day ?? 0) + 1
        guard let windowEnd = cal.date(from: comps) else { nowMinutes = nil; return }

        if now >= windowStart && now <= windowEnd {
            let amsterdam = TimeZone(identifier: "Europe/Amsterdam")!
            let nowComps = cal.dateComponents(in: amsterdam, from: now)
            var mins = (nowComps.hour ?? 0) * 60 + (nowComps.minute ?? 0)
            if (nowComps.hour ?? 0) < 12 { mins += 24 * 60 }
            nowMinutes = mins
        } else {
            nowMinutes = nil
        }
    }
}

// MARK: - Hour Gridlines

private struct HourGridlines: View {
    var body: some View {
        ForEach(0..<18, id: \.self) { i in
            let hour = 12 + i
            let x = CGFloat(i) * TimelineConstants.ptPerHour
            Rectangle()
                .fill(Color.rewireBorder.opacity(hour % 24 == 0 ? 0.5 : 0.25))
                .frame(width: 1)
                .frame(maxHeight: .infinity)
                .offset(x: x)
        }
    }
}

// MARK: - Time Ruler

private struct TimeRuler: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<18, id: \.self) { i in
                let hour = (12 + i) % 24
                Text(String(format: "%02d:00", hour))
                    .font(.rewireData(9))
                    .foregroundStyle(Color.rewireMuted)
                    .frame(width: TimelineConstants.ptPerHour, alignment: .leading)
                    .padding(.leading, 4)
            }
        }
        .frame(height: TimelineConstants.rulerHeight, alignment: .bottom)
        .padding(.bottom, 4)
    }
}

// MARK: - Slot Block

private struct TimelineSlotBlock: View {
    let layoutSlot: LayoutSlot
    let day: String

    private var shortenedStage: String? {
        guard let stage = layoutSlot.slot.stage else { return nil }
        if let range = stage.range(of: " \u{2013} ") {
            return String(stage[range.upperBound...])
        }
        return stage
    }

    private var dayColor: Color {
        Color.dayColor(day)
    }

    var body: some View {
        NavigationLink(destination: ArtistDetailView(slot: layoutSlot.slot)) {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(dayColor)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(layoutSlot.slot.displayName)
                        .font(.rewireTitle(11))
                        .foregroundStyle(Color.rewireText)
                        .lineLimit(1)

                    if let stage = shortenedStage {
                        Text(stage)
                            .font(.rewireBody(9))
                            .foregroundStyle(Color.rewireMuted)
                            .lineLimit(1)
                    }

                    HStack(spacing: 4) {
                        if let ud = layoutSlot.userData, ud.mustSeeRating > 0 {
                            HStack(spacing: 1) {
                                ForEach(1...5, id: \.self) { i in
                                    Image(systemName: i <= ud.mustSeeRating ? "star.fill" : "star")
                                        .font(.system(size: 7))
                                        .foregroundStyle(i <= ud.mustSeeRating ? dayColor : Color.rewireBorder)
                                }
                            }
                        }
                        if layoutSlot.slot.worldPremiere {
                            Text("WP")
                                .font(.rewireData(7, weight: .bold))
                                .foregroundStyle(dayColor)
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)

                Spacer(minLength: 0)
            }
            .frame(width: max(layoutSlot.width, 40), height: TimelineConstants.slotHeight)
            .background(dayColor.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(dayColor.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: dayColor.opacity(0.12), radius: 4, y: 1)
        }
        .buttonStyle(.plain)
        .offset(x: layoutSlot.xPosition, y: layoutSlot.yPosition)
    }
}

// MARK: - Walking Connectors

private struct WalkingConnectors: View {
    let layoutSlots: [LayoutSlot]
    let day: String

    private var consecutivePairs: [(LayoutSlot, LayoutSlot)] {
        let sorted = layoutSlots.sorted { $0.startMinutes < $1.startMinutes }
        guard sorted.count > 1 else { return [] }
        return zip(sorted, sorted.dropFirst()).map { ($0, $1) }
    }

    var body: some View {
        ForEach(Array(consecutivePairs.enumerated()), id: \.offset) { _, pair in
            let (a, b) = pair
            let gapMinutes = b.startMinutes - a.endMinutes
            if gapMinutes > 0 {
                connectorView(from: a, to: b, gap: gapMinutes)
            }
        }
    }

    @ViewBuilder
    private func connectorView(from a: LayoutSlot, to b: LayoutSlot, gap: Int) -> some View {
        let walkMins = walkTime(a, b)
        let startX = a.xPosition + a.width
        let endX = b.xPosition
        let midX = (startX + endX) / 2
        let startY = a.yPosition + TimelineConstants.slotHeight / 2
        let endY = b.yPosition + TimelineConstants.slotHeight / 2
        let labelY = min(startY, endY) - 14

        let buffer = walkMins.map { gap - $0 }
        let color: Color = {
            guard let b = buffer else { return Color.rewireMuted.opacity(0.5) }
            if b <= 0 { return .rewireTertiary }
            if b <= 15 { return .orange }
            return Color.rewireMuted.opacity(0.5)
        }()

        Path { path in
            path.move(to: CGPoint(x: startX, y: startY))
            path.addLine(to: CGPoint(x: endX, y: endY))
        }
        .stroke(color.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

        if let wm = walkMins {
            HStack(spacing: 2) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 8))
                Text("\(wm)m")
                    .font(.rewireData(8))
            }
            .foregroundStyle(color)
            .offset(x: midX - 16, y: labelY)
        }
    }

    private func walkTime(_ a: LayoutSlot, _ b: LayoutSlot) -> Int? {
        guard let sa = a.slot.stage, let sb = b.slot.stage else { return nil }
        let mins = VenueWalkTimes.walkingMinutes(fromStage: sa, toStage: sb)
        return mins.flatMap { $0 > 0 ? $0 : nil }
    }
}

// MARK: - Now Line

private struct NowLine: View {
    let minutes: Int
    let height: CGFloat
    let day: String

    private var xPos: CGFloat {
        CGFloat(minutes - 720) * TimelineConstants.ptPerMinute
    }

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Color.dayColor(day))
                .frame(width: 6, height: 6)
            Rectangle()
                .fill(Color.dayColor(day))
                .frame(width: 2, height: height - 6)
        }
        .offset(x: xPos - 3)
    }
}
