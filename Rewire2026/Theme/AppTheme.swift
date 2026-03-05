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
