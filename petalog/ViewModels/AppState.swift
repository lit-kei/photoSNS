//
//  AppState.swift
//  petalog
//

import Combine
import FirebaseFirestore
import Foundation
import UIKit

@MainActor
final class AppState: ObservableObject {
    @Published var currentUser: AppUser?
    @Published var groups: [PetalogGroup] = []
    @Published var selectedTab: AppTab = .home
    @Published var isBootstrapping = true
    @Published var errorMessage: String?

    private let services: AppServices
    private var groupListener: ListenerRegistration?

    init() {
        self.services = AppServices.shared
    }

    init(services: AppServices) {
        self.services = services
    }

    func bootstrap() {
        Task {
            do {
                let user = try await services.auth.signInAnonymouslyIfNeeded()
                currentUser = user
                observeGroups(for: user.id)
                isBootstrapping = false
            } catch {
                errorMessage = error.localizedDescription
                isBootstrapping = false
            }
        }
    }

    func createGroup(name: String, icon: String) async {
        guard let currentUser else { return }
        do {
            _ = try await services.groups.createGroup(name: name, icon: icon, currentUser: currentUser)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func joinGroup(inviteCode: String) async {
        guard let currentUser else { return }
        do {
            try await services.groups.joinGroup(inviteCode: inviteCode, currentUser: currentUser)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateProfile(displayName: String, avatar: String) async {
        guard var user = currentUser else { return }
        user.displayName = displayName.trimmedForPetalog
        user.avatar = avatar
        do {
            try await services.auth.updateProfile(user: user)
            currentUser = user
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func observeGroups(for userId: String) {
        groupListener?.remove()
        groupListener = services.groups.observeMyGroups(userId: userId) { [weak self] groups, error in
            Task { @MainActor in
                if let error {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.groups = groups
                }
            }
        }
    }
}

enum AppTab {
    case home
    case camera
    case memories
    case profile
}

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

@MainActor
final class StickerPostViewModel: ObservableObject {
    @Published var isUploading = false
    @Published var errorMessage: String?

    private let services: AppServices

    init() {
        self.services = AppServices.shared
    }

    init(services: AppServices) {
        self.services = services
    }

    func upload(originalImage: UIImage, stickerPNG: Data, draft: StickerDraft, group: PetalogGroup, user: AppUser) async -> StickerPost? {
        isUploading = true
        defer { isUploading = false }

        do {
            return try await services.stickers.uploadSticker(originalImage: originalImage, stickerPNG: stickerPNG, draft: draft, group: group, user: user)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
