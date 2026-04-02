import SwiftUI
import SwiftData

// MARK: - World Premiere Badge

struct WorldPremiereBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.system(size: 8))
            Text("WORLD PREMIERE")
                .font(.rewireData(10, weight: .bold))
        }
        .foregroundStyle(Color.rewireBackground)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.rewireTertiary)
        .clipShape(Capsule())
    }
}

// MARK: - Day Badge

struct DayBadge: View {
    let day: String?

    var body: some View {
        Text(day?.uppercased() ?? "TBA")
            .font(.rewireData(10, weight: .bold))
            .foregroundStyle(day != nil ? Color.rewireBackground : Color.rewireMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.dayColor(day))
            .clipShape(Capsule())
    }
}

// MARK: - Wave Badge

struct WaveBadge: View {
    let wave: String

    var body: some View {
        Text(wave)
            .font(.rewireData(10, weight: .bold))
            .foregroundStyle(Color.rewireBackground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.waveColor(wave))
            .clipShape(Capsule())
    }
}

// MARK: - Type Badge

struct TypeBadge: View {
    let type: String

    private var color: Color {
        let lower = type.lowercased()
        if lower.contains("world premiere") || lower.contains("commission") {
            return Color.rewireTertiary
        }
        if lower.contains("installation") {
            return Color.rewireSecondary
        }
        if lower.contains("dj") || lower.contains("b2b") {
            return Color.rewireMuted
        }
        return Color.rewireBorder
    }

    private var textColor: Color {
        let lower = type.lowercased()
        if lower.contains("world premiere") || lower.contains("commission") {
            return Color.rewireBackground
        }
        if lower.contains("installation") {
            return Color.rewireBackground
        }
        if lower.contains("dj") || lower.contains("b2b") {
            return Color.rewireBackground
        }
        return Color.rewireMuted
    }

    var body: some View {
        Text(type)
            .font(.rewireData(10))
            .foregroundStyle(textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .clipShape(Capsule())
            .lineLimit(1)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var color: Color = .rewireAccent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.rewireData(12))
                .foregroundStyle(isSelected ? Color.rewireBackground : color)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? color : Color.rewireSurface)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? color : Color.rewireBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Genre Tag

struct GenreTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.rewireBody(10))
            .foregroundStyle(Color.rewireText)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color.rewireSurface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.rewireBorder, lineWidth: 1))
    }
}

// MARK: - Release Row

struct ReleaseRow: View {
    let label: String
    let release: Release

    private var titleLine: String {
        var parts: [String] = []
        if let t = release.title { parts.append(t) }
        if let a = release.artist { parts.append("(\(a))") }
        return parts.joined(separator: " ")
    }

    private var metaLine: String {
        var parts: [String] = []
        if let y = release.year { parts.append(String(y)) }
        if let l = release.label { parts.append(l) }
        if let n = release.note { parts.append(n) }
        if let r = release.rating, let v = release.votes {
            parts.append("\(r) / \(v.formatted())")
        } else if let r = release.rating {
            parts.append(String(r))
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.rewireData(9, weight: .bold))
                .foregroundStyle(Color.rewireMuted)
            if !titleLine.isEmpty {
                Text(titleLine)
                    .font(.rewireBody(13))
                    .foregroundStyle(Color.rewireText)
            }
            if !metaLine.isEmpty {
                Text(metaLine)
                    .font(.rewireData(11))
                    .foregroundStyle(Color.rewireMuted)
            }
        }
    }
}

// MARK: - Schedule Slot Row (shared between ScheduleView and PlannerView)

struct ScheduleSlotRow: View {
    let slot: Slot
    let userData: UserArtistData?

    private var dayColor: Color { Color.slotDayColor(slot.day) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time column
            VStack(alignment: .trailing, spacing: 2) {
                if let time = slot.formattedTime {
                    Text(time)
                        .font(.rewireData(13, weight: .semibold))
                        .foregroundStyle(dayColor)
                } else {
                    Text("TBA")
                        .font(.rewireData(11))
                        .foregroundStyle(Color.rewireBorder)
                }
                if let stage = slot.stage {
                    Text(stage)
                        .font(.rewireBody(9))
                        .foregroundStyle(Color.rewireMuted)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                }
            }
            .frame(width: 72, alignment: .trailing)

            // Accent line — rounded
            RoundedRectangle(cornerRadius: 1.5)
                .fill(dayColor)
                .frame(width: 3)
                .padding(.top, 3)

            // Content
            VStack(alignment: .leading, spacing: 5) {
                Text(slot.displayName)
                    .font(.rewireTitle(14))
                    .foregroundStyle(Color.rewireText)
                    .multilineTextAlignment(.leading)

                if let project = slot.project {
                    Text(project)
                        .font(.rewireBody(11))
                        .foregroundStyle(Color.rewireMuted)
                }

                HStack(spacing: 5) {
                    if slot.isWorldPremiere { WorldPremiereBadge() }
                    if let type = slot.performanceType { TypeBadge(type: type) }
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
        .padding(14)
        .cardStyle(dayColor: dayColor)
        .padding(.horizontal, 16)
    }
}

// MARK: - Plus Ticket Warning

struct PlusTicketWarning: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "ticket")
                .foregroundStyle(Color.rewireTertiary)
            Text("Requires Plus Ticket")
                .font(.rewireData(12))
                .foregroundStyle(Color.rewireTertiary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.rewireTertiary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.rewireTertiary.opacity(0.4), lineWidth: 1))
    }
}
