import SwiftUI

struct FriendAddScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var playerId = ""
    @State private var selectedProfile: AppUser?
    @State private var isSearching = false
    @State private var friendToDelete: AppFriend?
    @State private var isShowingMyQR = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                searchCard
                requestSections
                friendsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .background {
            PetalogMetalBackground()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedProfile) { user in
            FriendProfileScreen(user: user)
        }
        .sheet(isPresented: $isShowingMyQR) {
            if let currentUser = appState.currentUser {
                MyQRCodeSheet(playerId: currentUser.playerId) { scannedId in
                    Task { await loadScannedProfile(scannedId) }
                }
                .environmentObject(appState)
            }
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
                deleteFriend(friend)
            }
            Button("キャンセル", role: .cancel) {
                friendToDelete = nil
            }
        } message: { friend in
            Text("\(friend.friendName)を友達一覧から削除します。")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("友達追加")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(AppColors.mainText)
        }
    }

    private var searchCard: some View {
        MetalCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                if let currentUser = appState.currentUser {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("あなたのユーザーID")
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
                }

                Label("ユーザーIDで探す", systemImage: "number")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.secondaryText)

                Button {
                    isShowingMyQR = true
                } label: {
                    Label("My QRコードを表示", systemImage: "qrcode")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.mainText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColors.elevatedSurface.opacity(0.96), in: RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.field, style: .continuous)
                                .stroke(AppColors.border, lineWidth: 0.8)
                        }
                }
                .buttonStyle(.plain)
                .disabled(appState.currentUser == nil)

                TextField("ユーザーIDを入力", text: $playerId)
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .metalTextField()

                Button {
                    Task { await searchUser() }
                } label: {
                    if isSearching {
                        ProgressView()
                            .tint(AppColors.mainText)
                    } else {
                        Label("プロフィールを見る", systemImage: "person.text.rectangle")
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(playerId.trimmedForPetalog.isEmpty || isSearching)
                .opacity(playerId.trimmedForPetalog.isEmpty ? 0.48 : 1)

            }
        }
    }

    private var requestSections: some View {
        VStack(spacing: 18) {
            ControlSection(title: "届いた申請") {
                if appState.incomingFriendRequests.isEmpty {
                    EmptyStateView(systemImage: "tray", title: "申請はありません", message: nil)
                } else {
                    VStack(spacing: 10) {
                        ForEach(appState.incomingFriendRequests) { request in
                            IncomingRequestRow(request: request)
                        }
                    }
                }
            }

            ControlSection(title: "送信中") {
                if appState.outgoingFriendRequests.isEmpty {
                    EmptyStateView(systemImage: "paperplane", title: "送信中の申請はありません", message: nil)
                } else {
                    VStack(spacing: 10) {
                        ForEach(appState.outgoingFriendRequests) { request in
                            OutgoingRequestRow(request: request)
                        }
                    }
                }
            }
        }
    }

    private var friendsSection: some View {
        ControlSection(title: "友達") {
            if appState.friends.isEmpty {
                EmptyStateView(systemImage: "person.2", title: "まだ友達がいません", message: nil)
            } else {
                VStack(spacing: 10) {
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
                            FriendRow(friend: friend)
                        }
                        .buttonStyle(.plain)
                        #if !DEBUG
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                friendToDelete = friend
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                friendToDelete = friend
                            } label: {
                                Label("友達を削除", systemImage: "trash")
                            }
                        }
                        #endif
                    }
                }
            }
        }
    }

    private func searchUser() async {
        isSearching = true
        let user = await appState.findUser(playerId: playerId)
        isSearching = false
        if let user {
            selectedProfile = user
        } else if appState.errorMessage == nil {
            appState.errorMessage = "このユーザーIDのユーザーが見つかりません。"
        }
    }

    private func deleteFriend(_ friend: AppFriend) {
        Task {
            await appState.removeFriend(friend)
            friendToDelete = nil
        }
    }

    private func loadScannedProfile(_ playerId: String) async {
        let user = await appState.findUser(playerId: playerId)
        if let user {
            selectedProfile = user
        } else if appState.errorMessage == nil {
            appState.errorMessage = "QRコードのユーザーが見つかりません。"
        }
    }

}

struct FriendProfileScreen: View {
    @EnvironmentObject private var appState: AppState
    let user: AppUser
    @State private var isSending = false
    @State private var didSend = false

    private var isCurrentUser: Bool {
        appState.currentUser?.id == user.id
    }

    private var isFriend: Bool {
        appState.friends.contains { $0.friendId == user.id }
    }

    private var hasOutgoingRequest: Bool {
        didSend || hasPendingOutgoingRequest
    }

