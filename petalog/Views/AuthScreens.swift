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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("petalog")
                            .font(.largeTitle.bold())
                            .foregroundStyle(PetalogTheme.text)
                        Text("友達との1日を、ステッカーで残そう。")
                            .font(.headline)
                            .foregroundStyle(PetalogTheme.secondaryText)
                    }
                    .padding(.top, 36)

                    Picker("認証モード", selection: $mode) {
                        ForEach(AuthMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(spacing: 14) {
                        TextField("メールアドレス", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)

                        SecureField("パスワード", text: $password)
                            .textContentType(mode == .signIn ? .password : .newPassword)
                            .textFieldStyle(.roundedBorder)

                        if mode == .signUp {
                            SecureField("パスワード確認", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        if appState.isAuthenticating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Label(mode.primaryActionTitle, systemImage: mode.systemImage)
                        }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(!canSubmit || appState.isAuthenticating)

                    VStack(alignment: .leading, spacing: 10) {
                        Label("ログイン方法はメールアドレスとパスワードです", systemImage: "envelope.fill")
                        Label("新規作成後にユーザー名を設定します", systemImage: "person.text.rectangle.fill")
                        Label("アカウント情報はFirestoreに保存されます", systemImage: "lock.doc.fill")
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PetalogTheme.secondaryText)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(PetalogTheme.border, lineWidth: 1)
                    }
                }
                .padding(20)
            }
            .background(PetalogTheme.glassBackground)
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
    @State private var avatar = "🙂"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Text(avatar)
                            .font(.system(size: 78))
                            .frame(width: 112, height: 112)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay { Circle().stroke(PetalogTheme.border, lineWidth: 1) }

                        Text("ユーザー名を決めよう")
                            .font(.largeTitle.bold())
                            .foregroundStyle(PetalogTheme.text)
                            .multilineTextAlignment(.center)

                        Text(email)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PetalogTheme.secondaryText)
                    }
                    .padding(.top, 36)

                    TextField("ユーザー名", text: $displayName)
                        .font(.title3.weight(.bold))
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 8) {
                        ForEach(["🙂", "😆", "😎", "😊", "🤩", "🌟"], id: \.self) { candidate in
                            Button(candidate) { avatar = candidate }
                                .font(.title2)
                                .frame(width: 42, height: 42)
                                .background {
                                    if candidate == avatar {
                                        Circle().fill(PetalogTheme.primary.opacity(0.16))
                                    } else {
                                        Circle().fill(.ultraThinMaterial)
                                    }
                                }
                                .clipShape(Circle())
                        }
                    }

                    Button {
                        Task { await appState.completeProfile(displayName: displayName, avatar: avatar) }
                    } label: {
                        if appState.isAuthenticating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Label("petalogを始める", systemImage: "sparkles")
                        }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(displayName.trimmedForPetalog.isEmpty || appState.isAuthenticating)

                    Button("別のアカウントでログイン") {
                        appState.signOut()
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PetalogTheme.secondaryText)
                }
                .padding(20)
            }
            .background(PetalogTheme.glassBackground)
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
