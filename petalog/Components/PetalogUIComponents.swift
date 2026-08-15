import SwiftUI

struct PetalogMetalBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            AppColors.appBackground

            if colorScheme == .dark {
                DarkCollageBackdrop()
            }
        }
        .ignoresSafeArea()
    }
}

struct BrandWordmark: View {
    var body: some View {
        Text("petalog")
            .font(.system(size: 39, weight: .heavy, design: .rounded))
            .foregroundStyle(AppColors.mainText)
            .tracking(0.4)
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppColors.mainText)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.secondaryText)
                    .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MetalCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    var padding: CGFloat = AppSpacing.card
    var radius: CGFloat = AppRadius.card
    let content: Content

    init(padding: CGFloat = AppSpacing.card, radius: CGFloat = AppRadius.card, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.radius = radius
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: radius + 3, style: .continuous)
                        .fill(colorScheme == .dark ? AppColors.burntOrange.opacity(0.34) : AppColors.mutedLavender.opacity(0.20))
                        .rotationEffect(.degrees(-1.8))
                        .offset(x: -4, y: 5)

                    RoundedRectangle(cornerRadius: radius + 2, style: .continuous)
                        .fill(colorScheme == .dark ? AppColors.deepGreen.opacity(0.36) : AppColors.dustyPink.opacity(0.24))
                        .rotationEffect(.degrees(1.5))
                        .offset(x: 5, y: -4)

                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(AppColors.surface.opacity(0.98))
                        .overlay {
                            LinearGradient(
                                colors: [
                                    .white.opacity(colorScheme == .dark ? 0.06 : 0.58),
                                    (colorScheme == .dark ? AppColors.burntOrange : AppColors.dustyPink).opacity(colorScheme == .dark ? 0.26 : 0.10),
                                    AppColors.kraftBeige.opacity(colorScheme == .dark ? 0.24 : 0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                        }
                        .overlay {
                            PaperGrain(opacity: colorScheme == .dark ? 0.12 : 0.07)
                                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                        }
                        .overlay(alignment: .bottomTrailing) {
                            if colorScheme == .dark {
                                ZebraPatch()
                                    .frame(width: 92, height: 46)
                                    .opacity(0.34)
                                    .rotationEffect(.degrees(-7))
                                    .offset(x: -16, y: 8)
                            }
                        }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 0.8)
            }
            .overlay(alignment: .topLeading) {
                PaperTape(width: colorScheme == .dark ? 70 : 58)
                    .rotationEffect(.degrees(colorScheme == .dark ? -6 : 0))
                    .offset(x: 18, y: -9)
            }
            .shadow(color: (colorScheme == .dark ? AppColors.burntOrange : AppColors.kraftBeige).opacity(colorScheme == .dark ? 0.30 : 0.22), radius: 12, y: 6)
    }
}

struct PrimaryButton<Label: View>: View {
    let action: () -> Void
    let label: Label

    init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.action = action
        self.label = label()
    }

    var body: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(PrimaryActionButtonStyle())
    }
}

struct SecondaryButton<Label: View>: View {
    let action: () -> Void
    let label: Label