    private var hasPendingOutgoingRequest: Bool {
        appState.outgoingFriendRequests.contains {
            $0.toUserId == user.id && $0.status == "pending"
        }
    }

    private var incomingRequest: FriendRequest? {
        appState.incomingFriendRequests.first {
            $0.fromUserId == user.id && $0.status == "pending"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                PublicUserAvatar(user: user, size: 124)
                    .padding(.top, 42)

                VStack(spacing: 7) {
                    Text(user.displayName)
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(AppColors.mainText)

                    Text("ユーザーID \(user.playerId)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                }

                profileAction
                    .frame(maxWidth: 420)

                Spacer(minLength: 30)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
        }
        .background {
            PetalogMetalBackground()
        }
        .navigationTitle("プロフィール")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: syncLocalSendState)
        .onChange(of: appState.outgoingFriendRequests) { _, _ in
            syncLocalSendState()
        }
    }

    @ViewBuilder
    private var profileAction: some View {
        if isCurrentUser {
            Label("自分のプロフィール", systemImage: "person.crop.circle")
                .profileStatusStyle()
        } else if isFriend {
            Label("友達です", systemImage: "person.2.fill")
                .profileStatusStyle()
        } else if hasOutgoingRequest {
            Label("申請済み", systemImage: "checkmark.circle.fill")
                .profileStatusStyle()
        } else if let incomingRequest {
            Button {
                Task { await appState.acceptFriendRequest(incomingRequest) }
            } label: {
                Label("届いた申請を承認する", systemImage: "person.badge.checkmark")
            }
            .buttonStyle(PrimaryActionButtonStyle())
        } else {
            Button {
                Task {
                    isSending = true
                    didSend = await appState.sendFriendRequest(to: user)
                    isSending = false
                }
            } label: {
                if isSending {
                    ProgressView()
                        .tint(AppColors.mainText)
                } else {
                    Label("フレンド申請を送る", systemImage: "person.badge.plus")
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(isSending)
        }
    }

    private func syncLocalSendState() {
        if didSend && !hasPendingOutgoingRequest {
            didSend = false
        }
    }
}

private extension View {
    func profileStatusStyle() -> some View {
        self
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(AppColors.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(AppColors.surface.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 0.8)
            }
    }
}

private struct IncomingRequestRow: View {
    @EnvironmentObject private var appState: AppState
    let request: FriendRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RequestProfile(name: request.fromName, avatar: request.fromAvatar, avatarURL: request.fromAvatarURL)
            HStack(spacing: 10) {
                Button {
                    Task { await appState.acceptFriendRequest(request) }
                } label: {
                    Label("承認", systemImage: "checkmark")
                }
                .buttonStyle(PrimaryActionButtonStyle())

                Button {
                    Task { await appState.rejectFriendRequest(request) }
                } label: {
                    Label("拒否", systemImage: "xmark")
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
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

private struct OutgoingRequestRow: View {
    let request: FriendRequest

    var body: some View {
        HStack(spacing: 12) {
            RequestProfile(name: request.toName, avatar: request.toAvatar, avatarURL: request.toAvatarURL)
            Spacer()
            Text("承認待ち")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.secondaryText)
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

private struct FriendRow: View {
    let friend: AppFriend

    var body: some View {
        HStack(spacing: 12) {
            PublicUserAvatar(user: AppUser(id: friend.friendId, displayName: friend.friendName, avatar: friend.friendAvatar, avatarURL: friend.friendAvatarURL), size: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(friend.friendName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.mainText)
                Text("friend")
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

private struct RequestProfile: View {
    let name: String
    let avatar: String
    let avatarURL: String?

    var body: some View {
        HStack(spacing: 12) {
            PublicUserAvatar(user: AppUser(id: "", displayName: name, avatar: avatar, avatarURL: avatarURL), size: 44)
            Text(name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.mainText)
        }
    }
}

private struct PublicUserAvatar: View {
    let user: AppUser
    let size: CGFloat

    var body: some View {
        Group {
            if let avatarURL = user.avatarURL, !avatarURL.isEmpty {
                RemoteImageView(urlString: avatarURL) {
                    placeholder
                }
            } else if user.avatar.isEmpty {
                placeholder
            } else {
                Text(user.avatar)
                    .font(.system(size: size * 0.48))
            }
        }
        .frame(width: size, height: size)
        .background(AppColors.chromeHighlight.opacity(0.78))
        .clipShape(Circle())
        .overlay { Circle().stroke(AppColors.border, lineWidth: 0.8) }
    }

    private var placeholder: some View {
        Image(systemName: "person.fill")
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(AppColors.mainText.opacity(0.72))
    }
}
