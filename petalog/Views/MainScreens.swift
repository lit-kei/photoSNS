//
//  MainScreens.swift
//  petalog
//

import PhotosUI
import SwiftUI
import UIKit

struct HomeScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var isShowingGroupOptions = false
    @State private var groupRoute: GroupRoute?
    var showsRootTabBar = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    header
                    quickActions
                    friendFeedSection
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.screenTop)
                .padding(.bottom, 16)
            }
            .background {
                PetalogMetalBackground()
            }
            .rootTabBar(shows: showsRootTabBar, selection: $appState.selectedTab)
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog("グループ", isPresented: $isShowingGroupOptions, titleVisibility: .visible) {
                Button("グループを作る") {
                    groupRoute = .create
                }
                Button("参加する") {
                    groupRoute = .join
                }
                Button("キャンセル", role: .cancel) {}
            }
            .navigationDestination(item: $groupRoute) { route in
                switch route {
                case .create:
                    GroupManagementScreen(initialMode: .create)
                case .join:
                    GroupManagementScreen(initialMode: .join)
                }
            }
        }
    }

    private var header: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 5) {
                BrandWordmark()
                
            }
            .frame(width: 156)

            HStack(spacing: 10) {

                NavigationLink {
                    FriendAddScreen()
                } label: {
                    IconButtonLabel(systemName: "person.badge.plus")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("友達追加")
                Spacer()
                NavigationLink {
                    HomeNotificationScreen()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        IconButtonLabel(systemName: "bell")
                        if !appState.incomingFriendRequests.isEmpty {
                            Circle()
                                .fill(AppColors.accentPink)
                                .frame(width: 9, height: 9)
                                .offset(x: -2, y: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("通知")
            }
        }
    }

    private var quickActions: some View {
        Button {
            isShowingGroupOptions = true
        } label: {
            HomeGroupActionRow()
        }
        .buttonStyle(.plain)
    }

    private var friendFeedSection: some View {
        FriendTodayFeedSection()
    }
}

private struct HomeGroupActionRow: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColors.mainText)
                .frame(width: 46, height: 46)
                .background(AppColors.chromeHighlight.opacity(0.78), in: Circle())
                .overlay {
                    Circle().stroke(AppColors.border, lineWidth: 0.8)
                }

            VStack(alignment: .leading, spacing: 5) {
                Text("グループ")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.mainText)
                Text("作成・参加")
                    .font(.system(size: 12, weight: .medium))
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

private enum GroupRoute: Identifiable {
    case create
    case join

    var id: String {
        switch self {
        case .create: "create"
        case .join: "join"
        }
    }
}

