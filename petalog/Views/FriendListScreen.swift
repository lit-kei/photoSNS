import SwiftUI

struct FriendListScreen: View {
    @EnvironmentObject private var appState: AppState
    var showsRootTabBar = false
    @State private var selectedProfile: AppUser?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("友達一覧")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(AppColors.mainText)
                    Text("友達になっている人")
                        .font(.system(size: 15))
                        .foregroundStyle(AppColors.secondaryText)
                }

                if appState.friends.isEmpty {
                    EmptyStateView(systemImage: "person.2", title: "まだ友達がいません", message: "友達になると、ここに一覧で表示されます。")
                } else {
                    VStack(spacing: 0) {
                        ForEach(appState.friends) { friend in
                            Button {
                                selectedProfile = AppUser(
                                    id: friend.friendId,
                                    email: friend.friendEmail,
                                    displayName: friend.friendName,
                                    avatar: friend.friendAvatar,
                                    avatarURL: friend.friendAvatarURL
                                )
                            } label: {
                                FriendListRow(friend: friend)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.screenTop + 18)
            .padding(.bottom, 16)
        }
        .background {
            PetalogMetalBackground()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsRootTabBar {
                AttachedBottomTabBar(selection: $appState.selectedTab)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedProfile) { user in
            FriendProfileScreen(user: user)
        }
    }
}

private struct FriendListRow: View {
    let friend: AppFriend

    var body: some View {
        HStack(spacing: 12) {
            FriendListAvatar(friend: friend)

            VStack(alignment: .leading, spacing: 4) {
                Text(friend.friendName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.mainText)
                Text("プロフィールを見る")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.secondaryText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.darkSilver)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 0.8)
        }
    }
}

private struct FriendListAvatar: View {
    let friend: AppFriend

    var body: some View {
        Group {
            if let avatarURL = friend.friendAvatarURL, !avatarURL.isEmpty {
                RemoteImageView(urlString: avatarURL) {
                    placeholder
                }
            } else if friend.friendAvatar.isEmpty {
                placeholder
            } else {
                Text(friend.friendAvatar)
                    .font(.system(size: 22))
            }
        }
        .frame(width: 44, height: 44)
        .background(AppColors.chromeHighlight.opacity(0.78))
        .clipShape(Circle())
        .overlay {
            Circle().stroke(AppColors.border, lineWidth: 0.8)
        }
    }

    private var placeholder: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(AppColors.mainText.opacity(0.72))
    }
}
