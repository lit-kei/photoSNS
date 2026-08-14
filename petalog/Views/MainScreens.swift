//
//  MainScreens.swift
//  petalog
//

import SwiftUI
import UIKit

struct HomeScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    header
                    cameraCTA
                    quickActions
                    groupsSection
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.screenTop)
                .padding(.bottom, 28)
            }
            .background {
                PetalogMetalBackground()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    BrandWordmark()
                    Text(Date().petalogDisplayDate)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.secondaryText)
                }

                Spacer()

                NavigationLink {
                    GroupManagementScreen(initialMode: .list)
                } label: {
                    IconButtonLabel(systemName: "person.2.badge.gearshape")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("グループ管理")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("今日の思い出をつくろう")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(AppColors.mainText)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                if let user = appState.currentUser {
                    Text("\(user.avatar) \(user.displayName)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
        }
    }

    private var cameraCTA: some View {
        NavigationLink {
            CameraScreen()
        } label: {
            HStack(spacing: 18) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 24, weight: .semibold))
                    .frame(width: 54, height: 54)
                    .background(.white.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text("写真を撮る")
                        .font(.system(size: 20, weight: .semibold))
                    Text("ステッカーにする1枚を残す")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.12))
                    .clipShape(Circle())
            }
            .foregroundStyle(.white)
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.charcoal,
                                Color(red: 0.22, green: 0.23, blue: 0.25),
                                AppColors.darkSilver
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.22), lineWidth: 0.8)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            NavigationLink {
                GroupManagementScreen(initialMode: .create)
            } label: {
                Label("グループを作る", systemImage: "person.3")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryActionButtonStyle())

            NavigationLink {
                GroupManagementScreen(initialMode: .join)
            } label: {
                Label("参加する", systemImage: "qrcode.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
    }

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "今日のグループ", subtitle: appState.groups.isEmpty ? nil : "絵日記に集まる今日の投稿")

            if appState.groups.isEmpty {
                EmptyStateView(systemImage: "person.3", title: "まだグループがありません", message: "グループを作るか、招待コードで参加すると今日の絵日記を始められます。")
            } else {
                VStack(spacing: 12) {
                    ForEach(appState.groups) { group in
                        NavigationLink {
                            DiaryScreen(group: group)
                        } label: {
                            GroupActivityCard(group: group)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct GroupActivityCard: View {
    let group: PetalogGroup

    var body: some View {
        MetalCard(padding: 16) {
            HStack(spacing: 14) {
                AvatarToken(symbol: group.icon, size: 48, fontSize: 24)

                VStack(alignment: .leading, spacing: 5) {
                    Text(group.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.mainText)
                    Text("invite \(group.inviteCode)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppColors.secondaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(group.diaryCount)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.mainText)
                    Text("posts")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.secondaryText)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.darkSilver)
            }
        }
    }
}

struct MemoriesScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("思い出")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(AppColors.mainText)
                        Text("1日1枚の絵日記")
                            .font(.system(size: 15))
                            .foregroundStyle(AppColors.secondaryText)
                    }

                    if appState.groups.isEmpty {
                        EmptyStateView(systemImage: "book.closed", title: "思い出はこれから", message: "グループでステッカーを貼ると、1日1枚の絵日記がここに並びます。")
                    } else {
                        VStack(spacing: 12) {
                            ForEach(appState.groups) { group in
                                NavigationLink {
                                    DiaryScreen(group: group)
                                } label: {
                                    MemoryListCard(group: group)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.screenTop + 18)
                .padding(.bottom, 28)
            }
            .background {
                PetalogMetalBackground()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct MemoryListCard: View {
    let group: PetalogGroup

    var body: some View {
        MetalCard(padding: 15) {
            HStack(spacing: 14) {
                AvatarToken(symbol: group.icon, size: 46, fontSize: 24)

                VStack(alignment: .leading, spacing: 5) {
                    Text(group.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.mainText)
                    Text("\(Date().petalogDisplayDate) / \(group.diaryCount)枚")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.darkSilver)
            }
        }
    }
}

struct ProfileScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var displayName = ""
    @State private var avatar = "🙂"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    Text("プロフィール")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(AppColors.mainText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 18) {
                        MetallicAvatar(symbol: avatar)

                        TextField("ユーザー名", text: $displayName)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(AppColors.mainText)
                            .multilineTextAlignment(.center)
                            .textFieldStyle(.plain)
                            .padding(.vertical, 10)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(AppColors.border)
                                    .frame(height: 1)
                            }

                        HStack(spacing: 10) {
                            ForEach(["🙂", "😆", "😎", "😊", "🤩", "🌟"], id: \.self) { candidate in
                                EmojiChip(symbol: candidate, isSelected: candidate == avatar) {
                                    withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                                        avatar = candidate
                                    }
                                }
                            }
                        }
                    }

                    Button {
                        Task { await appState.updateProfile(displayName: displayName, avatar: avatar) }
                    } label: {
                        Label("プロフィールを保存", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    StatsStrip(
                        groups: appState.groups.count,
                        members: appState.groups.reduce(0) { $0 + $1.memberIds.count },
                        diaries: appState.groups.reduce(0) { $0 + $1.diaryCount }
                    )

                    MetalCard(padding: 16) {
                        HStack(spacing: 14) {
                            Image(systemName: "scissors")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppColors.mainText)
                                .frame(width: 42, height: 42)
                                .background(AppColors.chromeHighlight.opacity(0.78))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text("作ったステッカー")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppColors.mainText)
                                Text("ギャラリーは今後ここに表示されます")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppColors.secondaryText)
                            }

                            Spacer()
                        }
                    }

                    Button("ログアウト") {
                        appState.signOut()
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.secondaryText)
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.screenTop + 18)
                .padding(.bottom, 34)
            }
            .background {
                PetalogMetalBackground()
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                displayName = appState.currentUser?.displayName ?? ""
                avatar = appState.currentUser?.avatar ?? "🙂"
            }
        }
    }
}

