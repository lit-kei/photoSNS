//
//  AppState.swift
//  petanko
//

import Combine
import FirebaseFirestore
import Foundation
import UserNotifications

@MainActor
final class AppState: ObservableObject {
    @Published var currentUser: AppUser?
    @Published var groups: [PetankoGroup] = []
    @Published var friends: [AppFriend] = []
    @Published var friendTodayStickers: [StickerPost] = []
    @Published private(set) var observedUserProfiles: [String: AppUser] = [:]
    @Published var incomingFriendRequests: [FriendRequest] = []
    @Published var outgoingFriendRequests: [FriendRequest] = []
    @Published private(set) var unreadPostCounts: [String: Int] = [:]
    @Published var selectedTab: AppTab = .home
    @Published var authState: AuthState = .bootstrapping
    @Published var errorMessage: String?
    @Published var isAuthenticating = false
    @Published var isShowingNotifications = false

    private let services: AppServices
    let networkMonitor: NetworkMonitor
    let stickerUploadCoordinator: StickerUploadCoordinator
    private var groupListener: ListenerRegistration?
    private var groupReadStateListener: ListenerRegistration?
    private var unreadStickerListeners: [String: ListenerRegistration] = [:]
    private var unreadObservationCutoffs: [String: Date] = [:]
    private var groupLastReadDates: [String: Date] = [:]
    private var initializingReadStateGroupIds: Set<String> = []
    private var friendListener: ListenerRegistration?
    private var friendTodayStickerListeners: [ListenerRegistration] = []
    private var userProfileListeners: [String: ListenerRegistration] = [:]
    private var incomingFriendRequestListener: ListenerRegistration?
    private var outgoingFriendRequestListener: ListenerRegistration?
    private var pendingAccount: AuthenticatedAccount?
    private var pendingTermsAcceptedAt: Date?
    private var hasLoadedIncomingFriendRequests = false
    private var knownIncomingFriendRequestIds: Set<String> = []

    init() {
        let services = AppServices.shared
        let networkMonitor = NetworkMonitor()
        self.services = services
        self.networkMonitor = networkMonitor
        self.stickerUploadCoordinator = StickerUploadCoordinator(
            services: services,
            networkMonitor: networkMonitor
        )
    }

    init(services: AppServices) {
        let networkMonitor = NetworkMonitor()
        self.services = services
        self.networkMonitor = networkMonitor
        self.stickerUploadCoordinator = StickerUploadCoordinator(
            services: services,
            networkMonitor: networkMonitor
        )
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
        pendingTermsAcceptedAt = nil
        await authenticate {
            try await services.auth.signIn(email: email, password: password)
        }
    }

    func createAccount(email: String, password: String, termsAcceptedAt: Date) async {
        pendingTermsAcceptedAt = termsAcceptedAt
        await authenticate {
            try await services.auth.createAccount(email: email, password: password)
        }
    }

