import SwiftUI

extension Color {
    static let rewireBackground = Color(hex: "0a0a0a")
    static let rewireSurface = Color(hex: "111111")
    static let rewireAccent = Color(hex: "c8ff00")
    static let rewireSecondary = Color(hex: "00d4ff")
    static let rewireTertiary = Color(hex: "ff6b35")
    static let rewireText = Color(hex: "e8e8e0")
    static let rewireMuted = Color(hex: "666666")
    static let rewireBorder = Color(hex: "222222")

    // Festival day colours
    static let dayThu = Color(hex: "c8ff00")   // lime — matches rewireAccent
    static let dayFri = Color(hex: "00d4ff")   // cyan — matches rewireSecondary
    static let daySat = Color(hex: "ff6b35")   // orange — matches rewireTertiary
    static let daySun = Color(hex: "b47fff")   // purple

    static func dayColor(_ day: String?) -> Color {
        guard let day else { return .rewireMuted }
        if day.contains("Thu") && !day.contains("–") { return .dayThu }
        if day.contains("Fri") && !day.contains("–") { return .dayFri }
        if day.contains("Sat") && !day.contains("–") { return .daySat }
        if day.contains("Sun") && !day.contains("–") { return .daySun }
        return .rewireMuted  // multi-day or unknown
    }

    static func waveColor(_ wave: String) -> Color {
        switch wave {
        case "W1": return .rewireAccent
        case "W2": return .rewireSecondary
        case "W3": return .rewireTertiary
        default:   return .rewireMuted
        }
    }

    static func slotDayColor(_ day: String?) -> Color {
        guard let day else { return .rewireMuted }
        if day.contains("Thu") { return .dayThu }
        if day.contains("Fri") { return .dayFri }
        if day.contains("Sat") { return .daySat }
        if day.contains("Sun") { return .daySun }
        return .rewireMuted
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 255, 255, 255)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - Font helpers

extension Font {
    static func rewireTitle(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static func rewireBody(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular)
    }
    static func rewireData(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - View modifiers

extension View {
    func cardStyle(dayColor: Color = .rewireBorder) -> some View {
        self
            .background(Color.rewireSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: dayColor.opacity(0.15), radius: 8, y: 2)
    }

    func sectionHeader() -> some View {
        self
            .font(.rewireData(10, weight: .bold))
            .foregroundStyle(Color.rewireMuted)
            .textCase(.uppercase)
    }
}

// MARK: - Day Selector (shared component)

struct DaySelector: View {
    let days: [String]
    @Binding var selectedDay: String
    var picksPerDay: [String: Int]? = nil

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                let isSelected = selectedDay == day
                Button { selectedDay = day } label: {
                    VStack(spacing: 4) {
                        Text(day.uppercased())
                            .font(.rewireData(13, weight: .bold))
                            .foregroundStyle(isSelected ? Color.dayColor(day) : Color.rewireMuted)
                        if let count = picksPerDay?[day], count > 0 {
                            Text("\(count)")
                                .font(.rewireData(9))
                                .foregroundStyle(isSelected ? Color.dayColor(day) : Color.rewireMuted.opacity(0.6))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.dayColor(day).opacity(0.2) : Color.clear)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.rewireSurface)
    }
}
