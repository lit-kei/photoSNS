import SwiftUI
import UIKit
import UserNotifications

struct SettingsScreen: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL
    @State private var isNotificationToggleOn = false
    @State private var notificationUpdateTask: Task<Void, Never>?
    @State private var isShowingNotificationSettingsAlert = false
    @State private var isShowingSignOutConfirmation = false
    @State private var isDeletingAccount = false
    @State private var isShowingReauthentication = false
    @State private var isReauthenticatingForAccountDeletion = false
    @State private var accountDeletionPassword = ""
    @State private var accountDeletionMessage: String?
    @State private var isAccountDeletionFlowActive = false
    @State private var isChoosingAccountDeletionPostPolicy = false
    @State private var isPreparingAccountDeletionChoice = false
    @State private var hasRecentLoginForAccountDeletion = false
    @State private var verifiedAccountDeletionPassword: String?
    @State private var accountDeletionStep: AccountDeletionStep?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                settingsSection(title: "アカウント") {
                    SettingsNavigationRow(title: "プロフィールを編集", systemImage: "person.crop.circle") {
                        ProfileEditScreen()
                    }
                    SettingsDivider()
                    SettingsNavigationRow(title: "ブロックしたユーザー", systemImage: "hand.raised") {
                        BlockedUsersScreen()
                    }
                }

                settingsSection(title: "通知") {
                    SettingsToggleRow(
                        title: "通知",
                        systemImage: "bell",
                        isOn: Binding(
                            get: { isNotificationToggleOn },
                            set: { isOn in
                                isNotificationToggleOn = isOn
                                notificationUpdateTask?.cancel()
                                notificationUpdateTask = Task {
                                    await updateNotificationPreference(isEnabled: isOn)
                                }
                            }
                        )
                    )
                }

                settingsSection(title: "サポート") {
                    SettingsNavigationRow(title: "利用規約", systemImage: "doc.text") {
                        TermsOfServiceScreen()
                    }
                    SettingsDivider()
                    SettingsNavigationRow(title: "プライバシーポリシー", systemImage: "lock") {
                        PrivacyPolicyScreen()
                    }
                }

                settingsSection(title: "アプリ") {
                    SettingsNavigationRow(title: "petankoについて", systemImage: "info.circle") {
                        AboutPetankoScreen()
                    } detail: {
                        Text("バージョン \(appVersion)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }

                VStack(spacing: 14) {
                    Button {
                        isShowingSignOutConfirmation = true
                    } label: {
                        Label("ログアウト", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryActionButtonStyle(foregroundColor: AppColors.destructiveRed))

                    Button("アカウントを削除") {
                        beginAccountDeletion()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.destructiveRed)
                    .buttonStyle(.plain)
                    .disabled(isDeletingAccount)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.screenTop)
            .padding(.bottom, 26)
        }
        .background {
            PetankoMetalBackground()
        }
        .disabled(isAccountDeletionFlowActive)
        .overlay {
            if isDeletingAccount {
                AccountDeletionProgressOverlay(step: accountDeletionStep)
            } else if isChoosingAccountDeletionPostPolicy {
                AccountDeletionChoiceOverlay(
                    deletePostsAction: {
                        Task { await deleteAccount(policy: .deletePosts) }
                    },
                    anonymizePostsAction: {
                        Task { await deleteAccount(policy: .anonymizePosts) }
                    },
                    cancelAction: cancelAccountDeletionFlow
                )
            } else if isAccountDeletionFlowActive && isPreparingAccountDeletionChoice {
                AccountDeletionProgressOverlay(step: nil)
            }
        }
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isAccountDeletionFlowActive)
        .task {
            await refreshNotificationToggle()
        }
        .confirmationDialog("ログアウトしますか？", isPresented: $isShowingSignOutConfirmation, titleVisibility: .visible) {
            Button("ログアウト", role: .destructive) {
                appState.signOut()
            }
            Button("キャンセル", role: .cancel) {}
        }
        .alert("通知がオフになっています", isPresented: $isShowingNotificationSettingsAlert) {
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("iPhoneの設定から通知を許可してください。")
        }
        .alert("ログイン確認", isPresented: $isShowingReauthentication) {
            SecureField("パスワード", text: $accountDeletionPassword)
            Button("続ける", role: .destructive) {
                Task { await confirmAccountDeletionPassword() }
            }
            .disabled(isReauthenticatingForAccountDeletion)
            Button("キャンセル", role: .cancel) {
                cancelAccountDeletionFlow()
            }
        } message: {
            Text("安全のため、パスワードを入力してください。次の画面で投稿の扱いを選べます。")
        }
        .alert("アカウント削除", isPresented: Binding(
            get: { accountDeletionMessage != nil },
            set: { if !$0 { accountDeletionMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(accountDeletionMessage ?? "")
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppColors.secondaryText)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(AppColors.surface.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 0.8)
            }
        }
    }

    private func refreshNotificationToggle() async {
        let status = await PushNotificationService.shared.authorizationStatus()
        let isAllowed = status == .authorized || status == .provisional || status == .ephemeral
        isNotificationToggleOn = PushNotificationService.isUserPreferenceEnabled && isAllowed
    }

    private func updateNotificationPreference(isEnabled: Bool) async {
        if !isEnabled {
            PushNotificationService.setUserPreferenceEnabled(false)
            await PushNotificationService.shared.deactivate()
            return
        }

        guard !Task.isCancelled else { return }

        let status = await PushNotificationService.shared.authorizationStatus()
        guard !Task.isCancelled else { return }
        guard status != .denied else {
            PushNotificationService.setUserPreferenceEnabled(false)
            isNotificationToggleOn = false
            isShowingNotificationSettingsAlert = true
            return
        }

        guard let userId = appState.currentUser?.id else {
            PushNotificationService.setUserPreferenceEnabled(false)
            isNotificationToggleOn = false
            return
        }

        PushNotificationService.setUserPreferenceEnabled(true)
        PushNotificationService.shared.activate(for: userId)
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }
        await refreshNotificationToggle()
        if !isNotificationToggleOn {
            PushNotificationService.setUserPreferenceEnabled(false)
            isShowingNotificationSettingsAlert = true
        }
    }

    private func beginAccountDeletion() {
        clearPendingAccountDeletionCredentials()
        isAccountDeletionFlowActive = true
        isPreparingAccountDeletionChoice = false
        isChoosingAccountDeletionPostPolicy = false
        hasRecentLoginForAccountDeletion = false
        if appState.needsPasswordForAccountDeletion() {
            isShowingReauthentication = true
        } else {
            isChoosingAccountDeletionPostPolicy = true
        }
    }

    private func confirmAccountDeletionPassword() async {
        guard !isReauthenticatingForAccountDeletion else { return }
        isReauthenticatingForAccountDeletion = true
        let password = accountDeletionPassword
        let result = await appState.reauthenticateForAccountDeletion(password: password)
        accountDeletionPassword = ""
        isReauthenticatingForAccountDeletion = false
        switch result {
        case .authenticated:
            hasRecentLoginForAccountDeletion = true
            verifiedAccountDeletionPassword = password
            isPreparingAccountDeletionChoice = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(220))
                isPreparingAccountDeletionChoice = false
                isChoosingAccountDeletionPostPolicy = true
            }
        case .failed(let message):
            hasRecentLoginForAccountDeletion = false
            isPreparingAccountDeletionChoice = false
            isAccountDeletionFlowActive = false
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(220))
                accountDeletionMessage = message
            }
        }
    }

    private func deleteAccount(policy: AccountDeletionPostRetentionPolicy) async {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        accountDeletionStep = .reauthenticating
        isChoosingAccountDeletionPostPolicy = false
        let password = verifiedAccountDeletionPassword
        clearPendingAccountDeletionCredentials()
        let result = await appState.deleteAccount(
            password: password,
            postRetentionPolicy: policy,
            hasRecentLogin: hasRecentLoginForAccountDeletion
        ) { step in
            accountDeletionStep = step
        }
        isDeletingAccount = false
        switch result {
        case .deleted:
            accountDeletionStep = nil
            isAccountDeletionFlowActive = false
        case .requiresRecentLogin:
            accountDeletionStep = nil
            hasRecentLoginForAccountDeletion = false
            isAccountDeletionFlowActive = true
            isShowingReauthentication = true
        case .failed(let message):
            accountDeletionStep = nil
            isAccountDeletionFlowActive = false
            accountDeletionMessage = message
        }
    }

    private func cancelAccountDeletionFlow() {
        isAccountDeletionFlowActive = false
        isPreparingAccountDeletionChoice = false
        isChoosingAccountDeletionPostPolicy = false
        isDeletingAccount = false
        accountDeletionStep = nil
        hasRecentLoginForAccountDeletion = false
        clearPendingAccountDeletionCredentials()
    }

    private func clearPendingAccountDeletionCredentials() {
        accountDeletionPassword = ""
        verifiedAccountDeletionPassword = nil
    }
}

