//
//  AuthScreens.swift
//  petalog
//

import SwiftUI

struct AuthScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    var body: some View {
        NavigationStack {
            ZStack {
                PetalogMetalBackground()

                GeometryReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 34) {
                            VStack(alignment: .leading, spacing: 12) {
                                BrandWordmark()
                                Text("友達との1日を、ステッカーで残そう。")
                                    .font(.system(size: 16))
                                    .foregroundStyle(AppColors.secondaryText)
                                    .lineSpacing(3)
                            }
                            .padding(.top, 70)

                            Spacer(minLength: 28)

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

                                if mode == .signUp {
                                    SecureField("パスワード確認", text: $confirmPassword)
                                        .textContentType(.newPassword)
                                        .textFieldStyle(.plain)
                                        .metalTextField()
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                }
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
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                                        mode = mode == .signIn ? .signUp : .signIn
                                    }
                                } label: {
                                    Text(mode == .signIn ? "アカウントを作る" : "ログインに戻る")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(AppColors.mainText)
                                }
                                .buttonStyle(.plain)
                            }

                            Spacer(minLength: 34)

                            Text("メールアドレスでログインします。アカウント情報は安全に保存されます。")
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.secondaryText)
                                .lineSpacing(3)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.bottom, 34)
                        .frame(minHeight: proxy.size.height, alignment: .top)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var canSubmit: Bool {
        let hasBaseFields = email.trimmedForPetalog.contains("@") && password.count >= 6
        if mode == .signIn {
            return hasBaseFields
        }
        return hasBaseFields && password == confirmPassword
    }

    private func submit() async {
        if mode == .signIn {
            await appState.signIn(email: email, password: password)
        } else {
            guard password == confirmPassword else {
                appState.errorMessage = "確認用パスワードが一致していません。"
                return
            }
            await appState.createAccount(email: email, password: password)
        }
    }
}

struct UsernameSetupScreen: View {
    @EnvironmentObject private var appState: AppState
    let email: String
    @State private var displayName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                PetalogMetalBackground()

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
                                Label("petalogを始める", systemImage: "sparkles")
                            }
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                        .disabled(displayName.trimmedForPetalog.isEmpty || appState.isAuthenticating)
                        .opacity(displayName.trimmedForPetalog.isEmpty ? 0.48 : 1)

                        Button("別のアカウントでログイン") {
                            appState.signOut()
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.secondaryText)
                        .buttonStyle(.plain)
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
