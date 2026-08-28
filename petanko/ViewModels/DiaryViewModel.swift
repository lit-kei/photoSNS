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
    private let group: PetankoGroup
    private(set) var dateKey: String
    private var diaryListener: ListenerRegistration?
    private var stickerListener: ListenerRegistration?
    private var observationGeneration = UUID()

    init(group: PetankoGroup) {
        self.group = group
        self.dateKey = Date().petankoDateKey
        self.services = AppServices.shared
    }

    init(group: PetankoGroup, dateKey: String, services: AppServices) {
        self.group = group
        self.dateKey = dateKey
        self.services = services
    }

    func start() {
        let requestedDateKey = dateKey
        let generation = UUID()
        observationGeneration = generation
        Task {
            do {
                _ = try await services.diaries.ensureTodayDiary(group: group, dateKey: requestedDateKey)
                guard observationGeneration == generation, dateKey == requestedDateKey else { return }
                observe(dateKey: requestedDateKey, generation: generation)
            } catch {
                guard observationGeneration == generation, dateKey == requestedDateKey else { return }
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func stop() {
        observationGeneration = UUID()
        diaryListener?.remove()
        stickerListener?.remove()
        diaryListener = nil
        stickerListener = nil
    }

    func changeDate(to dateKey: String) {
        stop()
        self.dateKey = dateKey
        diary = nil
        stickers = []
        isLoading = true
        errorMessage = nil
        start()
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

    func renewEditLock(user: AppUser) async -> Bool {
        guard let diary else { return false }
        do {
            let renewed = try await services.diaries.renewEditLock(groupId: group.id, diaryId: diary.id, user: user)
            isEditingLocked = !renewed
            return renewed
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

    func deleteSticker(_ sticker: StickerPost, user: AppUser) async {
        do {
            try await services.stickers.deleteSticker(sticker, user: user)
            stickers.removeAll { $0.id == sticker.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func observe(dateKey observedDateKey: String, generation: UUID) {
        diaryListener = services.diaries.observeDiary(groupId: group.id, dateKey: observedDateKey) { [weak self] diary, error in
            Task { @MainActor in
                guard let self,
                      self.observationGeneration == generation,
                      self.dateKey == observedDateKey else { return }
                if let error {
                    self.errorMessage = error.localizedDescription
                } else {
                    self.diary = diary
                }
                self.isLoading = false
            }
        }

        stickerListener = services.stickers.observeStickers(groupId: group.id, dateKey: observedDateKey) { [weak self] stickers, error in
            Task { @MainActor in
                guard let self,
                      self.observationGeneration == generation,
                      self.dateKey == observedDateKey else { return }
                if let error {
                    self.errorMessage = error.localizedDescription
                } else {
                    self.stickers = stickers
                }
            }
        }
    }
}
