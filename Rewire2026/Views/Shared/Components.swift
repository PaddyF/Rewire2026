import SwiftUI

// MARK: - World Premiere Badge

struct WorldPremiereBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.system(size: 8))
            Text("WORLD PREMIERE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(Color.rewireBackground)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.rewireTertiary)
    }
}

// MARK: - Day Badge

struct DayBadge: View {
    let day: String?

    var body: some View {
        Text(day?.uppercased() ?? "TBA")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(day != nil ? Color.rewireBackground : Color.rewireMuted)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.dayColor(day))
    }
}

// MARK: - Wave Badge

struct WaveBadge: View {
    let wave: String

    var body: some View {
        Text(wave)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.rewireBackground)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.waveColor(wave))
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
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(textColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color)
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
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(isSelected ? Color.rewireBackground : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : Color.rewireSurface)
                .overlay(
                    Rectangle()
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
            .font(.system(size: 10, weight: .regular, design: .monospaced))
            .foregroundStyle(Color.rewireText)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.rewireSurface)
            .overlay(Rectangle().stroke(Color.rewireBorder, lineWidth: 1))
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
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.rewireMuted)
            if !titleLine.isEmpty {
                Text(titleLine)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.rewireText)
            }
            if !metaLine.isEmpty {
                Text(metaLine)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.rewireMuted)
            }
        }
    }
}

// MARK: - Plus Ticket Warning

struct PlusTicketWarning: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "ticket")
                .foregroundStyle(Color.rewireTertiary)
            Text("Requires Plus Ticket")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.rewireTertiary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.rewireTertiary.opacity(0.12))
        .overlay(Rectangle().stroke(Color.rewireTertiary.opacity(0.4), lineWidth: 1))
    }
}
