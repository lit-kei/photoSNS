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
    var color: Color = AppColors.surface.opacity(0.98)
    let content: Content

    init(
        padding: CGFloat = AppSpacing.card,
        radius: CGFloat = AppRadius.card,
        color: Color = AppColors.surface.opacity(0.98),
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.radius = radius
        self.color = color
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(color)
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
    let color: Color
    let content: Content

    init(
        title: String,
        radius: CGFloat = AppRadius.card,
        color: Color = AppColors.surface.opacity(0.98),
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.radius = radius
        self.color = color
        self.content = content()
    }

    var body: some View {
        MetalCard(radius: radius, color: color) {
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
enum EmptyStateStyle {
    case hardShadow
    case collage(EmptyStateCollageStyle)
}

enum EmptyStateCollageStyle {
    case incomingRequests
    case outgoingRequests
    case groups
    case friends
    case timeline
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let size: CGFloat
    let xOffset: CGFloat
    let yOffset: CGFloat
    let message: String?
    let sectionTitle: String?
    let style: EmptyStateStyle

    init(
        systemImage: String,
        title: String,
        message: String? = nil,
        sectionTitle: String? = nil,
        style: EmptyStateStyle = .hardShadow,
        size: CGFloat = 48,
        xOffset: CGFloat = 0,
        yOffset: CGFloat = 0
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.sectionTitle = sectionTitle
        self.style = style
        self.size = size
        self.xOffset = xOffset
        self.yOffset = yOffset
    }

    var body: some View {
        Group {
            switch style {
            case .hardShadow:
                hardShadowCard
            case .collage(let collageStyle):
                collageCard(collageStyle)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, collageVerticalPadding)
    }

    private var collageVerticalPadding: CGFloat {
        switch style {
        case .hardShadow, .collage(.groups), .collage(.friends), .collage(.timeline): 24
        case .collage(.incomingRequests), .collage(.outgoingRequests): 6
        }
    }

    @ViewBuilder
    private func collageCard(_ collageStyle: EmptyStateCollageStyle) -> some View {
        switch collageStyle {
        case .incomingRequests:
            incomingRequestCollage
        case .outgoingRequests:
            outgoingRequestCollage
        case .groups:
            groupCollage
        case .friends:
            friendCollage
        case .timeline:
            timelineCollage
        }
    }

    private var incomingRequestCollage: some View {
        PixelEmptyStateLogo(
            kicker: sectionTitle ?? "届いた申請",
            title: "０件です",
            variant: .incoming
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var outgoingRequestCollage: some View {
        PixelEmptyStateLogo(
            kicker: sectionTitle ?? "送信中",
            title: "０件です",
            variant: .outgoing
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var groupCollage: some View {
        PixelEmptyStateLogo(
            kicker: nil,
            title: "グループは\nまだない",
            variant: .groups
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var friendCollage: some View {
        PixelEmptyStateLogo(
            kicker: nil,
            title: "今はまだ\nひとり",
            variant: .friends
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var timelineCollage: some View {
        PixelEmptyStateLogo(
            kicker: sectionTitle ?? "今日のタイムライン",
            title: title,
            variant: .timeline
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
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

private enum PixelPlaqueVariant {
    case incoming
    case outgoing
    case groups
    case friends
    case timeline
}

private struct PixelEmptyStateLogo: View {
    let kicker: String?
    let title: String
    let variant: PixelPlaqueVariant

    private let accent = AppColors.accentPink
    private let deepAccent = Color(red: 0.56, green: 0.28, blue: 0.02)

    var body: some View {
        ZStack {
            PixelPlaqueShape(variant: variant)
                .fill(deepAccent)
                .frame(width: 252, height: 116)
                .offset(x: 5, y: 11)

            PixelPlaqueShape(variant: variant)
                .fill(accent)
                .frame(width: 252, height: 116)
                .offset(y: 5)

            PixelPlaqueShape(variant: variant)
                .fill(Color.white)
                .overlay {
                    PixelPlaqueShape(variant: variant)
                        .stroke(accent, style: StrokeStyle(lineWidth: 5, lineJoin: .miter))
                }
                .frame(width: 252, height: 116)

            VStack(spacing: 1) {
                if let kicker = kicker {
                    Text(kicker)
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(accent)
                        .tracking(1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(width: 190)
                }

                PixelStatusText(
                    text: title,
                    color: accent,
                    shadowColor: deepAccent
                )
            }
            .offset(y: 2)

        }
        .frame(width: 312, height: 174)
    }
}

private struct PixelStatusText: View {
    let text: String
    let color: Color
    let shadowColor: Color

    var body: some View {
        ZStack {
            label
                .foregroundStyle(shadowColor)
                .offset(x: 1.25, y: 1.75)

            label
                .foregroundStyle(color)
        }
    }

    private var label: some View {
        Text(text)
            .font(.system(size: 25, weight: .black, design: .monospaced))
            .tracking(-0.8)
            .multilineTextAlignment(.center)
            .lineSpacing(-5)
            .lineLimit(2)
            .minimumScaleFactor(0.78)
            .frame(width: 222, height: 69)
    }
}

private struct PixelPlaqueShape: Shape {
    let variant: PixelPlaqueVariant

    func path(in rect: CGRect) -> Path {
        let points = points(for: variant)

        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: rect.minX + first.x * rect.width, y: rect.minY + first.y * rect.height))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height))
        }
        path.closeSubpath()
        return path
    }

    private func points(for variant: PixelPlaqueVariant) -> [CGPoint] {
        switch variant {
        case .incoming:
            return [
                CGPoint(x: 0.08, y: 0.05), CGPoint(x: 0.24, y: 0.05), CGPoint(x: 0.24, y: 0),
                CGPoint(x: 0.42, y: 0), CGPoint(x: 0.42, y: 0.07), CGPoint(x: 0.70, y: 0.07),
                CGPoint(x: 0.70, y: 0.02), CGPoint(x: 0.86, y: 0.02), CGPoint(x: 0.86, y: 0.11),
                CGPoint(x: 0.95, y: 0.11), CGPoint(x: 0.95, y: 0.27), CGPoint(x: 1, y: 0.27),
                CGPoint(x: 1, y: 0.72), CGPoint(x: 0.94, y: 0.72), CGPoint(x: 0.94, y: 0.90),
                CGPoint(x: 0.77, y: 0.90), CGPoint(x: 0.77, y: 0.98), CGPoint(x: 0.54, y: 0.98),
                CGPoint(x: 0.54, y: 0.92), CGPoint(x: 0.31, y: 0.92), CGPoint(x: 0.31, y: 1),
                CGPoint(x: 0.14, y: 1), CGPoint(x: 0.14, y: 0.91), CGPoint(x: 0.04, y: 0.91),
                CGPoint(x: 0.04, y: 0.73), CGPoint(x: 0, y: 0.73), CGPoint(x: 0, y: 0.29),
                CGPoint(x: 0.05, y: 0.29), CGPoint(x: 0.05, y: 0.13), CGPoint(x: 0.08, y: 0.13)
            ]
        case .outgoing:
            return [
                CGPoint(x: 0.04, y: 0.12), CGPoint(x: 0.29, y: 0.12), CGPoint(x: 0.29, y: 0.04),
                CGPoint(x: 0.52, y: 0.04), CGPoint(x: 0.52, y: 0), CGPoint(x: 0.73, y: 0),
                CGPoint(x: 0.73, y: 0.10), CGPoint(x: 0.90, y: 0.10), CGPoint(x: 0.90, y: 0.25),
                CGPoint(x: 0.96, y: 0.25), CGPoint(x: 0.96, y: 0.39), CGPoint(x: 1, y: 0.39),
                CGPoint(x: 1, y: 0.62), CGPoint(x: 0.94, y: 0.62), CGPoint(x: 0.94, y: 0.82),
                CGPoint(x: 0.82, y: 0.82), CGPoint(x: 0.82, y: 0.94), CGPoint(x: 0.57, y: 0.94),
                CGPoint(x: 0.57, y: 1), CGPoint(x: 0.34, y: 1), CGPoint(x: 0.34, y: 0.92),
                CGPoint(x: 0.12, y: 0.92), CGPoint(x: 0.12, y: 0.82), CGPoint(x: 0.03, y: 0.82),
                CGPoint(x: 0.03, y: 0.65), CGPoint(x: 0, y: 0.65), CGPoint(x: 0, y: 0.28),
                CGPoint(x: 0.04, y: 0.28)
            ]
        case .groups:
            return [
                CGPoint(x: 0.09, y: 0.09), CGPoint(x: 0.18, y: 0.09), CGPoint(x: 0.18, y: 0.02),
                CGPoint(x: 0.36, y: 0.02), CGPoint(x: 0.36, y: 0.10), CGPoint(x: 0.62, y: 0.10),
                CGPoint(x: 0.62, y: 0), CGPoint(x: 0.80, y: 0), CGPoint(x: 0.80, y: 0.06),
                CGPoint(x: 0.93, y: 0.06), CGPoint(x: 0.93, y: 0.20), CGPoint(x: 1, y: 0.20),
                CGPoint(x: 1, y: 0.69), CGPoint(x: 0.96, y: 0.69), CGPoint(x: 0.96, y: 0.88),
                CGPoint(x: 0.84, y: 0.88), CGPoint(x: 0.84, y: 0.96), CGPoint(x: 0.63, y: 0.96),
                CGPoint(x: 0.63, y: 0.90), CGPoint(x: 0.40, y: 0.90), CGPoint(x: 0.40, y: 1),
                CGPoint(x: 0.22, y: 1), CGPoint(x: 0.22, y: 0.94), CGPoint(x: 0.07, y: 0.94),
                CGPoint(x: 0.07, y: 0.82), CGPoint(x: 0, y: 0.82), CGPoint(x: 0, y: 0.34),
                CGPoint(x: 0.04, y: 0.34), CGPoint(x: 0.04, y: 0.16), CGPoint(x: 0.09, y: 0.16)
            ]
        case .friends:
            return [
                CGPoint(x: 0.05, y: 0.17), CGPoint(x: 0.13, y: 0.17), CGPoint(x: 0.13, y: 0.06),
                CGPoint(x: 0.31, y: 0.06), CGPoint(x: 0.31, y: 0), CGPoint(x: 0.54, y: 0),
                CGPoint(x: 0.54, y: 0.07), CGPoint(x: 0.76, y: 0.07), CGPoint(x: 0.76, y: 0.02),
                CGPoint(x: 0.91, y: 0.02), CGPoint(x: 0.91, y: 0.15), CGPoint(x: 0.97, y: 0.15),
                CGPoint(x: 0.97, y: 0.32), CGPoint(x: 1, y: 0.32), CGPoint(x: 1, y: 0.76),
                CGPoint(x: 0.92, y: 0.76), CGPoint(x: 0.92, y: 0.93), CGPoint(x: 0.73, y: 0.93),
                CGPoint(x: 0.73, y: 1), CGPoint(x: 0.48, y: 1), CGPoint(x: 0.48, y: 0.94),
                CGPoint(x: 0.26, y: 0.94), CGPoint(x: 0.26, y: 0.88), CGPoint(x: 0.09, y: 0.88),
                CGPoint(x: 0.09, y: 0.78), CGPoint(x: 0.02, y: 0.78), CGPoint(x: 0.02, y: 0.58),
                CGPoint(x: 0, y: 0.58), CGPoint(x: 0, y: 0.29), CGPoint(x: 0.05, y: 0.29)
            ]
        case .timeline:
            return [
                CGPoint(x: 0.06, y: 0.10), CGPoint(x: 0.27, y: 0.10), CGPoint(x: 0.27, y: 0.02),
                CGPoint(x: 0.45, y: 0.02), CGPoint(x: 0.45, y: 0), CGPoint(x: 0.59, y: 0),
                CGPoint(x: 0.59, y: 0.08), CGPoint(x: 0.84, y: 0.08), CGPoint(x: 0.84, y: 0.14),
                CGPoint(x: 0.95, y: 0.14), CGPoint(x: 0.95, y: 0.30), CGPoint(x: 1, y: 0.30),
                CGPoint(x: 1, y: 0.74), CGPoint(x: 0.95, y: 0.74), CGPoint(x: 0.95, y: 0.87),
                CGPoint(x: 0.81, y: 0.87), CGPoint(x: 0.81, y: 0.95), CGPoint(x: 0.59, y: 0.95),
                CGPoint(x: 0.59, y: 1), CGPoint(x: 0.43, y: 1), CGPoint(x: 0.43, y: 0.93),
                CGPoint(x: 0.21, y: 0.93), CGPoint(x: 0.21, y: 0.98), CGPoint(x: 0.08, y: 0.98),
                CGPoint(x: 0.08, y: 0.84), CGPoint(x: 0.02, y: 0.84), CGPoint(x: 0.02, y: 0.68),
                CGPoint(x: 0, y: 0.68), CGPoint(x: 0, y: 0.27), CGPoint(x: 0.06, y: 0.27)
            ]
        }
    }
}

private struct StickerOutlinedText: View {
    let text: String
    let fontSize: CGFloat
    let width: CGFloat

    private let outlineOffsets: [CGSize] = [
        CGSize(width: -3.5, height: -3.5),
        CGSize(width: 0, height: -4),
        CGSize(width: 3.5, height: -3.5),
        CGSize(width: -4, height: 0),
        CGSize(width: 4, height: 0),
        CGSize(width: -3.5, height: 3.5),
        CGSize(width: 0, height: 4),
        CGSize(width: 3.5, height: 3.5)
    ]

    var body: some View {
        ZStack {
            ForEach(outlineOffsets.indices, id: \.self) { index in
                label
                    .foregroundStyle(Color.black)
                    .offset(outlineOffsets[index])
            }

            label
                .foregroundStyle(Color.white)
        }
    }

    private var label: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .black, design: .rounded))
            .tracking(0.4)
            .multilineTextAlignment(.center)
            .lineSpacing(-5)
            .lineLimit(2)
            .minimumScaleFactor(0.82)
            .frame(width: width)
    }
}

private struct StickerCloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.61))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.20, y: rect.minY + rect.height * 0.30),
            control1: CGPoint(x: rect.minX - rect.width * 0.02, y: rect.minY + rect.height * 0.48),
            control2: CGPoint(x: rect.minX + rect.width * 0.06, y: rect.minY + rect.height * 0.28)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY + rect.height * 0.18),
            control1: CGPoint(x: rect.minX + rect.width * 0.26, y: rect.minY + rect.height * 0.06),
            control2: CGPoint(x: rect.minX + rect.width * 0.35, y: rect.minY + rect.height * 0.09)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.63, y: rect.minY + rect.height * 0.23),
            control1: CGPoint(x: rect.minX + rect.width * 0.50, y: rect.minY - rect.height * 0.02),
            control2: CGPoint(x: rect.minX + rect.width * 0.59, y: rect.minY + rect.height * 0.05)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.89, y: rect.minY + rect.height * 0.36),
            control1: CGPoint(x: rect.minX + rect.width * 0.75, y: rect.minY + rect.height * 0.08),
            control2: CGPoint(x: rect.minX + rect.width * 0.91, y: rect.minY + rect.height * 0.17)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.91, y: rect.minY + rect.height * 0.70),
            control1: CGPoint(x: rect.maxX + rect.width * 0.02, y: rect.minY + rect.height * 0.48),
            control2: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.66)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.67, y: rect.minY + rect.height * 0.83),
            control1: CGPoint(x: rect.minX + rect.width * 0.86, y: rect.minY + rect.height * 0.91),
            control2: CGPoint(x: rect.minX + rect.width * 0.74, y: rect.minY + rect.height * 0.91)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.minY + rect.height * 0.86),
            control1: CGPoint(x: rect.minX + rect.width * 0.56, y: rect.maxY),
            control2: CGPoint(x: rect.minX + rect.width * 0.47, y: rect.minY + rect.height * 0.79)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.61),
            control1: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.maxY),
            control2: CGPoint(x: rect.minX + rect.width * 0.04, y: rect.minY + rect.height * 0.87)
        )
        path.closeSubpath()
        return path
    }
}

