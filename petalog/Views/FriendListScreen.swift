import SwiftUI

struct FriendListScreen: View {
    @EnvironmentObject private var appState: AppState
    var showsRootTabBar = false
    @State private var selectedProfile: AppUser?
    @State private var friendToDelete: AppFriend?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                HStack(alignment: .center) {
                    Text("友達一覧")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColors.accentPink)
                        .tracking(0.4)

                    Spacer()

                    NavigationLink {
                        FriendAddScreen()
                    } label: {
                        Label("追加", systemImage: "person.badge.plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.mainText)
                            .labelStyle(.titleAndIcon)
                            .padding(.horizontal, 13)
                            .frame(height: 40)
                            .background(AppColors.elevatedSurface.opacity(0.96), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(AppColors.mainText.opacity(0.16), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("友達追加")
                }

                if appState.friends.isEmpty {
                    EmptyStateView(systemImage: "person.2", title: "まだ友達がいません", message: "友達になると、ここに一覧で表示されます。")
                } else {
                    VStack(spacing: 0) {
                        ForEach(appState.friends) { friend in
                            let latestProfile = appState.observedUserProfiles[friend.friendId]
                            FriendListRow(
                                friend: friend,
                                latestProfile: latestProfile,
                                onOpen: { selectedProfile = friend.profileUser(latestProfile: latestProfile) },
                                onDelete: { friendToDelete = friend }
                            )
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
        .rootTabBar(shows: showsRootTabBar, selection: $appState.selectedTab)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedProfile) { user in
            FriendProfileScreen(user: user)
        }
        .confirmationDialog(
            "友達を削除しますか？",
            isPresented: Binding(
                get: { friendToDelete != nil },
                set: { if !$0 { friendToDelete = nil } }
            ),
            presenting: friendToDelete
        ) { friend in
            Button("削除", role: .destructive) {
                Task {
                    await appState.removeFriend(friend)
                    friendToDelete = nil
                }
            }
            Button("キャンセル", role: .cancel) {
                friendToDelete = nil
            }
        } message: { friend in
            Text("\(friend.friendName)を友達一覧から削除します。")
        }
    }
}

private struct FriendListRow: View {
    let friend: AppFriend
    let latestProfile: AppUser?
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    FriendListAvatar(friend: friend, latestProfile: latestProfile)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppColors.mainText)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.darkSilver)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            #if !DEBUG
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.secondaryText)
                    .frame(width: 40, height: 40)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(displayName)を削除")
            #endif
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 0.8)
        }
    }

    private var displayName: String {
        latestProfile?.displayName ?? friend.friendName
    }
}

private extension AppFriend {
    func profileUser(latestProfile: AppUser?) -> AppUser {
        if let latestProfile {
            return latestProfile
        }
        return AppUser(
            id: friendId,
            email: friendEmail,
            displayName: friendName,
            avatar: friendAvatar,
            avatarURL: friendAvatarURL
        )
    }
}

private struct FriendListAvatar: View {
    let friend: AppFriend
    let latestProfile: AppUser?

    var body: some View {
        Group {
            if let avatarURL = latestProfile?.avatarURL ?? friend.friendAvatarURL, !avatarURL.isEmpty {
                RemoteImageView(urlString: avatarURL) {
                    placeholder
                }
            } else if avatarText.isEmpty {
                placeholder
            } else {
                Text(avatarText)
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

    private var avatarText: String {
        latestProfile?.avatar ?? friend.friendAvatar
    }
}