private struct SettingsNavigationRow<Destination: View, Detail: View>: View {
    let title: String
    let systemImage: String
    let destination: Destination
    let detail: Detail

    init(
        title: String,
        systemImage: String,
        @ViewBuilder destination: () -> Destination,
        @ViewBuilder detail: () -> Detail = { EmptyView() }
    ) {
        self.title = title
        self.systemImage = systemImage
        self.destination = destination()
        self.detail = detail()
    }

    var body: some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: 13) {
                SettingsRowIcon(systemImage: systemImage)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.mainText)
                Spacer(minLength: 12)
                detail
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.secondaryText)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .padding(.vertical, 15)
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 13) {
            SettingsRowIcon(systemImage: systemImage)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.mainText)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(AppColors.accentPink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct SettingsRowIcon: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppColors.mainText)
            .frame(width: 24, height: 24)
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppColors.border.opacity(0.72))
            .frame(height: 0.8)
            .padding(.leading, 51)
    }
}

private struct AccountDeletionProgressOverlay: View {
    let step: AccountDeletionStep?

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()
                .contentShape(Rectangle())

            MetalCard(padding: 22) {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(AppColors.mainText)
                        .scaleEffect(1.12)

                    VStack(spacing: 6) {
                        Text(step?.title ?? "アカウントを削除中")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(AppColors.mainText)

                        Text(step?.message ?? "しばらくお待ちください。")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.secondaryText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: 280)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }
}

