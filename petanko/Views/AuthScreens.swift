//
//  AuthScreens.swift
//  petanko
//

import SwiftUI

struct AuthScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var hasReadTerms = false
    @State private var hasAcceptedTerms = false
    @State private var isShowingTerms = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                PetankoMetalBackground()

                GeometryReader { proxy in
                    let isCompact = proxy.size.height < 680

                    VStack(alignment: .leading, spacing: isCompact ? 22 : 32) {
                        VStack(alignment: .leading, spacing: 12) {
                            BrandWordmark()
                            Text("友達との1日を、ステッカーで残そう。")
                                .font(.system(size: 16))
                                .foregroundStyle(AppColors.secondaryText)
                                .lineSpacing(3)
                        }
                        .padding(.top, isCompact ? 44 : 70)

                        Spacer(minLength: isCompact ? 10 : 24)

                        authForm

                        Spacer(minLength: isCompact ? 84 : 98)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                }

                bottomAuthDescription
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.bottom, 34)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isShowingTerms) {
                TermsOfServiceSheet {
                    hasReadTerms = true
                    hasAcceptedTerms = true
                    isShowingTerms = false
                }
            }
        }
    }

    private var authForm: some View {
        VStack(spacing: 14) {
            VStack(spacing: 12) {
                TextField("メールアドレス", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .metalTextField()

                SecureField("パスワード", text: $password)
                    .textContentType(mode == .signIn ? .password : .newPassword)
                    .textFieldStyle(.plain)
                    .metalTextField()

                signUpOnlyFields
                    .animation(.spring(response: 0.28, dampingFraction: 0.88), value: mode)
            }

            VStack(spacing: 14) {
                Button {
                    Task { await submit() }
                } label: {
                    if appState.isAuthenticating {
                        ProgressView()
                            .tint(AppColors.mainText)
                    } else {
                        Label(mode.primaryActionTitle, systemImage: mode.systemImage)
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(!canSubmit || appState.isAuthenticating)
                .opacity(canSubmit ? 1 : 0.48)

                Button {
                    mode = mode == .signIn ? .signUp : .signIn
                    if mode == .signIn {
                        hasAcceptedTerms = false
                    }
                } label: {
                    Text(mode == .signIn ? "アカウントを作る" : "ログインに戻る")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.mainText)
                        .id(mode)
                }
                .buttonStyle(.plain)
                .animation(nil, value: mode)
            }
        }
    }

    @ViewBuilder
    private var signUpOnlyFields: some View {
        if mode == .signUp {
            SecureField("パスワード確認", text: $confirmPassword)
                .textContentType(.newPassword)
                .textFieldStyle(.plain)
                .metalTextField()
                .transition(.opacity.combined(with: .move(edge: .top)))

            termsAgreementView
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var bottomAuthDescription: some View {
        Text("メールアドレスでログインします。\nアカウント情報は安全に保存されます。")
            .font(.system(size: 12))
            .foregroundStyle(AppColors.secondaryText)
            .lineSpacing(3)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
    }

    private var termsAgreementView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                isShowingTerms = true
            } label: {
                Label("利用規約を読む", systemImage: "doc.text")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.mainText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                guard hasReadTerms else {
                    isShowingTerms = true
                    return
                }
                hasAcceptedTerms.toggle()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: hasAcceptedTerms ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(hasAcceptedTerms ? AppColors.accentPink : AppColors.secondaryText)
                    Text("利用規約に同意します")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.mainText)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(hasAcceptedTerms ? "利用規約に同意済み" : "利用規約に同意する")

            if !hasReadTerms {
                Text("アカウント作成前に利用規約を確認してください。")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
        .padding(13)
        .background(AppColors.elevatedSurface.opacity(0.96), in: RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.8)
        }
    }

    private var canSubmit: Bool {
        let hasBaseFields = email.trimmedForPetanko.contains("@") && password.count >= 6
        if mode == .signIn {
            return hasBaseFields
        }
        return hasBaseFields && password == confirmPassword && hasAcceptedTerms
    }

    private func submit() async {
        if mode == .signIn {
            await appState.signIn(email: email, password: password)
        } else {
            guard password == confirmPassword else {
                appState.errorMessage = "確認用パスワードが一致していません。"
                return
            }
            guard hasAcceptedTerms else {
                appState.errorMessage = "利用規約を確認して同意してください。"
                return
            }
            await appState.createAccount(email: email, password: password, termsAcceptedAt: Date())
        }
    }
}

private struct TermsOfServiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAccept: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("petanko 利用規約")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(AppColors.mainText)

                    Text(termsText)
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.mainText)
                        .lineSpacing(5)
                }
                .padding(22)
            }
            .background {
                PetankoMetalBackground()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("同意する") {
                        onAccept()
                    }
                    .font(.system(size: 15, weight: .semibold))
                }
            }
        }
    }

    private var termsText: String {
        """
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
    }
}

struct UsernameSetupScreen: View {
    @EnvironmentObject private var appState: AppState
    let email: String
    @State private var displayName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                PetankoMetalBackground()

                ScrollView {
                    VStack(spacing: 30) {
                        VStack(spacing: 10) {
                            BrandWordmark()
                            Text("プロフィールを仕上げよう")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(AppColors.mainText)
                            Text(email)
                                .font(.system(size: 13))
                                .foregroundStyle(AppColors.secondaryText)
                        }
                        .padding(.top, 62)

                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 70, weight: .regular))
                            .foregroundStyle(AppColors.mainText.opacity(0.72))
                            .frame(width: 118, height: 118)
                            .background {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppColors.elevatedSurface, AppColors.dustyPink.opacity(0.24), AppColors.paperCream],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            .overlay { Circle().stroke(AppColors.border, lineWidth: 0.8) }

                        MetalCard(padding: 16) {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("ユーザー名を入力", systemImage: "pencil")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AppColors.secondaryText)

                                TextField("ユーザー名", text: $displayName)
                                    .font(.system(size: 20, weight: .semibold))
                                    .textFieldStyle(.plain)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 14)
                                    .background(AppColors.elevatedSurface.opacity(0.92))
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(AppColors.border, lineWidth: 0.8)
                                    }
                            }
                        }

                        Button {
                            Task { await appState.completeProfile(displayName: displayName, avatar: "") }
                        } label: {
                            if appState.isAuthenticating {
                                ProgressView()
                                    .tint(AppColors.mainText)
                            } else {
                                Label("petankoを始める", systemImage: "sparkles")
                            }
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                        .disabled(displayName.trimmedForPetanko.isEmpty || appState.isAuthenticating)
                        .opacity(displayName.trimmedForPetanko.isEmpty ? 0.48 : 1)

                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.bottom, 34)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private enum AuthMode: String, CaseIterable, Identifiable {
    case signIn
    case signUp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .signIn: "ログイン"
        case .signUp: "新規作成"
        }
    }

    var primaryActionTitle: String {
        switch self {
        case .signIn: "ログイン"
        case .signUp: "アカウントを作成"
        }
    }

    var systemImage: String {
        switch self {
        case .signIn: "rectangle.portrait.and.arrow.right.fill"
        case .signUp: "person.badge.plus.fill"
        }
    }
}
