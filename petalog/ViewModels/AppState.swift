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
    @Published var friends: [AppFriend] = []
    @Published var incomingFriendRequests: [FriendRequest] = []
    @Published var outgoingFriendRequests: [FriendRequest] = []
    @Published var selectedTab: AppTab = .home
    @Published var authState: AuthState = .bootstrapping
    @Published var errorMessage: String?
    @Published var isAuthenticating = false

    private let services: AppServices
    private var groupListener: ListenerRegistration?
    private var friendListener: ListenerRegistration?
    private var incomingFriendRequestListener: ListenerRegistration?
    private var outgoingFriendRequestListener: ListenerRegistration?
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
            observeSignedInData(for: user.id)
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

    func createGroup(name: String, icon: String, iconImageData: Data? = nil) async {
        guard let currentUser else { return }
        do {
            _ = try await services.groups.createGroup(name: name, icon: icon, iconImageData: iconImageData, currentUser: currentUser)
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

    func findGroup(inviteCode: String) async -> PetalogGroup? {
        do {
            return try await services.groups.findGroup(inviteCode: inviteCode)
        } catch {
            guard !error.isPetalogOfflineFirestoreError else { return nil }
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func updateGroup(group: PetalogGroup, name: String, icon: String, iconImageData: Data? = nil) async {
        do {
            try await services.groups.updateGroup(group: group, name: name, icon: icon, iconImageData: iconImageData)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func findUser(email: String) async -> AppUser? {
        do {
            return try await services.friends.findUser(email: email)
        } catch {
            guard !error.isPetalogOfflineFirestoreError else { return nil }
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func fetchUser(userId: String) async -> AppUser? {
        do {
            return try await services.friends.fetchUser(userId: userId)
        } catch {
            guard !error.isPetalogOfflineFirestoreError else { return nil }
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func sendFriendRequest(to targetUser: AppUser) async -> Bool {
        guard let currentUser else { return false }
        do {
            try await services.friends.sendRequest(to: targetUser, currentUser: currentUser)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func acceptFriendRequest(_ request: FriendRequest) async {
        guard let currentUser else { return }
        do {
            try await services.friends.acceptRequest(request, currentUser: currentUser)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rejectFriendRequest(_ request: FriendRequest) async {
        guard let currentUser else { return }
        do {
            try await services.friends.rejectRequest(request, currentUser: currentUser)
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

    private func observeFriends(for userId: String) {
        friendListener?.remove()
        friendListener = services.friends.observeFriends(userId: userId) { [weak self] friends, error in
            Task { @MainActor in
                if let error {
                    guard !error.isPetalogOfflineFirestoreError else { return }
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.friends = friends
                }
            }
        }
    }

    private func observeFriendRequests(for userId: String) {
        incomingFriendRequestListener?.remove()
        outgoingFriendRequestListener?.remove()

        incomingFriendRequestListener = services.friends.observeIncomingRequests(userId: userId) { [weak self] requests, error in
            Task { @MainActor in
                if let error {
                    guard !error.isPetalogOfflineFirestoreError else { return }
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.incomingFriendRequests = requests
                }
            }
        }

        outgoingFriendRequestListener = services.friends.observeOutgoingRequests(userId: userId) { [weak self] requests, error in
            Task { @MainActor in
                if let error {
                    guard !error.isPetalogOfflineFirestoreError else { return }
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.outgoingFriendRequests = requests
                }
            }
        }
    }

    private func observeSignedInData(for userId: String) {
        observeGroups(for: userId)
        observeFriends(for: userId)
        observeFriendRequests(for: userId)
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
                observeSignedInData(for: user.id)
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
            observeSignedInData(for: fallbackUser.id)
        }
    }

    private func clearSignedInState() {
        groupListener?.remove()
        groupListener = nil
        friendListener?.remove()
        friendListener = nil
        incomingFriendRequestListener?.remove()
        incomingFriendRequestListener = nil
        outgoingFriendRequestListener?.remove()
        outgoingFriendRequestListener = nil
        currentUser = nil
        groups = []
        friends = []
        incomingFriendRequests = []
        outgoingFriendRequests = []
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
