import CoreGraphics
import SwiftUI
import UIKit

enum AppColors {
    static let appBackground = adaptive(
        light: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1),
        dark: UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1)
    )
    static let backgroundTop = appBackground
    static let backgroundBottom = appBackground
    static let pureWhite = adaptive(
        light: UIColor(red: 0.995, green: 0.988, blue: 0.968, alpha: 1),
        dark: UIColor(red: 0.12, green: 0.105, blue: 0.095, alpha: 1)
    )
    static let mainText = adaptive(
        light: UIColor(red: 0.12, green: 0.105, blue: 0.095, alpha: 1),
        dark: UIColor(red: 0.965, green: 0.94, blue: 0.9, alpha: 1)
    )
    static let ink = Color(red: 0.12, green: 0.105, blue: 0.095)
    static let secondaryText = adaptive(
        light: UIColor(red: 0.46, green: 0.41, blue: 0.37, alpha: 1),
        dark: UIColor(red: 0.66, green: 0.66, blue: 0.68, alpha: 1)
    )
    static let border = adaptive(
        light: UIColor(red: 0.23, green: 0.19, blue: 0.16, alpha: 0.13),
        dark: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.13)
    )
    static let dustyPink = Color(red: 0.86, green: 0.68, blue: 0.66)
    static let mutedLavender = Color(red: 0.70, green: 0.64, blue: 0.72)
    static let kraftBeige = Color(red: 0.73, green: 0.62, blue: 0.49)
    static let burntOrange = Color(red: 0.87, green: 0.40, blue: 0.16)
    static let deepGreen = Color(red: 0.06, green: 0.25, blue: 0.20)
    static let neonLime = Color(red: 0.64, green: 1.0, blue: 0.04)
    static let electricPurple = Color(red: 0.25, green: 0.11, blue: 0.96)
    static let darkCard = Color(red: 0.135, green: 0.135, blue: 0.14)
    static let darkField = Color(red: 0.16, green: 0.16, blue: 0.17)
    static let paperCream = Color(red: 0.974, green: 0.946, blue: 0.889)
    static let tape = Color(red: 0.88, green: 0.81, blue: 0.68)
    static let silver = dustyPink
    static let darkSilver = mutedLavender
    static let chromeHighlight = pureWhite
    static let surface = adaptive(
        light: UIColor(red: 0.992, green: 0.976, blue: 0.936, alpha: 1),
        dark: UIColor(red: 0.135, green: 0.135, blue: 0.14, alpha: 1)
    )
    static let elevatedSurface = adaptive(
        light: UIColor(red: 1.0, green: 0.992, blue: 0.972, alpha: 1),
        dark: UIColor(red: 0.18, green: 0.18, blue: 0.19, alpha: 1)
    )
    static let charcoal = adaptive(
        light: UIColor(red: 0.12, green: 0.105, blue: 0.095, alpha: 1),
        dark: UIColor(red: 0.965, green: 0.94, blue: 0.9, alpha: 1)
    )

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

enum AppSpacing {
    static let screenHorizontal: CGFloat = 24
    static let screenTop: CGFloat = 28
    static let section: CGFloat = 28
    static let card: CGFloat = 18
    static let control: CGFloat = 14
    static let floatingTabClearance: CGFloat = 126
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
