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
    @Published var authState: AuthState = .bootstrapping
    @Published var errorMessage: String?
    @Published var isAuthenticating = false

    private let services: AppServices
    private var groupListener: ListenerRegistration?
    private var pendingAccount: AuthenticatedAccount?

    init() {
        self.services = AppServices.shared
    }

    init(services: AppServices) {
        self.services = services
    }

    func bootstrap() {
        Task {
            do {
                guard let account = services.auth.currentAccount() else {
                    clearSignedInState()
                    authState = .signedOut
                    return
                }
                try await finishAuthentication(account: account)
            } catch {
                clearSignedInState()
                errorMessage = error.localizedDescription
                authState = .signedOut
            }
        }
    }

    func signIn(email: String, password: String) async {
        await authenticate {
            try await services.auth.signIn(email: email, password: password)
        }
    }

    func createAccount(email: String, password: String) async {
        await authenticate {
            try await services.auth.createAccount(email: email, password: password)
        }
    }

    func completeProfile(displayName: String, avatar: String) async {
        guard let pendingAccount else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let user = try await services.auth.createProfile(account: pendingAccount, displayName: displayName, avatar: avatar)
            self.pendingAccount = nil
            currentUser = user
            authState = .signedIn
            observeGroups(for: user.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        do {
            try services.auth.signOut()
            clearSignedInState()
            authState = .signedOut
        } catch {
            errorMessage = error.localizedDescription
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
                    guard !error.isPetalogOfflineFirestoreError else { return }
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.groups = groups
                }
            }
        }
    }

    private func authenticate(_ operation: () async throws -> AuthenticatedAccount) async {
        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let account = try await operation()
            try await finishAuthentication(account: account)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finishAuthentication(account: AuthenticatedAccount) async throws {
        do {
            if let user = try await services.auth.fetchUser(account: account) {
                pendingAccount = nil
                currentUser = user
                authState = .signedIn
                observeGroups(for: user.id)
            } else {
                clearSignedInState()
                pendingAccount = account
                authState = .needsProfile(email: account.email)
            }
        } catch {
            guard error.isPetalogOfflineFirestoreError else { throw error }
            let fallbackUser = AppUser(
                id: account.uid,
                email: account.email,
                displayName: account.email.petalogFallbackDisplayName,
                avatar: "🙂"
            )
            pendingAccount = nil
            currentUser = fallbackUser
            authState = .signedIn
            observeGroups(for: fallbackUser.id)
        }
    }

    private func clearSignedInState() {
        groupListener?.remove()
        groupListener = nil
        currentUser = nil
        groups = []
        pendingAccount = nil
    }
}

enum AuthState: Equatable {
    case bootstrapping
    case signedOut
    case needsProfile(email: String)
    case signedIn
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
