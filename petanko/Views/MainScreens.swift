//
//  MainScreens.swift
//  petanko
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
                PetankoMetalBackground()
            }
            .rootTabBar(shows: showsRootTabBar, selection: $appState.selectedTab)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isShowingGroupOptions) {
                GroupActionSheet { route in
                    isShowingGroupOptions = false
                    groupRoute = route
                }
            }
            .navigationDestination(item: $groupRoute) { route in
                switch route {
                case .create:
                    GroupManagementScreen(initialMode: .create)
                case .join:
                    GroupManagementScreen(initialMode: .join)
                }
            }
            .navigationDestination(isPresented: $appState.isShowingNotifications) {
                HomeNotificationScreen()
            }
        }
    }

    private var header: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 5) {
                BrandWordmark()

            }
            .frame(width: 184)

            HStack(spacing: 10) {

                NavigationLink {
                    FriendAddScreen()
                } label: {
                    RootTabHeaderPersonAddIconLabel(systemName: "person.fill")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("友達追加")
                Spacer()
                NavigationLink {
                    HomeNotificationScreen()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        RootTabHeaderSystemIconLabel(systemName: "bell")
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
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.darkSilver)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
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

private struct GroupActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (GroupRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(AppColors.border)
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 6) {
                Text("グループ")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppColors.mainText)
            }

            VStack(spacing: 12) {
                GroupActionCard(
                    title: "グループを作る",
                    systemImage: "person.3.fill",
                    tint: AppColors.accentPink
                ) {
                    onSelect(.create)
                }

                GroupActionCard(
                    title: "招待コードで参加する",
                    systemImage: "number.square.fill",
                    tint: AppColors.accentBlue
                ) {
                    onSelect(.join)
                }
            }

            Button("閉じる") {
                dismiss()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(AppColors.secondaryText)
            .frame(maxWidth: .infinity)
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 22)
        .background {
            PetankoMetalBackground()
                .ignoresSafeArea()
        }
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.hidden)
    }
}

private struct GroupActionCard: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppColors.mainText)
                        .frame(width: 48, height: 48)
                        .background(tint.opacity(0.86), in: Circle())
                        .overlay {
                            Circle().stroke(AppColors.border, lineWidth: 0.8)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppColors.mainText)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.darkSilver)
                }
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())

                actionDivider
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var actionDivider: some View {
        Rectangle()
            .fill(AppColors.border)
            .frame(height: 0.8)
        .accessibilityHidden(true)
    }
}