    func completeProfile(displayName: String, avatar: String) async {
        guard let pendingAccount else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let user = try await services.auth.createProfile(account: pendingAccount, displayName: displayName, avatar: avatar, termsAcceptedAt: pendingTermsAcceptedAt)
            self.pendingAccount = nil
            pendingTermsAcceptedAt = nil
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

    func findGroup(inviteCode: String) async -> PetankoGroup? {
        do {
            return try await services.groups.findGroup(inviteCode: inviteCode)
        } catch {
            guard !error.isPetankoOfflineFirestoreError else { return nil }
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func updateGroup(group: PetankoGroup, name: String, icon: String, iconImageData: Data? = nil) async {
        do {
            try await services.groups.updateGroup(group: group, name: name, icon: icon, iconImageData: iconImageData)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func leaveGroup(_ group: PetankoGroup) async {
        guard let currentUser else { return }
        do {
            try await services.groups.leaveGroup(group, currentUser: currentUser)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func findUser(email: String) async -> AppUser? {
        do {
            return try await services.friends.findUser(email: email)
        } catch {
            guard !error.isPetankoOfflineFirestoreError else { return nil }
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func findUser(playerId: String) async -> AppUser? {
        do {
            return try await services.friends.findUser(playerId: playerId)
        } catch {
            guard !error.isPetankoOfflineFirestoreError else { return nil }
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func fetchUser(userId: String) async -> AppUser? {
        do {
            return try await services.friends.fetchUser(userId: userId)
        } catch {
            guard !error.isPetankoOfflineFirestoreError else { return nil }
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

    func removeFriend(_ friend: AppFriend) async {
        guard let currentUser else { return }
        do {
            try await services.friends.removeFriend(friend, currentUser: currentUser)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reportSticker(_ sticker: StickerPost) async -> Bool {
        guard let currentUser else { return false }
        do {
            try await services.stickers.reportSticker(sticker, user: currentUser)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func openNotifications() {
        selectedTab = .home
        isShowingNotifications = true
    }

    func markGroupAsRead(_ groupId: String) {
        guard let userId = currentUser?.id,
              groups.contains(where: { $0.id == groupId }) else { return }

        let previousReadDate = groupLastReadDates[groupId]
        let readDate = Date()
        groupLastReadDates[groupId] = readDate
        unreadPostCounts[groupId] = 0
        reconcileUnreadObservations(for: userId)

        Task {
            do {
                try await services.groups.markGroupAsRead(groupId: groupId, userId: userId, at: readDate)
            } catch {
                guard groupLastReadDates[groupId] == readDate else { return }
                if let previousReadDate {
                    groupLastReadDates[groupId] = previousReadDate
                } else {
                    groupLastReadDates.removeValue(forKey: groupId)
                }
                reconcileUnreadObservations(for: userId)
                guard !error.isPetankoOfflineFirestoreError else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    func updateProfile(displayName: String, avatarImageData: Data? = nil) async {
        guard var user = currentUser else { return }
        user.displayName = displayName.trimmedForPetanko
        let previousAvatarURL = user.avatarURL
        var uploadedAvatarURL: URL?
        var didPersistProfile = false
        do {
            if let avatarImageData {
                let imageURL = try await services.auth.uploadProfileImage(userId: user.id, imageData: avatarImageData)
                uploadedAvatarURL = imageURL
                user.avatarURL = imageURL.absoluteString
            }
            try await services.auth.updateProfile(user: user)
            didPersistProfile = true
            currentUser = user
            observedUserProfiles[user.id] = user
            reconcileObservedUserProfiles()
            try await services.groups.syncMemberProfile(user)
            if let previousAvatarURL,
               previousAvatarURL != uploadedAvatarURL?.absoluteString,
               uploadedAvatarURL != nil {
                await services.auth.deleteProfileImage(at: previousAvatarURL)
            }
        } catch {
            if let uploadedAvatarURL, !didPersistProfile {
                await services.auth.deleteProfileImage(at: uploadedAvatarURL.absoluteString)
            }
            errorMessage = error.localizedDescription
        }
    }

    private func observeGroups(for userId: String) {
        groupListener?.remove()
        groupListener = services.groups.observeMyGroups(userId: userId) { [weak self] groups, error in
            Task { @MainActor in
                if let error {
                    guard !error.isPetankoOfflineFirestoreError else { return }
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.groups = groups
                    self?.reconcileUnreadObservations(for: userId)
                }
            }
        }
    }

    private func observeGroupReadStates(for userId: String) {
        groupReadStateListener?.remove()
        groupReadStateListener = services.groups.observeMyGroupReadStates(userId: userId) { [weak self] states, error in
            Task { @MainActor in
                guard let self, self.currentUser?.id == userId else { return }
                if let error {
                    guard !error.isPetankoOfflineFirestoreError else { return }
                    self.errorMessage = error.localizedDescription
                    return
                }

                for (groupId, serverReadDate) in states {
                    if let localReadDate = self.groupLastReadDates[groupId],
                       localReadDate >= serverReadDate {
                        continue
                    }
                    self.groupLastReadDates[groupId] = serverReadDate
                }
                self.initializingReadStateGroupIds.subtract(states.keys)
                self.reconcileUnreadObservations(for: userId)
            }
        }
    }

    private func reconcileUnreadObservations(for userId: String) {
        guard currentUser?.id == userId else { return }
        let activeGroupIds = Set(groups.map(\.id))
        let trackedGroupIds = Set(unreadStickerListeners.keys)
            .union(unreadPostCounts.keys)
            .union(unreadObservationCutoffs.keys)
            .union(initializingReadStateGroupIds)

        for groupId in trackedGroupIds.subtracting(activeGroupIds) {
            unreadStickerListeners.removeValue(forKey: groupId)?.remove()
            unreadObservationCutoffs.removeValue(forKey: groupId)
            unreadPostCounts.removeValue(forKey: groupId)
            groupLastReadDates.removeValue(forKey: groupId)
            initializingReadStateGroupIds.remove(groupId)
        }

        for groupId in activeGroupIds {
            guard let lastReadAt = groupLastReadDates[groupId] else {
                unreadPostCounts[groupId] = 0
                initializeReadStateIfNeeded(groupId: groupId, userId: userId)
                continue
            }
            guard unreadObservationCutoffs[groupId] != lastReadAt else { continue }

            unreadStickerListeners.removeValue(forKey: groupId)?.remove()
            unreadObservationCutoffs[groupId] = lastReadAt
            unreadPostCounts[groupId] = 0
            unreadStickerListeners[groupId] = services.stickers.observeUnreadStickerCount(
                groupId: groupId,
                userId: userId,
                createdAfter: lastReadAt
            ) { [weak self] count, error in
                Task { @MainActor in
                    guard let self,
                          self.unreadObservationCutoffs[groupId] == lastReadAt else { return }
                    if let error {
                        guard !error.isPetankoOfflineFirestoreError else { return }
                        self.errorMessage = error.localizedDescription
                    } else {
                        self.unreadPostCounts[groupId] = count
                    }
                }
            }
        }
    }

    private func initializeReadStateIfNeeded(groupId: String, userId: String) {
        guard initializingReadStateGroupIds.insert(groupId).inserted else { return }
        Task {
            do {
                try await services.groups.initializeGroupReadState(groupId: groupId, userId: userId)
            } catch {
                initializingReadStateGroupIds.remove(groupId)
                guard !error.isPetankoOfflineFirestoreError else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    private func observeFriends(for userId: String) {
        friendListener?.remove()
        friendListener = services.friends.observeFriends(userId: userId) { [weak self] friends, error in
            Task { @MainActor in
                if let error {
                    guard !error.isPetankoOfflineFirestoreError else { return }
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.friends = friends
                    self?.observeTodayBlogStickers(for: friends)
                    self?.reconcileObservedUserProfiles()
                }
            }
        }
    }

    private func observeTodayBlogStickers(for friends: [AppFriend]) {
        removeFriendTodayStickerListeners()
        guard let currentUser else {
            friendTodayStickers = []
            return
        }
        let authorIds = friends.map(\.friendId) + [currentUser.id]

        friendTodayStickerListeners = services.stickers.observeTodayBlogStickers(authorIds: authorIds) { [weak self] stickers, error in
            Task { @MainActor in
                if let error {
                    guard !error.isPetankoOfflineFirestoreError else { return }
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.friendTodayStickers = stickers
                    self?.reconcileObservedUserProfiles()
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
                    guard !error.isPetankoOfflineFirestoreError else { return }
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.applyIncomingFriendRequests(requests)
                }
            }
        }

        outgoingFriendRequestListener = services.friends.observeOutgoingRequests(userId: userId) { [weak self] requests, error in
            Task { @MainActor in
                if let error {
                    guard !error.isPetankoOfflineFirestoreError else { return }
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.outgoingFriendRequests = requests
                }
            }
        }
    }

    private func observeSignedInData(for userId: String) {
        observeGroups(for: userId)
        observeGroupReadStates(for: userId)
        observeFriends(for: userId)
        observeFriendRequests(for: userId)
        reconcileObservedUserProfiles()
        if let currentUser, currentUser.id == userId {
            Task {
                do {
                    try await services.groups.syncMemberProfile(currentUser)
                } catch {
                    guard !error.isPetankoOfflineFirestoreError else { return }
                    errorMessage = error.localizedDescription
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
                pendingTermsAcceptedAt = nil
                currentUser = user
                authState = .signedIn
                observeSignedInData(for: user.id)
            } else {
                clearSignedInState()
                pendingAccount = account
                authState = .needsProfile(email: account.email)
            }
        } catch {
            guard error.isPetankoOfflineFirestoreError else { throw error }
            let fallbackUser = AppUser(
                id: account.uid,
                email: account.email,
                displayName: account.email.petankoFallbackDisplayName,
                avatar: ""
            )
            pendingAccount = nil
            pendingTermsAcceptedAt = nil
            currentUser = fallbackUser
            authState = .signedIn
            observeSignedInData(for: fallbackUser.id)
        }
    }

    private func clearSignedInState() {
        stickerUploadCoordinator.cancelAndClear()
        pendingTermsAcceptedAt = nil
        groupListener?.remove()
        groupListener = nil
        groupReadStateListener?.remove()
        groupReadStateListener = nil
        unreadStickerListeners.values.forEach { $0.remove() }
        unreadStickerListeners = [:]
        unreadObservationCutoffs = [:]
        groupLastReadDates = [:]
        initializingReadStateGroupIds = []
        friendListener?.remove()
        friendListener = nil
        removeFriendTodayStickerListeners()
        removeUserProfileListeners()
        incomingFriendRequestListener?.remove()
        incomingFriendRequestListener = nil
        outgoingFriendRequestListener?.remove()
        outgoingFriendRequestListener = nil
        currentUser = nil
        observedUserProfiles = [:]
        groups = []
        friends = []
        friendTodayStickers = []
        incomingFriendRequests = []
        outgoingFriendRequests = []
        unreadPostCounts = [:]
        isShowingNotifications = false
        hasLoadedIncomingFriendRequests = false
        knownIncomingFriendRequestIds = []
        pendingAccount = nil
    }

    private func removeFriendTodayStickerListeners() {
        friendTodayStickerListeners.forEach { $0.remove() }
        friendTodayStickerListeners = []
    }

    private func reconcileObservedUserProfiles() {
        var activeUserIds = Set<String>()
        if let currentUser {
            activeUserIds.insert(currentUser.id)
            observedUserProfiles[currentUser.id] = currentUser
        }
        activeUserIds.formUnion(friends.map(\.friendId).filter { !$0.isEmpty })
        activeUserIds.formUnion(friendTodayStickers.map(\.authorId).filter { !$0.isEmpty })

        for userId in Set(userProfileListeners.keys).subtracting(activeUserIds) {
            userProfileListeners.removeValue(forKey: userId)?.remove()
            observedUserProfiles.removeValue(forKey: userId)
        }

        for userId in activeUserIds where userProfileListeners[userId] == nil {
            userProfileListeners[userId] = services.friends.observeUserProfile(userId: userId) { [weak self] profile, error in
                Task { @MainActor in
                    guard let self,
                          self.userProfileListeners[userId] != nil else { return }
                    if let error {
                        guard !error.isPetankoOfflineFirestoreError else { return }
                        self.errorMessage = error.localizedDescription
                    } else if let profile {
                        self.observedUserProfiles[userId] = profile
                        if self.currentUser?.id == userId {
                            self.currentUser = profile
                        }
                    }
                }
            }
        }
    }

    private func removeUserProfileListeners() {
        userProfileListeners.values.forEach { $0.remove() }
        userProfileListeners = [:]
    }

    private func applyIncomingFriendRequests(_ requests: [FriendRequest]) {
        let incomingIds = Set(requests.map(\.id))
        let newRequests = requests.filter { !knownIncomingFriendRequestIds.contains($0.id) }
        incomingFriendRequests = requests

        if hasLoadedIncomingFriendRequests {
            for request in newRequests {
                sendFriendRequestNotification(request)
            }
        }

        hasLoadedIncomingFriendRequests = true
        knownIncomingFriendRequestIds = incomingIds
    }

    private func sendFriendRequestNotification(_ request: FriendRequest) {
        Task {
            let content = UNMutableNotificationContent()
            content.title = "友達申請が届きました"
            content.body = "\(request.fromName)さんから友達申請が届いています。"
            content.sound = .default
            content.userInfo = ["petankoDestination": "notifications"]
            let notificationRequest = UNNotificationRequest(
                identifier: "friend-request-\(request.id)",
                content: content,
                trigger: nil
            )
            try? await UNUserNotificationCenter.current().add(notificationRequest)
        }
    }
}

enum AuthState: Hashable {
    case bootstrapping
    case signedOut
    case needsProfile(email: String)
    case signedIn
}

enum AppTab {
    case home
    case camera
    case friends
    case memories
    case profile
}