private struct GroupListSection: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "グループ")

            if appState.groups.isEmpty {
                EmptyStateView(systemImage: "person.3", title: "まだグループがありません", message: "グループを作るか、招待コードで参加すると今日の絵日記を始められます。")
            } else {
                VStack(spacing: 0) {
                    ForEach(appState.groups) { group in
                        NavigationLink {
                            DiaryScreen(group: group)
                        } label: {
                            GroupActivityRow(
                                group: group,
                                unreadCount: appState.unreadPostCounts[group.id, default: 0]
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct HomeNotificationScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "通知", subtitle: notificationSubtitle)

                if appState.incomingFriendRequests.isEmpty {
                    EmptyStateView(systemImage: "bell", title: "新しい通知はありません", message: "友達申請などのお知らせがここに表示されます。")
                } else {
                    VStack(spacing: 12) {
                        ForEach(appState.incomingFriendRequests) { request in
                            incomingRequestRow(request)
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.screenTop)
            .padding(.bottom, AppSpacing.section)
        }
        .background {
            PetalogMetalBackground()
        }
        .navigationTitle("通知")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var notificationSubtitle: String {
        appState.incomingFriendRequests.isEmpty ? "お知らせはありません" : "\(appState.incomingFriendRequests.count)件の友達申請"
    }

    private func incomingRequestRow(_ request: FriendRequest) -> some View {
        HStack(spacing: 12) {
            notificationAvatar(request)

            VStack(alignment: .leading, spacing: 4) {
                Text(request.fromName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.mainText)
                Text("友達申請が届いています")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.secondaryText)
            }

            Spacer()

            Button {
                Task {
                    await appState.acceptFriendRequest(request)
                }
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColors.mainText)
            .background(AppColors.accentPink, in: Circle())

            Button {
                Task {
                    await appState.rejectFriendRequest(request)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColors.mainText)
            .background(AppColors.surface.opacity(0.94), in: Circle())
            .overlay {
                Circle().stroke(AppColors.border, lineWidth: 0.8)
            }
        }
        .padding(14)
        .background(AppColors.elevatedSurface.opacity(0.96), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.8)
        }
    }

    private func notificationAvatar(_ request: FriendRequest) -> some View {
        Group {
            if let avatarURL = request.fromAvatarURL,
               let url = URL(string: avatarURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Image(systemName: "person.fill")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(AppColors.mainText.opacity(0.72))
                    }
                }
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(AppColors.mainText.opacity(0.72))
            }
        }
        .frame(width: 44, height: 44)
        .background(AppColors.chromeHighlight.opacity(0.78), in: Circle())
        .clipShape(Circle())
        .overlay {
            Circle().stroke(AppColors.border, lineWidth: 0.8)
        }
    }
}

private struct GroupActivityRow: View {
    let group: PetalogGroup
    let unreadCount: Int

    var body: some View {
        HStack(spacing: 14) {
            GroupIconView(icon: group.icon, iconURL: group.iconURL, imageData: nil, size: 46, fontSize: 23)

            VStack(alignment: .leading, spacing: 5) {
                Text(group.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.mainText)
                Text("招待 \(group.inviteCode)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppColors.secondaryText)
            }

            Spacer()

            if unreadCount > 0 {
                Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                    .font(.system(size: unreadCount > 99 ? 10 : 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(AppColors.burntOrange, in: Circle())
                    .accessibilityLabel("\(unreadCount)件の未読投稿")
            }

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

struct MemoriesScreen: View {
    @EnvironmentObject private var appState: AppState
    var showsRootTabBar = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("絵日記")
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppColors.accentPink)
                            .tracking(0.4)
                    }

                    GroupListSection()
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
    @State private var isShowingMyQR = false
    @State private var selectedFriendProfile: AppUser?
    var showsRootTabBar = false

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                HStack {
                    Text("プロフィール")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColors.accentPink)
                        .tracking(0.4)

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

                    if let currentUser = appState.currentUser {
                        VStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("ユーザーID")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AppColors.secondaryText)
                                Text(currentUser.playerId)
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(AppColors.mainText)
                                    .lineLimit(2)
                                    .textSelection(.enabled)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(AppColors.accentBlue.opacity(0.26))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous)
                                    .stroke(AppColors.border, lineWidth: 0.8)
                            }

                            Button {
                                isShowingMyQR = true
                            } label: {
                                Label("My QRコード", systemImage: "qrcode")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                        }
                    }

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
            .padding(.bottom, 16)
        }
        .background {
            PetalogMetalBackground()
        }
        .rootTabBar(shows: showsRootTabBar, selection: $appState.selectedTab)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            displayName = appState.currentUser?.displayName ?? ""
            currentAvatarURL = appState.currentUser?.avatarURL
        }
        .sheet(isPresented: $isShowingMyQR) {
            if let currentUser = appState.currentUser {
                MyQRCodeSheet(playerId: currentUser.playerId) { scannedId in
                    Task { await loadScannedProfile(scannedId) }
                }
                .environmentObject(appState)
            }
        }
        .navigationDestination(item: $selectedFriendProfile) { user in
            FriendProfileScreen(user: user)
        }
    }

    private func loadScannedProfile(_ playerId: String) async {
        let user = await appState.findUser(playerId: playerId)
        if let user {
            selectedFriendProfile = user
        } else if appState.errorMessage == nil {
            appState.errorMessage = "QRコードのユーザーが見つかりません。"
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