private struct GroupListSection: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "グループ")

            if appState.groups.isEmpty {
                EmptyStateView(
                    systemImage: "person.3",
                    title: "まだグループがありません",
                    message: "",
                    style: .collage(.groups),
                    size: 44
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(appState.groups) { group in
                        NavigationLink(value: group) {
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
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

struct HomeNotificationScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {


                if appState.incomingFriendRequests.isEmpty {
                    EmptyStateView(
                        systemImage: "bell",
                        title: "新着は\nまだない",
                        message: nil,
                        sectionTitle: "通知",
                        style: .collage(.notifications)
                    )
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
            PetankoMetalBackground()
        }
        .navigationTitle("通知")
        .navigationBarTitleDisplayMode(.inline)
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
    let group: PetankoGroup
    let unreadCount: Int

    var body: some View {
        HStack(spacing: 14) {
            GroupIconView(icon: group.icon, iconURL: group.iconURL, imageData: nil, size: 46, fontSize: 23)

            VStack(alignment: .leading, spacing: 5) {
                Text(group.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.mainText)
                Text("コード \(group.inviteCode)")
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
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
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
    @State private var navigationPath = NavigationPath()
    @State private var isShowingGroupOptions = false
    @State private var groupRoute: GroupRoute?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    RootTabNavigationHeader(title: "絵日記") {
                        Button {
                            isShowingGroupOptions = true
                        } label: {
                            RootTabHeaderPersonAddIconLabel(systemName: "person.3.fill")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("グループを作成または参加")
                    }

                    GroupListSection()
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.screenTop)
                .padding(.bottom, 16)
            }
            .background {
                PetankoMetalBackground()
            }
            .rootTabBar(shows: showsRootTabBar, selection: $appState.selectedTab)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isShowingGroupOptions) {
                GroupActionSheet { route in
                    isShowingGroupOptions = false
                    groupRoute = route
                }
            }
            .navigationDestination(item: $groupRoute) { route in
                switch route {
                case .create:
                    GroupManagementScreen(initialMode: .create)
                case .join:
                    GroupManagementScreen(initialMode: .join)
                }
            }
            .navigationDestination(for: PetankoGroup.self) { group in
                DiaryScreen(group: group)
            }
            .navigationDestination(for: DiaryNavigationTarget.self) { target in
                DiaryScreen(
                    group: target.group,
                    initialDateKey: target.dateKey,
                    focusedStickerId: target.stickerId
                )
            }
            .onChange(of: appState.memoriesNavigationResetID) { _, _ in
                navigationPath = NavigationPath()
                groupRoute = nil
                isShowingGroupOptions = false
            }
            .onChange(of: appState.pendingDiaryNavigationRequest) { _, request in
                openDiaryIfPossible(for: request)
            }
            .onChange(of: appState.groups) { _, _ in
                openDiaryIfPossible(for: appState.pendingDiaryNavigationRequest)
            }
            .onAppear {
                openDiaryIfPossible(for: appState.pendingDiaryNavigationRequest)
            }
        }
    }

    private func openDiaryIfPossible(for request: DiaryNotificationNavigationRequest?) {
        guard let request,
              let group = appState.groups.first(where: { $0.id == request.groupId }) else { return }
        navigationPath = NavigationPath()
        navigationPath.append(
            DiaryNavigationTarget(
                group: group,
                dateKey: request.dateKey,
                stickerId: request.stickerId
            )
        )
        appState.clearDiaryNavigationRequest(request)
    }
}

private struct DiaryNavigationTarget: Hashable {
    let group: PetankoGroup
    let dateKey: String?
    let stickerId: String?
}

struct RootTabNavigationHeader<Trailing: View>: View {
    let title: String
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let trailing: Trailing

    init(
        title: String,
        fontSize: CGFloat = 28,
        fontWeight: Font.Weight = .heavy,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: fontSize, weight: fontWeight, design: .rounded))
                .foregroundStyle(AppColors.accentPink)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer()
            trailing
        }
        .frame(maxWidth: .infinity)
        .frame(height: 46)
    }
}

struct RootTabHeaderIconLabel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(width: 44, height: 44)
            .background {
                Circle()
                    .fill(AppColors.elevatedSurface.opacity(0.96))
            }
            .overlay {
                Circle().stroke(AppColors.border, lineWidth: 0.8)
            }
            .frame(width: 46, height: 46)
    }
}

struct RootTabHeaderSystemIconLabel: View {
    let systemName: String

    var body: some View {
        RootTabHeaderIconLabel {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.mainText)
        }
    }
}

struct RootTabHeaderPersonAddIconLabel: View {
    let systemName: String
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RootTabHeaderSystemIconLabel(systemName: systemName)
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppColors.mainText)
                .background(.white, in: Circle())
                .overlay {
                    Circle().stroke(AppColors.elevatedSurface, lineWidth: 0.8)
                }
                .offset(x: 2, y: 2)
        }
        .frame(width: 46, height: 46)
    }
}

private struct MemoryListCard: View {
    let group: PetankoGroup