private struct AvatarToken: View {
    let symbol: String
    let size: CGFloat
    let fontSize: CGFloat

    var body: some View {
        Text(symbol)
            .font(.system(size: fontSize))
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.chromeHighlight, AppColors.silver.opacity(0.32), AppColors.elevatedSurface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay { Circle().stroke(AppColors.border, lineWidth: 0.8) }
    }
}

private struct MetallicAvatar: View {
    let symbol: String

    var body: some View {
        Text(symbol)
            .font(.system(size: 70))
            .frame(width: 132, height: 132)
            .background {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.chromeHighlight,
                                AppColors.silver.opacity(0.54),
                                AppColors.elevatedSurface,
                                AppColors.darkSilver.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                Circle().stroke(AppColors.border, lineWidth: 0.8)
            }
            .shadow(color: AppColors.silver.opacity(0.22), radius: 18, y: 8)
    }
}

private struct EmojiChip: View {
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 20))
                .frame(width: 42, height: 42)
                .background {
                    Circle()
                        .fill(AppColors.surface.opacity(0.95))
                }
                .overlay {
                    Circle()
                        .stroke(isSelected ? AppColors.mainText.opacity(0.72) : AppColors.border, lineWidth: isSelected ? 1.2 : 0.8)
                }
                .shadow(color: isSelected ? AppColors.silver.opacity(0.34) : .clear, radius: 10, y: 4)
                .scaleEffect(isSelected ? 1.08 : 1)
        }
        .buttonStyle(.plain)
    }
}

private struct StatsStrip: View {
    let groups: Int
    let members: Int
    let diaries: Int

    var body: some View {
        MetalCard(padding: 0) {
            HStack(spacing: 0) {
                ProfileStat(title: "グループ", value: "\(groups)")
                Divider().frame(height: 34)
                ProfileStat(title: "参加中", value: "\(members)")
                Divider().frame(height: 34)
                ProfileStat(title: "絵日記", value: "\(diaries)")
            }
            .padding(.vertical, 16)
        }
    }
}

private struct ProfileStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppColors.mainText)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}