    init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.action = action
        self.label = label()
    }

    var body: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(SecondaryActionButtonStyle())
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(AppColors.mainText)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background {
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                colorScheme == .dark ? AppColors.burntOrange : AppColors.dustyPink,
                                colorScheme == .dark ? AppColors.kraftBeige.opacity(0.98) : AppColors.mutedLavender.opacity(0.92),
                                colorScheme == .dark ? AppColors.deepGreen.opacity(0.90) : AppColors.kraftBeige.opacity(0.86)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .topLeading) {
                        if colorScheme == .dark {
                            ZebraPatch()
                                .frame(width: 108, height: 54)
                                .opacity(0.24)
                                .rotationEffect(.degrees(-6))
                                .offset(x: 10, y: -3)
                        } else {
                            CollageGrid()
                                .stroke(.white.opacity(0.18), lineWidth: 0.7)
                                .frame(width: 82, height: 54)
                                .rotationEffect(.degrees(-8))
                                .offset(x: 16, y: -7)
                        }
                    }
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                            .stroke(.white.opacity(configuration.isPressed ? 0.16 : 0.30), lineWidth: 0.8)
                    }
                    .overlay(alignment: .trailing) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white.opacity(0.08))
                            .padding(.trailing, 18)
                    }
            }
            .overlay(alignment: .topLeading) {
                PaperTape(width: colorScheme == .dark ? 56 : 44, height: 12)
                    .rotationEffect(.degrees(colorScheme == .dark ? -12 : -7))
                    .offset(x: 16, y: -6)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.86), value: configuration.isPressed)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppColors.mainText)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.button + 2, style: .continuous)
                        .fill((colorScheme == .dark ? AppColors.burntOrange : AppColors.dustyPink).opacity(colorScheme == .dark ? 0.32 : 0.22))
                        .rotationEffect(.degrees(-1.4))
                        .offset(x: -3, y: 3)
                    RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                        .fill(AppColors.elevatedSurface.opacity(configuration.isPressed ? 0.88 : 0.98))
                        .overlay {
                            LinearGradient(
                                colors: [
                                    .white.opacity(colorScheme == .dark ? 0.06 : 0.62),
                                    (colorScheme == .dark ? AppColors.burntOrange : AppColors.dustyPink).opacity(colorScheme == .dark ? 0.24 : 0.16),
                                    AppColors.kraftBeige.opacity(colorScheme == .dark ? 0.22 : 0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
                        }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 0.8)
            }
            .overlay(alignment: .topTrailing) {
                PaperTape(width: 34, height: 10)
                    .rotationEffect(.degrees(8))
                    .offset(x: -14, y: -5)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.86), value: configuration.isPressed)
    }
}

struct ListRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(AppColors.mainText)
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(AppColors.surface.opacity(configuration.isPressed ? 0.88 : 0.98))
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 0.8)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.88), value: configuration.isPressed)
    }
}

struct ControlSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        MetalCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: title)
                content
            }
        }
    }
}

struct IconButtonLabel: View {
    @Environment(\.colorScheme) private var colorScheme
    let systemName: String
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(AppColors.mainText)
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(AppColors.elevatedSurface.opacity(0.96))
                    .overlay {
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.08 : 0.76),
                                (colorScheme == .dark ? AppColors.burntOrange : AppColors.dustyPink).opacity(colorScheme == .dark ? 0.28 : 0.18),
                                AppColors.kraftBeige.opacity(colorScheme == .dark ? 0.18 : 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(Circle())
                    }
            }
            .overlay {
                Circle().stroke(AppColors.border, lineWidth: 0.8)
            }
    }
}

struct IconButton: View {
    let systemName: String
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            IconButtonLabel(systemName: systemName, size: size)
        }
        .buttonStyle(.plain)
    }
}

private struct MetalTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16))
            .foregroundStyle(AppColors.mainText)
            .padding(.horizontal, 16)
            .frame(minHeight: 54)
            .background {
                RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous)
                    .fill(AppColors.elevatedSurface.opacity(0.98))
                    .overlay {
                        LinearGradient(
                            colors: [AppColors.chromeHighlight.opacity(0.72), AppColors.dustyPink.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 0.8)
            }
    }
}

extension View {
    func metalTextField() -> some View {
        modifier(MetalTextFieldModifier())
    }
}

struct HorizontalOptionPicker<Option: PetalogOption>: View {
    let options: [Option]
    @Binding var selection: Option

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(options) { option in
                    Button {
                        selection = option
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: option.systemImage)
                                .font(.title3)
                            Text(option.title)
                                .font(.caption.weight(.semibold))
                        }
                        .frame(width: 76, height: 70)
                    }
                    .buttonStyle(OptionButtonStyle(isSelected: option.id == selection.id))
                }
            }
        }
    }
}

