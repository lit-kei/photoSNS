//
//  MainScreens.swift
//  petalog
//

import PhotosUI
import SwiftUI
import UIKit

struct HomeScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    header
                    quickActions
                    groupsSection
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.screenTop)
                .padding(.bottom, AppSpacing.floatingTabClearance)
            }
            .background {
                PetalogMetalBackground()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("ホーム")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppColors.mainText)
                    Text(Date().petalogDisplayDate)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.secondaryText)
                    if let user = appState.currentUser {
                        Text(user.displayName)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }

                Spacer()

                HStack(spacing: 10) {
                    NavigationLink {
                        ProfileScreen()
                    } label: {
                        IconButtonLabel(systemName: "person.crop.circle")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("プロフィール")

                    NavigationLink {
                        FriendAddScreen()
                    } label: {
                        IconButtonLabel(systemName: "person.badge.plus")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("友達追加")
                }
            }
        }
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
                GroupIconView(icon: group.icon, iconURL: group.iconURL, imageData: nil, size: 48, fontSize: 24)

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
                .padding(.bottom, AppSpacing.floatingTabClearance)
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
                GroupIconView(icon: group.icon, iconURL: group.iconURL, imageData: nil, size: 46, fontSize: 24)

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
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var isSavingProfile = false
    @State private var currentAvatarURL: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                HStack {
                    Text("プロフィール")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(AppColors.mainText)

                    Spacer()
                }

                VStack(spacing: 18) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                        ProfilePhotoPickerLabel(
                            imageData: selectedPhotoData,
                            imageURLString: currentAvatarURL
                        )
                    }
                    .buttonStyle(.plain)

                    Text("写真を変更")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.secondaryText)

                    MetalCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("ユーザー名を編集", systemImage: "pencil")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColors.secondaryText)

                            TextField("ユーザー名", text: $displayName)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(AppColors.mainText)
                                .textFieldStyle(.plain)
                                .padding(.vertical, 13)
                                .padding(.horizontal, 14)
                                .background(AppColors.elevatedSurface.opacity(0.92))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(AppColors.border, lineWidth: 0.8)
                                }
                        }
                    }
                }
                .onChange(of: selectedPhotoItem) { _, item in
                    Task {
                        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
                        selectedPhotoData = data
                    }
                }

                Button {
                    Task {
                        isSavingProfile = true
                        await appState.updateProfile(displayName: displayName, avatarImageData: selectedPhotoData)
                        currentAvatarURL = appState.currentUser?.avatarURL
                        selectedPhotoData = nil
                        selectedPhotoItem = nil
                        isSavingProfile = false
                    }
                } label: {
                    if isSavingProfile {
                        ProgressView()
                            .tint(AppColors.mainText)
                    } else {
                        Label("プロフィールを保存", systemImage: "checkmark.circle")
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(isSavingProfile)

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
                            .background(AppColors.dustyPink.opacity(0.18))
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
            .padding(.bottom, AppSpacing.floatingTabClearance)
        }
        .background {
            PetalogMetalBackground()
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            displayName = appState.currentUser?.displayName ?? ""
            currentAvatarURL = appState.currentUser?.avatarURL
        }
    }
}

private struct AvatarToken: View {
    let symbol: String
    let size: CGFloat
    let fontSize: CGFloat

    var body: some View {
        Group {
            if symbol.isEmpty {
                Image(systemName: "person.fill")
                    .font(.system(size: fontSize * 0.74, weight: .semibold))
                    .foregroundStyle(AppColors.mainText.opacity(0.72))
            } else {
                Text(symbol)
                    .font(.system(size: fontSize))
            }
        }
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(AppColors.elevatedSurface)
            }
            .overlay { Circle().stroke(AppColors.border, lineWidth: 0.8) }
    }
}

private struct ProfilePhotoPickerLabel: View {
    let imageData: Data?
    let imageURLString: String?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            avatarContent
                .frame(width: 132, height: 132)
                .background {
                    Circle()
                        .fill(AppColors.elevatedSurface)
                }
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(AppColors.border, lineWidth: 0.8)
                }
                .shadow(color: AppColors.kraftBeige.opacity(0.22), radius: 18, y: 8)

            Image(systemName: "camera.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.mainText)
                .frame(width: 38, height: 38)
                .background(AppColors.elevatedSurface.opacity(0.96))
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(AppColors.border, lineWidth: 0.8)
                }
        }
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let imageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else if let imageURLString, !imageURLString.isEmpty {
            RemoteImageView(urlString: imageURLString) {
                placeholder
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Image(systemName: "person.crop.circle.fill")
            .font(.system(size: 72, weight: .regular))
            .foregroundStyle(AppColors.mainText.opacity(0.72))
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
