import CoreGraphics
import SwiftUI

enum AppColors {
    static let backgroundTop = Color(red: 0.949, green: 0.953, blue: 0.957)
    static let backgroundBottom = Color(red: 0.898, green: 0.906, blue: 0.914)
    static let pureWhite = Color(red: 0.98, green: 0.98, blue: 0.98)
    static let mainText = Color(red: 0.067, green: 0.071, blue: 0.078)
    static let secondaryText = Color(red: 0.439, green: 0.455, blue: 0.478)
    static let border = Color(red: 0.078, green: 0.078, blue: 0.078).opacity(0.10)
    static let silver = Color(red: 0.749, green: 0.765, blue: 0.78)
    static let darkSilver = Color(red: 0.557, green: 0.576, blue: 0.6)
    static let chromeHighlight = Color(red: 0.969, green: 0.973, blue: 0.973)
    static let surface = Color(red: 0.956, green: 0.96, blue: 0.964)
    static let elevatedSurface = Color(red: 0.985, green: 0.985, blue: 0.985)
    static let charcoal = Color(red: 0.075, green: 0.079, blue: 0.087)
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
    static let card: CGFloat = 22
    static let button: CGFloat = 17
    static let field: CGFloat = 18
    static let chip: CGFloat = 17
    static let tabBar: CGFloat = 30
}

enum PetalogTheme {
    static let primary = AppColors.mainText
    static let accent = AppColors.silver
    static let glassPink = AppColors.surface
    static let glassMint = AppColors.chromeHighlight
    static let glassLavender = AppColors.darkSilver
    static let text = AppColors.mainText
    static let secondaryText = AppColors.secondaryText
    static let border = AppColors.border
    static let background = AppColors.backgroundTop
    static let readableSurface = AppColors.surface.opacity(0.92)
    static let glassBackground = LinearGradient(
        colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
        startPoint: .top,
        endPoint: .bottom
    )
    static let craft = Color(red: 0.77, green: 0.62, blue: 0.42)
    static let sky = Color(red: 0.78, green: 0.91, blue: 1.0)
    static let pinkPaper = AppColors.surface
}
