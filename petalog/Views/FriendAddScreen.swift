import AVFoundation
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct FriendAddScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var email = ""
    @State private var selectedProfile: AppUser?
    @State private var isSearching = false
    @State private var isShowingScanner = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                searchCard
                qrCard
                requestSections
                friendsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 34)
        }
        .background {
            PetalogMetalBackground()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedProfile) { user in
            FriendProfileScreen(user: user)
        }
        .sheet(isPresented: $isShowingScanner) {
            QRScannerSheet { userId in
                isShowingScanner = false
                Task { await loadQRUser(userId: userId) }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("友達追加")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(AppColors.mainText)
            Text("プロフィールを確認してからフレンド申請を送れます。")
                .font(.system(size: 14))
                .foregroundStyle(AppColors.secondaryText)
                .lineSpacing(3)
        }
    }

    private var searchCard: some View {
        MetalCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Label("メールアドレスで探す", systemImage: "envelope")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.secondaryText)

                TextField("friend@example.com", text: $email)
                    .keyboardType(.emailAddress)
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
                .disabled(email.trimmedForPetalog.isEmpty || isSearching)
                .opacity(email.trimmedForPetalog.isEmpty ? 0.48 : 1)

            }
        }
    }

    private var qrCard: some View {
        ControlSection(title: "QRコード") {
            VStack(spacing: 12) {
                if let currentUser = appState.currentUser {
                    QRCodeView(payload: currentUser.id)
                        .frame(width: 168, height: 168)
                        .frame(maxWidth: .infinity)
                        .padding(18)
                        .background(AppColors.surface.opacity(0.94))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                                .stroke(AppColors.border, lineWidth: 0.8)
                        }
                }

                Button {
                    isShowingScanner = true
                } label: {
                    Label("QRコードを読み取る", systemImage: "qrcode.viewfinder")
                }
                .buttonStyle(SecondaryActionButtonStyle())

            }
        }
    }

    private var requestSections: some View {
        VStack(spacing: 18) {
            ControlSection(title: "届いた申請") {
                if appState.incomingFriendRequests.isEmpty {
                    EmptyStateView(systemImage: "tray", title: "申請はありません", message: "友達から申請が届くとここに表示されます。")
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
                    EmptyStateView(systemImage: "paperplane", title: "送信中の申請はありません", message: "申請を送ると承認待ちとして表示されます。")
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
                EmptyStateView(systemImage: "person.2", title: "まだ友達がいません", message: "承認された友達がここに表示されます。")
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
                    }
                }
            }
        }
    }

    private func searchUser() async {
        isSearching = true
        let user = await appState.findUser(email: email)
        isSearching = false
        if let user {
            selectedProfile = user
        } else if appState.errorMessage == nil {
            appState.errorMessage = "このメールアドレスのユーザーが見つかりません。"
        }
    }

    private func loadQRUser(userId: String) async {
        let user = await appState.fetchUser(userId: userId)
        if let user {
            selectedProfile = user
        } else if appState.errorMessage == nil {
            appState.errorMessage = "QRコードのユーザーが見つかりません。"
        }
    }
}

private struct FriendProfileScreen: View {
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
        didSend || appState.outgoingFriendRequests.contains {
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

                    if !user.email.isEmpty {
                        Text(user.email)
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.secondaryText)
                    }
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
            if let avatarURL = user.avatarURL, let url = URL(string: avatarURL), !avatarURL.isEmpty {
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

private struct QRCodeView: View {
    let payload: String
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        if let image = makeImage() {
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
        } else {
            Image(systemName: "qrcode")
                .font(.system(size: 80))
                .foregroundStyle(AppColors.mainText)
        }
    }

    private func makeImage() -> UIImage? {
        filter.message = Data(payload.utf8)
        guard let outputImage = filter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

private struct QRScannerSheet: View {
    let onScan: (String) -> Void

    var body: some View {
        NavigationStack {
            QRScannerView(onScan: onScan)
                .ignoresSafeArea()
                .navigationTitle("QRコードを読み取る")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct QRScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onScan = onScan
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

private final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    private let session = AVCaptureSession()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configure()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }

    private func configure() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        (view.layer.sublayers?.first as? AVCaptureVideoPreviewLayer)?.frame = view.bounds
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }
        session.stopRunning()
        onScan?(value)
    }
}