private struct StickerArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        let points: [CGPoint] = [
            CGPoint(x: 0.04, y: 0.31), CGPoint(x: 0.22, y: 0.25),
            CGPoint(x: 0.27, y: 0.08), CGPoint(x: 0.43, y: 0.20),
            CGPoint(x: 0.58, y: 0.06), CGPoint(x: 0.68, y: 0.23),
            CGPoint(x: 0.87, y: 0.18), CGPoint(x: 0.82, y: 0.37),
            CGPoint(x: 0.98, y: 0.50), CGPoint(x: 0.80, y: 0.64),
            CGPoint(x: 0.85, y: 0.84), CGPoint(x: 0.65, y: 0.76),
            CGPoint(x: 0.55, y: 0.95), CGPoint(x: 0.41, y: 0.78),
            CGPoint(x: 0.23, y: 0.88), CGPoint(x: 0.20, y: 0.69),
            CGPoint(x: 0.04, y: 0.62), CGPoint(x: 0.12, y: 0.47)
        ]

        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: rect.minX + first.x * rect.width, y: rect.minY + first.y * rect.height))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height))
        }
        path.closeSubpath()
        return path
    }
}

private struct StickerOrganicShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.28))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.34, y: rect.minY + rect.height * 0.08),
            control1: CGPoint(x: rect.minX - rect.width * 0.01, y: rect.minY + rect.height * 0.12),
            control2: CGPoint(x: rect.minX + rect.width * 0.17, y: rect.minY - rect.height * 0.02)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.66, y: rect.minY + rect.height * 0.14),
            control1: CGPoint(x: rect.minX + rect.width * 0.44, y: rect.minY + rect.height * 0.18),
            control2: CGPoint(x: rect.minX + rect.width * 0.56, y: rect.minY - rect.height * 0.02)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.91, y: rect.minY + rect.height * 0.31),
            control1: CGPoint(x: rect.minX + rect.width * 0.79, y: rect.minY + rect.height * 0.05),
            control2: CGPoint(x: rect.maxX + rect.width * 0.03, y: rect.minY + rect.height * 0.16)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.88, y: rect.minY + rect.height * 0.75),
            control1: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.46),
            control2: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.69)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.57, y: rect.minY + rect.height * 0.88),
            control1: CGPoint(x: rect.minX + rect.width * 0.78, y: rect.maxY + rect.height * 0.02),
            control2: CGPoint(x: rect.minX + rect.width * 0.68, y: rect.minY + rect.height * 0.78)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.minY + rect.height * 0.92),
            control1: CGPoint(x: rect.minX + rect.width * 0.48, y: rect.maxY),
            control2: CGPoint(x: rect.minX + rect.width * 0.39, y: rect.minY + rect.height * 0.84)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.68),
            control1: CGPoint(x: rect.minX + rect.width * 0.13, y: rect.maxY + rect.height * 0.05),
            control2: CGPoint(x: rect.minX - rect.width * 0.01, y: rect.minY + rect.height * 0.84)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.28),
            control1: CGPoint(x: rect.minX - rect.width * 0.03, y: rect.minY + rect.height * 0.54),
            control2: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.45)
        )
        path.closeSubpath()
        return path
    }
}

