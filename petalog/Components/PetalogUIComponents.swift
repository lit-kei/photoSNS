import SwiftUI

struct StickerUploadBanner: View {
    @ObservedObject var coordinator: StickerUploadCoordinator
    @ObservedObject private var networkMonitor: NetworkMonitor

    init(coordinator: StickerUploadCoordinator) {
        self.coordinator = coordinator
        self._networkMonitor = ObservedObject(wrappedValue: coordinator.networkMonitor)
    }

    var body: some View {
        if coordinator.state != .idle {
            HStack(spacing: 12) {
                statusIcon
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.mainText)
                    if let detailText {
                        Text(detailText)
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryText)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 4)
                actions
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(AppColors.elevatedSurface.opacity(0.98))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.16), radius: 14, y: 7)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.3, dampingFraction: 0.86), value: coordinator.state)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch coordinator.state {
        case .success:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failure:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
        default:
            ProgressView().tint(AppColors.mainText)
        }
    }

    private var title: String {
        switch coordinator.state {
        case .idle: ""
        case .uploading: "画像をアップロード中"
        case .resolvingURL: "画像URLを確認中"
        case .savingPost: "投稿情報を保存中"
        case .success: "投稿しました"
        case .failure: "投稿できませんでした"
        }
    }

    private var detailText: String? {
        switch coordinator.state {
        case .failure(let message):
            message
        case .success:
            "絵日記への保存が完了しました。"
        default:
            nil
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch coordinator.state {
        case .failure:
            HStack(spacing: 8) {
                Button("再試行") { coordinator.retry() }
                    .font(.caption.weight(.semibold))
                    .disabled(networkMonitor.status != .online)
                Button { coordinator.dismissBanner() } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("閉じる")
            }
        case .success:
            Button { coordinator.dismissBanner() } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("閉じる")
        default:
            EmptyView()
        }
    }
}

struct PetalogMetalBackground: View {
    var body: some View {
        AppColors.appBackground
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
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(AppColors.surface.opacity(colorScheme == .dark ? 0.98 : 0.96))
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.18 : 0.05), radius: 8, y: 3)
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
            .foregroundStyle(colorScheme == .dark ? AppColors.ink : AppColors.mainText)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background {
                if colorScheme == .dark {
                    RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                        .fill(AppColors.neonLime)
                } else {
                    RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                        .fill(AppColors.dustyPink.opacity(0.72))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.14 : 0.04), radius: 6, y: 2)
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
                    RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                        .fill(AppColors.elevatedSurface.opacity(configuration.isPressed ? 0.88 : 0.98))
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
    @Environment(\.colorScheme) private var colorScheme
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isSelected ? AppColors.mainText : AppColors.mainText)
            .background {
                if isSelected {
                    Rectangle()
                        .fill(colorScheme == .dark ? AppColors.neonLime.opacity(0.90) : AppColors.dustyPink.opacity(0.30))
                } else {
                    Rectangle().fill(AppColors.surface.opacity(0.92))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.chip, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.chip, style: .continuous)
                    .stroke(isSelected ? (colorScheme == .dark ? AppColors.neonLime.opacity(0.58) : AppColors.dustyPink.opacity(0.42)) : AppColors.border, lineWidth: 0.8)
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
                    .foregroundStyle(selection == tab && colorScheme == .dark ? AppColors.ink : (selection == tab ? AppColors.mainText : AppColors.secondaryText))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background {
                        if selection == tab {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(colorScheme == .dark ? AppColors.neonLime.opacity(0.95) : AppColors.dustyPink.opacity(0.26))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .stroke(colorScheme == .dark ? .white.opacity(0.18) : AppColors.dustyPink.opacity(0.35), lineWidth: 0.8)
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
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.tabBar, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.8)
        }
        .shadow(color: colorScheme == .dark ? .black.opacity(0.44) : AppColors.kraftBeige.opacity(0.24), radius: 16, y: 8)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: selection)
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
