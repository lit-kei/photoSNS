import Combine
import SwiftUI
import UIKit

enum BackgroundStickerUploadState: Equatable {
    case idle
    case uploading(Double)
    case resolvingURL
    case savingPost
    case success
    case failure(String)

    var isRunning: Bool {
        switch self {
        case .uploading, .resolvingURL, .savingPost:
            true
        default:
            false
        }
    }
}

private struct PendingStickerUpload {
    let stickerPNG: Data
    let originalStickerPNG: Data?
    let draft: StickerDraft
    let groups: [PetankoGroup]
    let publishToBlog: Bool
    let user: AppUser
}

@MainActor
final class StickerUploadCoordinator: ObservableObject {
    @Published private(set) var state: BackgroundStickerUploadState = .idle

    private let services: AppServices
    let networkMonitor: NetworkMonitor
    private var uploadTask: Task<Void, Never>?
    private var dismissTask: Task<Void, Never>?
    private var failedUpload: PendingStickerUpload?
    private var backgroundTask = UIBackgroundTaskIdentifier.invalid

    init(services: AppServices, networkMonitor: NetworkMonitor) {
        self.services = services
        self.networkMonitor = networkMonitor
    }

    func submit(
        stickerPNG: Data,
        originalStickerPNG: Data? = nil,
        draft: StickerDraft,
        groups: [PetankoGroup],
        publishToBlog: Bool,
        user: AppUser
    ) -> String? {
        guard networkMonitor.status == .online else {
            return networkMonitor.status == .checking
                ? "通信状態を確認しています。少し待ってからもう一度お試しください。"
                : "インターネットに接続されていません。接続後に投稿してください。"
        }
        guard !state.isRunning else {
            return "別の投稿を保存しています。完了してからもう一度お試しください。"
        }
        guard publishToBlog || !groups.isEmpty else { return "ブログまたは投稿先のグループを選択してください。" }

        let upload = PendingStickerUpload(
            stickerPNG: stickerPNG,
            originalStickerPNG: originalStickerPNG,
            draft: draft,
            groups: groups,
            publishToBlog: publishToBlog,
            user: user
        )
        failedUpload = nil
        start(upload)
        return nil
    }

    func retry() {
        guard let failedUpload, networkMonitor.status == .online, !state.isRunning else { return }
        self.failedUpload = nil
        start(failedUpload)
    }

    func dismissBanner() {
        guard !state.isRunning else { return }
        let wasFailure: Bool
        if case .failure = state { wasFailure = true } else { wasFailure = false }
        dismissTask?.cancel()
        state = .idle
        if wasFailure { failedUpload = nil }
    }

    func setAppActive(_ isActive: Bool) {
        _ = isActive
    }

    func cancelAndClear() {
        uploadTask?.cancel()
        uploadTask = nil
        dismissTask?.cancel()
        dismissTask = nil
        failedUpload = nil
        state = .idle
        endBackgroundTask()
    }

    private func start(_ upload: PendingStickerUpload) {
        dismissTask?.cancel()
        state = .uploading(0)
        beginBackgroundTask()

        uploadTask = Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await services.stickers.uploadSticker(
                    stickerPNG: upload.stickerPNG,
                    originalStickerPNG: upload.originalStickerPNG,
                    draft: upload.draft,
                    groups: upload.groups,
                    publishToBlog: upload.publishToBlog,
                    user: upload.user,
                    onStageChange: { [weak self] stage in
                        Task { @MainActor in self?.apply(stage) }
                    }
                )
                guard !Task.isCancelled else { return }
                state = .success
                failedUpload = nil
                scheduleSuccessDismissal()
            } catch {
                guard !Task.isCancelled else { return }
                let message = error.localizedDescription
                failedUpload = upload
                state = .failure(message)
            }
            uploadTask = nil
            endBackgroundTask()
        }
    }

    private func apply(_ stage: StickerUploadStage) {
        switch stage {
        case .uploading(let progress):
            state = .uploading(min(max(progress, 0), 1))
        case .resolvingDownloadURL:
            state = .resolvingURL
        case .savingPost:
            state = .savingPost
        }
    }

    private func scheduleSuccessDismissal() {
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.state = .idle }
        }
    }

    private func beginBackgroundTask() {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "petanko.sticker-upload") { [weak self] in
            Task { @MainActor in self?.endBackgroundTask() }
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}