private struct AccountDeletionChoiceOverlay: View {
    let deletePostsAction: () -> Void
    let anonymizePostsAction: () -> Void
    let cancelAction: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()
                .contentShape(Rectangle())

            MetalCard(padding: 22) {
                VStack(spacing: 16) {
                    VStack(spacing: 7) {
                        Text("アカウントを削除しますか？")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppColors.mainText)
                            .multilineTextAlignment(.center)

                        Text("この操作は取り消せません。匿名化を選ぶと、投稿画像は残り、名前・ユーザーID・プロフィール画像との紐づきとコメントが削除されます。")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.secondaryText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 10) {
                        Button(role: .destructive, action: deletePostsAction) {
                            Label("投稿も削除", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryActionButtonStyle(foregroundColor: AppColors.destructiveRed))

                        Button(role: .destructive, action: anonymizePostsAction) {
                            Label("匿名化して投稿を残す", systemImage: "person.crop.circle.badge.xmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryActionButtonStyle(foregroundColor: AppColors.destructiveRed))

                        Button(action: cancelAction) {
                            Label("キャンセル", systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                }
                .frame(maxWidth: 320)
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
        }
    }
}

struct TermsOfServiceScreen: View {
    var body: some View {
        LegalTextScreen(title: "利用規約", text: PetankoLegalText.termsOfService)
    }
}

struct PrivacyPolicyScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("petankoのプライバシーポリシーは、以下のページで確認できます。")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.mainText)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                Link(destination: PetankoLegalText.privacyPolicyURL) {
                    HStack(spacing: 10) {
                        Image(systemName: "safari")
                            .font(.system(size: 15, weight: .semibold))
                        Text("プライバシーポリシーを開く")
                            .font(.system(size: 15, weight: .bold))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(AppColors.mainText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                    .background(AppColors.surface.opacity(0.82))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                            .stroke(AppColors.border, lineWidth: 0.8)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.screenTop)
            .padding(.bottom, 24)
        }
        .background {
            PetankoMetalBackground()
        }
        .navigationTitle("プライバシーポリシー")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LegalTextScreen: View {
    let title: String
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.mainText)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.screenTop)
                .padding(.bottom, 24)
        }
        .background {
            PetankoMetalBackground()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutPetankoScreen: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                appIcon
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(AppColors.border, lineWidth: 0.8)
                    }

                VStack(spacing: 8) {
                    Text("petanko")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.mainText)

                    Spacer()

                    Text("バージョン \(appVersion)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.secondaryText)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.screenTop + 18)
        }
        .background {
            PetankoMetalBackground()
        }
        .navigationTitle("petankoについて")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    @ViewBuilder
    private var appIcon: some View {
        if let image = UIImage(named: "BootSplashIcon") {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppColors.accentPink)
        }
    }
}

