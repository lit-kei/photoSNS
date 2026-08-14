import SwiftUI

struct FriendAddScreen: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var isAdding = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("友達追加")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(AppColors.mainText)
                    Text("メールアドレスでpetalogの友達を追加できます。")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.secondaryText)
                        .lineSpacing(3)
                }

                MetalCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("メールアドレス", systemImage: "envelope")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.secondaryText)

                        TextField("friend@example.com", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.plain)
                            .metalTextField()

                        Button {
                            Task { await addFriend() }
                        } label: {
                            if isAdding {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Label("友達に追加", systemImage: "person.badge.plus")
                            }
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                        .disabled(email.trimmedForPetalog.isEmpty || isAdding)
                        .opacity(email.trimmedForPetalog.isEmpty ? 0.48 : 1)
                    }
                }

                ControlSection(title: "友達") {
                    if appState.friends.isEmpty {
                        EmptyStateView(systemImage: "person.2", title: "まだ友達がいません", message: "メールアドレスで友達を追加するとここに表示されます。")
                    } else {
                        VStack(spacing: 10) {
                            ForEach(appState.friends) { friend in
                                FriendRow(friend: friend)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, AppSpacing.floatingTabClearance)
        }
        .background {
            PetalogMetalBackground()
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func addFriend() async {
        isAdding = true
        await appState.addFriend(email: email)
        if appState.errorMessage == nil {
            email = ""
        }
        isAdding = false
    }
}

private struct FriendRow: View {
    let friend: AppFriend

    var body: some View {
        HStack(spacing: 12) {
            FriendAvatar(friend: friend)

            VStack(alignment: .leading, spacing: 4) {
                Text(friend.friendName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.mainText)
                Text(friend.friendEmail)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.secondaryText)
            }

            Spacer()
        }
        .padding(12)
        .background(AppColors.surface.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.8)
        }
    }
}

private struct FriendAvatar: View {
    let friend: AppFriend

    var body: some View {
        Group {
            if let avatarURL = friend.friendAvatarURL, let url = URL(string: avatarURL), !avatarURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else if friend.friendAvatar.isEmpty {
                placeholder
            } else {
                Text(friend.friendAvatar)
                    .font(.title3)
            }
        }
        .frame(width: 44, height: 44)
        .background(AppColors.chromeHighlight.opacity(0.78))
        .clipShape(Circle())
        .overlay { Circle().stroke(AppColors.border, lineWidth: 0.8) }
    }

    private var placeholder: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(AppColors.mainText.opacity(0.72))
    }
}
