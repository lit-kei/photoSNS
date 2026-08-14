import Combine
import FirebaseFirestore
import Foundation

@MainActor
final class DiaryViewModel: ObservableObject {
    @Published var diary: DiaryPage?
    @Published var stickers: [StickerPost] = []
    @Published var isLoading = true
    @Published var isEditingLocked = false
    @Published var errorMessage: String?

    private let services: AppServices
    private let group: PetalogGroup
    private let dateKey: String
    private var diaryListener: ListenerRegistration?
    private var stickerListener: ListenerRegistration?

    init(group: PetalogGroup) {
        self.group = group
        self.dateKey = Date().petalogDateKey
        self.services = AppServices.shared
    }

    init(group: PetalogGroup, dateKey: String, services: AppServices) {
        self.group = group
        self.dateKey = dateKey
        self.services = services
    }

    func start() {
        Task {
            do {
                _ = try await services.diaries.ensureTodayDiary(group: group, dateKey: dateKey)
                observe()
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func stop() {
        diaryListener?.remove()
        stickerListener?.remove()
    }

    func acquireEditLock(user: AppUser) async -> Bool {
        guard let diary else { return false }
        do {
            let acquired = try await services.diaries.acquireEditLock(groupId: group.id, diaryId: diary.id, user: user)
            isEditingLocked = !acquired
            return acquired
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func releaseEditLock(user: AppUser) async {
        guard let diary else { return }
        try? await services.diaries.releaseEditLock(diaryId: diary.id, userId: user.id)
    }

    func saveDiary(_ diary: DiaryPage) async {
        do {
            try await services.diaries.saveDiaryLayout(diary)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func observe() {
        diaryListener = services.diaries.observeDiary(groupId: group.id, dateKey: dateKey) { [weak self] diary, error in
            Task { @MainActor in
                if let error {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.diary = diary
                }
                self?.isLoading = false
            }
        }

        stickerListener = services.stickers.observeStickers(groupId: group.id, dateKey: dateKey) { [weak self] stickers, error in
            Task { @MainActor in
                if let error {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.stickers = stickers
                }
            }
        }
    }
}