private enum PetankoLegalText {
    static let termsOfService = """
    この利用規約は、petankoを安全に楽しく利用するためのルールです。アカウントを作成することで、本規約に同意したものとします。

    1. 投稿内容について
    ユーザーは、自分が投稿する写真、ステッカー、コメント、プロフィール情報について責任を持つものとします。他人の権利を侵害する画像や文章、許可なく撮影・共有された内容を投稿してはいけません。

    2. 禁止されるコンテンツ
    以下の内容を投稿または共有することを禁止します。
    ・他人を傷つける、脅す、嫌がらせをする内容
    ・差別的、攻撃的、侮辱的な内容
    ・性的、暴力的、過度に不快な画像や文章
    ・個人情報、連絡先、住所、識別情報などを本人の許可なく含む内容
    ・著作権、肖像権、商標権など第三者の権利を侵害する内容
    ・違法行為、危険行為、自傷行為を助長する内容
    ・スパム、不正アクセス、サービス運営を妨げる行為

    3. 投稿前の確認
    ユーザーは、投稿する前に、投稿内容が上記の禁止コンテンツに該当しないことを確認してください。petankoは、親しい友達やグループで日常の思い出を共有するためのサービスであり、他人を攻撃したり不快にさせたりする目的で利用してはいけません。

    4. 通報とブロック
    不適切な投稿を見つけた場合、ユーザーはアプリ内の報告機能から投稿を通報できます。また、ユーザーをブロックすることで、そのユーザーの投稿表示やフレンド申請を制限できます。ブロックはプロフィール画面またはブロックしたユーザー一覧から解除できます。

    5. 運営による対応
    運営上必要と判断した場合、違反する投稿の確認、削除、表示制限、アカウントの利用制限、その他安全確保のための対応を行うことがあります。通報された内容は、確認と対応のために保存される場合があります。

    6. アカウント削除
    ユーザーはプロフィール画面からアカウントを削除できます。削除時には、投稿も削除するか、個人情報との紐づきを匿名化して投稿を残すかを選択できます。匿名化した場合、表示名、ユーザーID、プロフィール画像との紐づき、コメントは削除されます。

    7. 問い合わせ先
    不適切な投稿、ユーザー対応、アカウント、プライバシー、その他サポートが必要な場合は、以下までお問い合わせください。
    petanko.support@gmail.com

    8. 規約の変更
    本規約は、アプリの機能変更、法令、App Store Review Guidelines、運用方針に応じて更新される場合があります。

    上記を確認し、同意したうえでアカウントを作成してください。
    """

    static let privacyPolicyURL = URL(string: "https://lit-kei.github.io/petanko/privacy.html")!
}