    var body: some View {
        MetalCard(padding: 15) {
            HStack(spacing: 14) {
                GroupIconView(icon: group.icon, iconURL: group.iconURL, imageData: nil, size: 46, fontSize: 24)

                VStack(alignment: .leading, spacing: 5) {
                    Text(group.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.mainText)
                    Text("\(Date().petankoDisplayDate) / \(group.diaryCount)枚")
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
    @State private var isShowingMyQR = false
    @State private var selectedFriendProfile: AppUser?
    var showsRootTabBar = false

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                RootTabNavigationHeader(title: "プロフィール") {
                    NavigationLink {
                        SettingsScreen()
                    } label: {
                        RootTabHeaderSystemIconLabel(systemName: "gearshape.fill")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("設定")
                }

                VStack(spacing: 18) {
                    ProfileAvatarView(user: appState.currentUser, size: 132)

                    if let currentUser = appState.currentUser {
                        Text(currentUser.displayName)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.mainText)
                            .multilineTextAlignment(.center)

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

                            NavigationLink {
                                StickerCollectionScreen()
                            } label: {
                                Label("コレクション", systemImage: "square.grid.3x3.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryActionButtonStyle())
                        }
                        
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.screenTop)
            .padding(.bottom, 16)
        }
        .background {
            PetankoMetalBackground()
        }
        .rootTabBar(shows: showsRootTabBar, selection: $appState.selectedTab)
        .toolbar(.hidden, for: .navigationBar)
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

struct StickerCollectionScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var stickers: [StickerPost] = []
    @State private var selectedSticker: StickerPost?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.screenTop)
                .padding(.bottom, 20)
        }
        .background {
            PetankoMetalBackground()
        }
        .navigationTitle("コレクション")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: appState.currentUser?.id) {
            await loadCollection()
        }
        .refreshable {
            await loadCollection(showLoading: false)
        }
        .sheet(item: $selectedSticker) { sticker in
            CollectionStickerDetailSheet(sticker: sticker)
                .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            VStack {
                ProgressView()
                    .tint(AppColors.mainText)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 80)
        } else if let errorMessage {
            VStack(spacing: 14) {
                EmptyStateView(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "読み込めませんでした",
                    message: errorMessage
                )

                Button {
                    Task { await loadCollection() }
                } label: {
                    Label("再読み込み", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
        } else if stickers.isEmpty {
            EmptyStateView(
                systemImage: "square.grid.3x3.fill",
                title: "まだ\n空っぽ",
                message: "作成したステッカーがここに集まります。",
                sectionTitle: "コレクション",
                style: .collage(.collection)
            )
            .frame(maxWidth: .infinity)
            .padding(.top, 48)
        } else {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(stickers) { sticker in
                    Button {
                        selectedSticker = sticker
                    } label: {
                        CollectionStickerTile(sticker: sticker)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func loadCollection(showLoading: Bool = true) async {
        if showLoading {
            isLoading = true
        }
        errorMessage = nil
        do {
            stickers = try await appState.fetchMyCollectionStickers()
        } catch {
            stickers = []
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct CollectionStickerTile: View {
    let sticker: StickerPost

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(AppColors.elevatedSurface.opacity(0.96))

            RemoteStickerView(sticker: sticker, size: 86)
                .padding(10)
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.border, lineWidth: 0.8)
        }
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }
}

private struct CollectionStickerDetailSheet: View {
    let sticker: StickerPost
    @State private var photoSaveMessage: String?
    @State private var isSavingToPhotos = false

    var body: some View {
        VStack(spacing: 18) {
            RemoteStickerView(sticker: sticker, size: 180)

            VStack(alignment: .leading, spacing: 10) {
                Label(sticker.createdAt.petankoDateTimeText, systemImage: "clock.fill")

                Label(sticker.comment.isEmpty ? "コメントなし" : sticker.comment, systemImage: "bubble.left.fill")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.headline)
            .foregroundStyle(AppColors.mainText)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                saveStickerToPhotos()
            } label: {
                Label(isSavingToPhotos ? "保存中…" : "写真を保存", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(isSavingToPhotos || sticker.stickerImageURL.isEmpty)
        }
        .padding(24)
        .alert("写真への保存", isPresented: Binding(
            get: { photoSaveMessage != nil },
            set: { if !$0 { photoSaveMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(photoSaveMessage ?? "")
        }
    }

    private func saveStickerToPhotos() {
        guard !isSavingToPhotos else { return }
        isSavingToPhotos = true
        Task {
            do {
                try await StickerPhotoLibraryService.saveSticker(from: sticker.stickerImageURL)
                photoSaveMessage = "ステッカーを写真に保存しました。"
            } catch {
                photoSaveMessage = error.localizedDescription
            }
            isSavingToPhotos = false
        }
    }
}

struct ProfileEditScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var displayName = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var isSavingProfile = false
    @State private var currentAvatarURL: String?
    @FocusState private var isDisplayNameFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(spacing: 30) {

                VStack(spacing: 18) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                        ProfilePhotoPickerLabel(
                            imageData: selectedPhotoData,
                            imageURLString: currentAvatarURL
                        )
                    }
                    .buttonStyle(.plain)


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
                                .focused($isDisplayNameFocused)
                        }
                    }
                    .id("displayNameEditor")
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
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.screenTop + 18)
            .padding(.bottom, isDisplayNameFocused ? 220 : 16)
            .animation(.easeOut(duration: 0.22), value: isDisplayNameFocused)
        }
        .onChange(of: isDisplayNameFocused) { _, isFocused in
            guard isFocused else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(120))
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo("displayNameEditor", anchor: .center)
                }
            }
        }
        }
        .background {
            PetankoMetalBackground()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("プロフィール編集")
        .onAppear {
            displayName = appState.currentUser?.displayName ?? ""
            currentAvatarURL = appState.currentUser?.avatarURL
        }
    }
}

struct BlockedUsersScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var unblockingUserIds: Set<String> = []
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                if appState.blockedUsers.isEmpty {
                    EmptyStateView(
                        systemImage: "hand.raised",
                        title: "ブロック中は\nいません",
                        message: nil,
                        sectionTitle: "ブロック",
                        style: .collage(.blockedUsers)
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(appState.blockedUsers) { block in
                            blockedUserRow(block)
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.screenTop)
            .padding(.bottom, 16)
        }
        .background {
            PetankoMetalBackground()
        }
        .navigationTitle("ブロックしたユーザー")
        .navigationBarTitleDisplayMode(.inline)
        .alert("ブロック解除", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private func blockedUserRow(_ block: UserBlock) -> some View {
        let profile = appState.observedUserProfiles[block.blockedUserId]
        let isUnblocking = unblockingUserIds.contains(block.blockedUserId)
        return HStack(spacing: 12) {
            BlockedUserAvatar(user: profile)

            VStack(alignment: .leading, spacing: 4) {
                Text(profile?.displayName ?? "petanko user")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.mainText)
                Text(profile?.playerId ?? block.blockedUserId)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppColors.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                Task { await unblock(block.blockedUserId, displayName: profile?.displayName) }
            } label: {
                if isUnblocking {
                    ProgressView()
                        .tint(AppColors.mainText)
                } else {
                    Text("解除")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColors.mainText)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(AppColors.elevatedSurface.opacity(0.96), in: Capsule())
            .overlay {
                Capsule().stroke(AppColors.border, lineWidth: 0.8)
            }
            .disabled(isUnblocking)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 0.8)
        }
    }

    private func unblock(_ userId: String, displayName: String?) async {
        guard unblockingUserIds.insert(userId).inserted else { return }
        let success = await appState.unblockUser(userId)
        unblockingUserIds.remove(userId)
        message = success ? "\(displayName ?? "ユーザー")さんのブロックを解除しました。投稿を見るには再度フレンドになる必要があります。" : "ブロックを解除できませんでした。"
    }
}

private struct BlockedUserAvatar: View {
    let user: AppUser?

    var body: some View {
        Group {
            if let avatarURL = user?.avatarURL, !avatarURL.isEmpty {
                RemoteImageView(urlString: avatarURL) {
                    placeholder
                }
            } else if let avatar = user?.avatar, !avatar.isEmpty {
                Text(avatar)
                    .font(.system(size: 20))
            } else {
                placeholder
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

private struct ProfileAvatarView: View {
    let user: AppUser?
    let size: CGFloat

    var body: some View {
        Group {
            if let avatarURL = user?.avatarURL, !avatarURL.isEmpty {
                RemoteImageView(urlString: avatarURL) {
                    placeholder
                }
            } else if let avatar = user?.avatar, !avatar.isEmpty {
                Text(avatar)
                    .font(.system(size: size * 0.48))
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .background {
            Circle()
                .fill(AppColors.elevatedSurface)
        }
        .clipShape(Circle())
        .overlay {
            Circle().stroke(AppColors.border, lineWidth: 0.8)
        }
    }

    private var placeholder: some View {
        Image(systemName: "person.crop.circle.fill")
            .font(.system(size: size * 0.55, weight: .regular))
            .foregroundStyle(AppColors.mainText.opacity(0.72))
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