private struct OptionButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isSelected ? AppColors.mainText : AppColors.mainText)
            .background {
                if isSelected {
                    LinearGradient(
                        colors: [
                            AppColors.dustyPink.opacity(0.38),
                            AppColors.mutedLavender.opacity(0.22),
                            AppColors.elevatedSurface.opacity(0.86)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    Rectangle().fill(AppColors.surface.opacity(0.92))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? AppColors.dustyPink.opacity(0.42) : AppColors.border, lineWidth: 0.8)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : (isSelected ? 1.02 : 1))
            .opacity(configuration.isPressed ? 0.84 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.86), value: configuration.isPressed)
            .animation(.spring(response: 0.28, dampingFraction: 0.84), value: isSelected)
    }
}

struct MemberAvatarStack: View {
    let avatars: [String]

    var body: some View {
        HStack(spacing: -8) {
            ForEach(Array(avatars.prefix(4).enumerated()), id: \.offset) { _, avatar in
                Group {
                    if avatar.isEmpty {
                        Image(systemName: "person.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppColors.mainText.opacity(0.72))
                    } else {
                        Text(avatar)
                            .font(.title3)
                    }
                }
                    .frame(width: 34, height: 34)
                    .background(AppColors.surface.opacity(0.98))
                    .clipShape(Circle())
                    .overlay { Circle().stroke(AppColors.border, lineWidth: 0.8) }
            }
        }
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(AppColors.mainText)
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColors.mainText)
            Text(message)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColors.secondaryText)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(AppColors.surface.opacity(0.94))
                .overlay {
                    PaperGrain(opacity: 0.045)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.8)
        }
    }
}

struct FloatingTabBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 18, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(selection == tab ? AppColors.mainText : AppColors.secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background {
                        if selection == tab {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            (colorScheme == .dark ? AppColors.burntOrange : AppColors.dustyPink).opacity(colorScheme == .dark ? 0.48 : 0.32),
                                            (colorScheme == .dark ? AppColors.kraftBeige : AppColors.mutedLavender).opacity(colorScheme == .dark ? 0.38 : 0.20),
                                            AppColors.elevatedSurface.opacity(0.92)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay {
                                    Capsule().stroke(AppColors.dustyPink.opacity(0.35), lineWidth: 0.8)
                                }
                                .overlay(alignment: .topTrailing) {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle((colorScheme == .dark ? AppColors.burntOrange : AppColors.dustyPink).opacity(0.72))
                                        .offset(x: -10, y: 8)
                                }
                                .transition(.opacity.combined(with: .scale(scale: 0.94)))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 68)
        .background {
            RoundedRectangle(cornerRadius: AppRadius.tabBar, style: .continuous)
                .fill(AppColors.elevatedSurface.opacity(0.96))
                .overlay {
                    LinearGradient(
                        colors: [
                            .white.opacity(0.72),
                            colorScheme == .dark ? AppColors.deepGreen.opacity(0.25) : AppColors.paperCream.opacity(0.9),
                            AppColors.kraftBeige.opacity(colorScheme == .dark ? 0.22 : 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.tabBar, style: .continuous))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.tabBar, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.8)
        }
        .shadow(color: (colorScheme == .dark ? AppColors.burntOrange : AppColors.kraftBeige).opacity(colorScheme == .dark ? 0.30 : 0.24), radius: 16, y: 8)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: selection)
    }
}

