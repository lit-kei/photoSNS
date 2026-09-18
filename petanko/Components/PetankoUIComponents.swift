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
            VStack(spacing: 10) {
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

                if showsProgressBar {
                    ProgressView(value: progressValue)
                        .progressViewStyle(.linear)
                        .tint(progressTint)
                        .scaleEffect(x: 1, y: 0.78, anchor: .center)
                        .accessibilityLabel(progressAccessibilityLabel)
                        .accessibilityValue(progressAccessibilityValue)
                } else if coordinator.state == .resolvingURL || coordinator.state == .savingPost {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(AppColors.accentBlue)
                        .scaleEffect(x: 1, y: 0.78, anchor: .center)
                        .accessibilityLabel("投稿処理中")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(AppColors.elevatedSurface.opacity(0.98))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 5)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.3, dampingFraction: 0.86), value: coordinator.state != .idle)
        }
    }

    private var showsProgressBar: Bool {
        switch coordinator.state {
        case .uploading, .success:
            true
        default:
            false
        }
    }

    private var progressValue: Double {
        switch coordinator.state {
        case .uploading(let progress):
            min(max(progress, 0), 1)
        case .success:
            1
        default:
            0
        }
    }

    private var progressTint: Color {
        switch coordinator.state {
        case .success:
            .green
        default:
            AppColors.accentBlue
        }
    }

    private var progressAccessibilityLabel: String {
        switch coordinator.state {
        case .success:
            "投稿完了"
        default:
            "アップロード進捗"
        }
    }

    private var progressAccessibilityValue: String {
        "\(Int((progressValue * 100).rounded()))パーセント"
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

struct PetankoMetalBackground: View {
    var body: some View {
        AppColors.appBackground
        .ignoresSafeArea()
    }
}

struct BrandWordmark: View {
    var body: some View {
        Text("petanko")
            .font(.system(size: 39, weight: .heavy, design: .rounded))
            .foregroundStyle(AppColors.accentPink)
            .tracking(0.4)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
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

    init(
        padding: CGFloat = AppSpacing.card,
        radius: CGFloat = AppRadius.card,
        @ViewBuilder content: () -> Content
    ) {
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
                    .fill(AppColors.surface.opacity(0.98))
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 0.8)
            }
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
    var radius: CGFloat = AppRadius.button

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(AppColors.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(AppColors.accentPink)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 0.8)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.86), value: configuration.isPressed)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    let backgroundColor: Color?
    let foregroundColor: Color
    let radius: CGFloat

    init(
        backgroundColor: Color? = nil,
        foregroundColor: Color = AppColors.mainText,
        radius: CGFloat = AppRadius.button
    ) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.radius = radius
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background {
                RoundedRectangle(
                    cornerRadius: radius,
                    style: .continuous
                )
                .fill(
                    (backgroundColor ?? AppColors.elevatedSurface)
                        .opacity(configuration.isPressed ? 0.88 : 0.98)
                )
            }
            .overlay {
                if backgroundColor == nil {
                    RoundedRectangle(
                        cornerRadius: radius,
                        style: .continuous
                    )
                    .stroke(AppColors.border, lineWidth: 0.8)
                }
            }
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
    let radius: CGFloat
    let content: Content

    init(
        title: String,
        radius: CGFloat = AppRadius.card,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.radius = radius
        self.content = content()
    }

    var body: some View {
        MetalCard(radius: radius) {
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
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .font(.system(size: 16))
            .foregroundStyle(AppColors.mainText)
            .padding(.horizontal, 16)
            .frame(minHeight: 54)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(AppColors.elevatedSurface.opacity(0.98))
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 0.8)
            }
    }
}

extension View {
    func metalTextField(radius: CGFloat = AppRadius.field) -> some View {
        modifier(MetalTextFieldModifier(radius: radius))
    }
}

struct HorizontalOptionPicker<Option: PetankoOption>: View {
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
                    Rectangle()
                        .fill(AppColors.accentPink.opacity(0.90))
                } else {
                    Rectangle().fill(AppColors.surface.opacity(0.92))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.chip, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.chip, style: .continuous)
                    .stroke(isSelected ? AppColors.accentPink.opacity(0.58) : AppColors.border, lineWidth: 0.8)
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
                    if avatar.hasPrefix("https://") || avatar.hasPrefix("http://") {
                        RemoteImageView(urlString: avatar) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColors.mainText.opacity(0.72))
                        }
                        .scaledToFill()
                    } else if avatar.isEmpty || avatar == "system:person.fill" {
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
    let size: CGFloat
    let xOffset: CGFloat
    let yOffset: CGFloat
    let message: String?
    let sectionTitle: String?

    init(
        systemImage: String,
        title: String,
        message: String? = nil,
        sectionTitle: String? = nil,
        size: CGFloat = 48,
        xOffset: CGFloat = 0,
        yOffset: CGFloat = 0
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.sectionTitle = sectionTitle
        self.size = size
        self.xOffset = xOffset
        self.yOffset = yOffset
    }

    var body: some View {
        hardShadowCard
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }

    private var hardShadowCard: some View {
        ZStack {
            Rectangle()
                .fill(Color.black)
                .offset(x: 9, y: 10)

            Rectangle()
                .fill(Color(red: 1, green: 0.99, blue: 0.97))
                .overlay {
                    Rectangle()
                        .stroke(Color.black, lineWidth: 2.4)
                }

            VStack(spacing: hasMessage ? 10 : 14) {
                if let sectionTitle, !sectionTitle.isEmpty {
                    Text(sectionTitle)
                        .font(.system(size: 21, weight: .black, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.92))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 2)
                }

                ZStack {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: 62, height: 58)
                        .offset(x: 7, y: 7)
                        .zIndex(0)

                    ZStack {
                        Rectangle()
                            .fill(AppColors.accentPink)
                            .overlay {
                                Rectangle()
                                    .stroke(Color.black, lineWidth: 2)
                            }

                        Image(systemName: systemImage)
                            .symbolRenderingMode(.monochrome)
                            .font(.system(size: min(size, 37), weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.90))
                            .offset(x: xOffset, y: yOffset)
                            .zIndex(2)
                    }
                    .frame(width: 62, height: 58)
                    .zIndex(1)
                }

                Text(title)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.90))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                if let message, !message.isEmpty {
                    Text(message)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.62))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .lineLimit(3)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
        }
        .frame(
            width: 300,
            height: hasSectionTitle
                ? (hasMessage ? 218 : 194)
                : (hasMessage ? 172 : 148)
        )
        .padding(.trailing, 9)
        .padding(.bottom, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var hasMessage: Bool {
        message?.isEmpty == false
    }

    private var hasSectionTitle: Bool {
        sectionTitle?.isEmpty == false
    }

    private var accessibilityText: String {
        [sectionTitle, title, message]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: "。")
    }
}
extension AppTab: CaseIterable, Identifiable {
    var id: Self { self }

    static var allCases: [AppTab] {
        [.home, .memories, .camera, .friends, .profile]
    }

    var title: String {
        switch self {
        case .home: "ホーム"
        case .camera: "カメラ"
        case .friends: "友達一覧"
        case .memories: "絵日記"
        case .profile: "プロフィール"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .camera: "plus"
        case .friends: "person.2"
        case .memories: "book.pages"
        case .profile: "person.crop.circle"
        }
    }
}
