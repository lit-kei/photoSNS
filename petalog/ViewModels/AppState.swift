//
//  AppState.swift
//  petalog
//

import Combine
import FirebaseFirestore
import Foundation

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

    func updateProfile(displayName: String, avatarImageData: Data? = nil) async {
        guard var user = currentUser else { return }
        user.displayName = displayName.trimmedForPetalog
        do {
            if let avatarImageData {
                let imageURL = try await services.auth.uploadProfileImage(userId: user.id, imageData: avatarImageData)
                user.avatarURL = imageURL.absoluteString
            }
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
                avatar: ""
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