private struct DarkCollageBackdrop: View {
    var body: some View {
        ZStack {
            TornPaperPatch(seed: 2)
                .fill(AppColors.deepGreen.opacity(0.36))
                .frame(width: 190, height: 120)
                .rotationEffect(.degrees(-11))
                .offset(x: -138, y: -252)

            TornPaperPatch(seed: 5)
                .fill(AppColors.burntOrange.opacity(0.34))
                .frame(width: 170, height: 112)
                .rotationEffect(.degrees(16))
                .offset(x: 142, y: -164)

            TornPaperPatch(seed: 8)
                .fill(AppColors.kraftBeige.opacity(0.24))
                .frame(width: 210, height: 126)
                .rotationEffect(.degrees(-8))
                .offset(x: 128, y: 276)

            ZebraPatch()
                .frame(width: 170, height: 92)
                .opacity(0.16)
                .rotationEffect(.degrees(-13))
                .offset(x: -126, y: 190)

            CollageGrid()
                .stroke(.white.opacity(0.08), lineWidth: 0.8)
                .frame(width: 132, height: 132)
                .rotationEffect(.degrees(8))
                .offset(x: 132, y: 80)
        }
        .allowsHitTesting(false)
    }
}

private struct PaperGrain: View {
    var opacity: Double

    var body: some View {
        Canvas { context, size in
            for index in 0..<90 {
                let x = CGFloat((index * 29) % 100) / 100 * size.width
                let y = CGFloat((index * 47) % 100) / 100 * size.height
                let diameter = CGFloat(index % 3 + 1) * 0.55
                var speck = Path()
                speck.addEllipse(in: CGRect(x: x, y: y, width: diameter, height: diameter))
                context.fill(speck, with: .color(AppColors.mainText.opacity(opacity)))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct TornPaperPatch: Shape {
    let seed: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = 18
        for index in 0..<points {
            let progress = CGFloat(index) / CGFloat(points)
            let angle = progress * .pi * 2
            let noise = CGFloat(((index * 37 + seed * 19) % 11) - 5) / 42
            let radiusX = rect.width * (0.48 + noise)
            let radiusY = rect.height * (0.48 - noise * 0.6)
            let point = CGPoint(
                x: rect.midX + cos(angle) * radiusX,
                y: rect.midY + sin(angle) * radiusY
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

private struct ZebraPatch: View {
    var body: some View {
        Canvas { context, size in
            let base = Path(CGRect(origin: .zero, size: size))
            context.fill(base, with: .color(.white.opacity(0.84)))

            for index in -2..<10 {
                var stripe = Path()
                let x = CGFloat(index) * size.width / 7
                stripe.move(to: CGPoint(x: x, y: 0))
                stripe.addLine(to: CGPoint(x: x + size.width * 0.22, y: 0))
                stripe.addLine(to: CGPoint(x: x + size.width * 0.52, y: size.height))
                stripe.addLine(to: CGPoint(x: x + size.width * 0.30, y: size.height))
                stripe.closeSubpath()
                context.fill(stripe, with: .color(.black.opacity(0.78)))
            }
        }
        .clipShape(TornPaperPatch(seed: 11))
    }
}

private struct PaperTape: View {
    var width: CGFloat
    var height: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(AppColors.tape.opacity(0.62))
            .frame(width: width, height: height)
            .overlay {
                PaperGrain(opacity: 0.08)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 0.5)
            }
            .shadow(color: AppColors.kraftBeige.opacity(0.18), radius: 3, y: 1)
    }
}

private struct CollageGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 18
        var x = rect.minX
        while x <= rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += step
        }
        var y = rect.minY
        while y <= rect.maxY {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += step
        }
        return path
    }
}

private struct CollageDots: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 26
        var y = rect.minY + 10
        while y < rect.maxY {
            var x = rect.minX + 10
            while x < rect.maxX {
                path.addEllipse(in: CGRect(x: x, y: y, width: 8, height: 8))
                x += step
            }
            y += step
        }
        return path
    }
}

extension AppTab: CaseIterable, Identifiable {
    var id: Self { self }

    static var allCases: [AppTab] {
        [.home, .camera]
    }

    var title: String {
        switch self {
        case .home: "ホーム"
        case .camera: "カメラ"
        case .memories: "思い出"
        case .profile: "プロフィール"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .camera: "camera"
        case .memories: "book.pages"
        case .profile: "person.crop.circle"
        }
    }
}