private struct StickerBurstShape: Shape {
    func path(in rect: CGRect) -> Path {
        let points: [CGPoint] = [
            CGPoint(x: 0.08, y: 0.34), CGPoint(x: 0.20, y: 0.27),
            CGPoint(x: 0.23, y: 0.09), CGPoint(x: 0.39, y: 0.20),
            CGPoint(x: 0.51, y: 0.04), CGPoint(x: 0.61, y: 0.22),
            CGPoint(x: 0.79, y: 0.14), CGPoint(x: 0.82, y: 0.31),
            CGPoint(x: 0.97, y: 0.40), CGPoint(x: 0.88, y: 0.55),
            CGPoint(x: 0.94, y: 0.76), CGPoint(x: 0.75, y: 0.73),
            CGPoint(x: 0.67, y: 0.95), CGPoint(x: 0.50, y: 0.80),
            CGPoint(x: 0.34, y: 0.93), CGPoint(x: 0.27, y: 0.76),
            CGPoint(x: 0.08, y: 0.74), CGPoint(x: 0.13, y: 0.56),
            CGPoint(x: 0.02, y: 0.46)
        ]

        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: rect.minX + first.x * rect.width, y: rect.minY + first.y * rect.height))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height))
        }
        path.closeSubpath()
        return path
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
