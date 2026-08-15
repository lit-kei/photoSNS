import CoreGraphics
import SwiftUI
import UIKit

enum AppColors {
    static let appBackground = Color.white
    static let backgroundTop = appBackground
    static let backgroundBottom = appBackground
    static let pureWhite = Color(red: 0.995, green: 0.988, blue: 0.968)
    static let mainText = Color(red: 0.12, green: 0.105, blue: 0.095)
    static let ink = Color(red: 0.12, green: 0.105, blue: 0.095)
    static let secondaryText = Color(red: 0.46, green: 0.41, blue: 0.37)
    static let border = Color(red: 0.23, green: 0.19, blue: 0.16).opacity(0.13)
    static var accentPink: Color { DebugThemeColors.mainAccent }
    static var accentBlue: Color { DebugThemeColors.cameraAccent }
    static var dustyPink: Color { accentPink }
    static var mutedLavender: Color { accentBlue }
    static var kraftBeige: Color { accentBlue }
    static let burntOrange = Color(red: 0.87, green: 0.40, blue: 0.16)
    static let deepGreen = Color(red: 0.06, green: 0.25, blue: 0.20)
    static let electricPurple = Color(red: 0.25, green: 0.11, blue: 0.96)
    static let darkCard = Color(red: 0.135, green: 0.135, blue: 0.14)
    static let darkField = Color(red: 0.16, green: 0.16, blue: 0.17)
    static let paperCream = pureWhite
    static var tape: Color { accentBlue }
    static var silver: Color { dustyPink }
    static var darkSilver: Color { mutedLavender }
    static let chromeHighlight = pureWhite
    static let surface = pureWhite
    static let elevatedSurface = Color.white
    static let charcoal = Color(red: 0.12, green: 0.105, blue: 0.095)
}

enum DebugThemeColors {
    static let mainAccentKey = "petalog.debug.mainAccentHex"
    static let cameraAccentKey = "petalog.debug.cameraAccentHex"
    static let defaultMainAccentHex = "#ffc6c6"
    static let defaultCameraAccentHex = "#c6e2ff"

    static var mainAccent: Color {
        color(for: mainAccentKey, fallbackHex: defaultMainAccentHex)
    }

    static var cameraAccent: Color {
        color(for: cameraAccentKey, fallbackHex: defaultCameraAccentHex)
    }

    static func color(for key: String, fallbackHex: String) -> Color {
        let hex = UserDefaults.standard.string(forKey: key) ?? fallbackHex
        return Color(uiColor: UIColor(hex: hex) ?? UIColor(hex: fallbackHex) ?? .systemPink)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: mainAccentKey)
        UserDefaults.standard.removeObject(forKey: cameraAccentKey)
    }
}

extension UIColor {
    convenience init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else { return nil }
        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }

    var petalogHexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
    }
}

enum AppSpacing {
    static let screenHorizontal: CGFloat = 24
    static let screenTop: CGFloat = 28
    static let section: CGFloat = 28
    static let card: CGFloat = 18
    static let control: CGFloat = 14
    static let floatingTabClearance: CGFloat = 32
}

enum AppRadius {
    static let card: CGFloat = 14
    static let button: CGFloat = 11
    static let field: CGFloat = 12
    static let chip: CGFloat = 12
    static let tabBar: CGFloat = 18
}

enum PetalogTheme {
    static let primary = AppColors.mainText
    static let accent = AppColors.dustyPink
    static let glassPink = AppColors.surface
    static let glassMint = AppColors.chromeHighlight
    static let glassLavender = AppColors.mutedLavender
    static let text = AppColors.mainText
    static let secondaryText = AppColors.secondaryText
    static let border = AppColors.border
    static let background = AppColors.appBackground
    static let readableSurface = AppColors.surface.opacity(0.92)
    static let glassBackground = LinearGradient(
        colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
        startPoint: .top,
        endPoint: .bottom
    )
    static let craft = AppColors.kraftBeige
    static let sky = AppColors.mutedLavender.opacity(0.72)
    static let pinkPaper = AppColors.dustyPink.opacity(0.34)
}
