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
    static let accentPink = Color(red: 1.0, green: 0.702, blue: 0.086)
    static let accentBlue = Color(red: 0.776, green: 0.886, blue: 1.0)
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
