import CryptoKit
import FirebaseFirestore
import FirebaseMessaging
import Foundation
import UIKit
import UserNotifications

@MainActor
final class PushNotificationService: NSObject, MessagingDelegate {
    static let shared = PushNotificationService()

    private let db = Firestore.firestore()
    private var currentUserId: String?
    private var currentToken: String?

    private override init() {
        super.init()
    }

    func configureMessagingDelegate() {
        Messaging.messaging().delegate = self
    }

    func activate(for userId: String) {
        currentUserId = userId
        Task {
            await requestAuthorizationAndRegister()
            guard currentUserId == userId else { return }
            if let token = Messaging.messaging().fcmToken {
                currentToken = token
                await saveToken(token, for: userId)
            } else if let token = await fetchMessagingToken() {
                guard currentUserId == userId else { return }
                currentToken = token
                await saveToken(token, for: userId)
            }
        }
    }

    func deactivate() async {
        let tokenToDelete = currentToken ?? Messaging.messaging().fcmToken
        let userId = currentUserId
        currentUserId = nil
        currentToken = nil

        if let userId, let tokenToDelete {
            try? await tokenDocument(userId: userId, token: tokenToDelete).delete()
        }
        await deleteMessagingToken()
    }

    func requestAuthorizationAndRegister() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
        let updatedSettings = await center.notificationSettings()
        guard updatedSettings.authorizationStatus == .authorized ||
              updatedSettings.authorizationStatus == .provisional ||
              updatedSettings.authorizationStatus == .ephemeral else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task { @MainActor in
            self.currentToken = fcmToken
            if let currentUserId = self.currentUserId {
                await self.saveToken(fcmToken, for: currentUserId)
            }
        }
    }

    private func saveToken(_ token: String, for userId: String) async {
        let document = tokenDocument(userId: userId, token: token)
        try? await document.setData(
            [
                "token": token,
                "platform": "ios",
                "updatedAt": FieldValue.serverTimestamp()
            ],
            merge: true
        )
    }

    private func tokenDocument(userId: String, token: String) -> DocumentReference {
        db.collection("users")
            .document(userId)
            .collection("fcmTokens")
            .document(Self.tokenDocumentId(for: token))
    }

    private static func tokenDocumentId(for token: String) -> String {
        let digest = SHA256.hash(data: Data(token.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func deleteMessagingToken() async {
        await withCheckedContinuation { continuation in
            Messaging.messaging().deleteToken { _ in
                continuation.resume()
            }
        }
    }

    private func fetchMessagingToken() async -> String? {
        await withCheckedContinuation { continuation in
            Messaging.messaging().token { token, _ in
                continuation.resume(returning: token)
            }
        }
    }
}
