import SwiftUI

struct PetalogMetalBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppColors.backgroundTop,
                    Color(red: 0.93, green: 0.936, blue: 0.942),
                    AppColors.backgroundBottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    AppColors.chromeHighlight.opacity(0.9),
                    AppColors.silver.opacity(0.18),
                    .clear
                ],
                center: UnitPoint(x: 0.52, y: 0.08),
                startRadius: 24,
                endRadius: 360
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [
                    AppColors.darkSilver.opacity(0.12),
                    .clear
                ],
                center: UnitPoint(x: 0.92, y: 0.78),
                startRadius: 30,
                endRadius: 340
            )

            Canvas { context, size in
                for index in 0..<180 {
                    let x = CGFloat((index * 37) % 100) / 100 * size.width
                    let y = CGFloat((index * 71) % 100) / 100 * size.height
                    let opacity = index.isMultiple(of: 2) ? 0.055 : 0.032
                    var dot = Path()
                    dot.addEllipse(in: CGRect(x: x, y: y, width: 0.7, height: 0.7))
                    context.fill(dot, with: .color(AppColors.mainText.opacity(opacity)))
                }
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

struct BrandWordmark: View {
    var body: some View {
        Text("petalog")
            .font(.system(size: 38, weight: .bold, design: .rounded))
            .foregroundStyle(AppColors.mainText)
            .tracking(0.2)
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
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(AppColors.surface.opacity(0.94))
                    .overlay {
                        LinearGradient(
                            colors: [
                                AppColors.chromeHighlight.opacity(0.9),
                                AppColors.silver.opacity(0.18),
                                AppColors.elevatedSurface.opacity(0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.045), radius: 12, y: 5)
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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
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
                                AppColors.charcoal,
                                Color(red: 0.20, green: 0.21, blue: 0.23),
                                AppColors.darkSilver.opacity(0.86)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                            .stroke(.white.opacity(configuration.isPressed ? 0.18 : 0.28), lineWidth: 0.8)
                    }
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.86), value: configuration.isPressed)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
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
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .fill(AppColors.surface.opacity(configuration.isPressed ? 0.82 : 0.96))
                    .overlay {
                        LinearGradient(
                            colors: [.white.opacity(0.86), AppColors.silver.opacity(0.22)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 0.8)
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
                    .fill(AppColors.surface.opacity(configuration.isPressed ? 0.84 : 0.95))
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
    let systemName: String
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(AppColors.mainText)
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(AppColors.surface.opacity(0.92))
                    .overlay {
                        LinearGradient(
                            colors: [.white.opacity(0.92), AppColors.silver.opacity(0.18)],
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
                    .fill(AppColors.elevatedSurface.opacity(0.94))
                    .overlay {
                        LinearGradient(
                            colors: [AppColors.chromeHighlight.opacity(0.86), AppColors.silver.opacity(0.14)],
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
            .foregroundStyle(isSelected ? .white : AppColors.mainText)
            .background {
                if isSelected {
                    LinearGradient(
                        colors: [
                            AppColors.charcoal,
                            Color(red: 0.28, green: 0.29, blue: 0.31),
                            AppColors.darkSilver.opacity(0.88)
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
                    .stroke(isSelected ? .white.opacity(0.24) : AppColors.border, lineWidth: 0.8)
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
                    .background(AppColors.surface.opacity(0.94))
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
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.8)
        }
    }
}

struct FloatingTabBar: View {
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
                    .foregroundStyle(selection == tab ? AppColors.mainText : AppColors.darkSilver)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background {
                        if selection == tab {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            AppColors.chromeHighlight,
                                            AppColors.silver.opacity(0.42),
                                            AppColors.elevatedSurface
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay {
                                    Capsule().stroke(.white.opacity(0.82), lineWidth: 0.7)
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
                .fill(AppColors.surface.opacity(0.92))
                .overlay {
                    LinearGradient(
                        colors: [
                            .white.opacity(0.9),
                            AppColors.silver.opacity(0.22),
                            AppColors.chromeHighlight.opacity(0.68)
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
        .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: selection)
    }
}

extension AppTab: CaseIterable, Identifiable {
    var id: Self { self }

    static var allCases: [AppTab] {
        [.home, .camera, .memories, .profile]
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
