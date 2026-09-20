import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications

extension Notification.Name {
    static let petankoOpenNotifications = Notification.Name("petankoOpenNotifications")
}

@MainActor
final class RemoteNotificationRouter {
    static let shared = RemoteNotificationRouter()

    private var pendingUserInfos: [[AnyHashable: Any]] = []

    private init() {}

    func enqueue(_ userInfo: [AnyHashable: Any]) {
        pendingUserInfos.append(userInfo)
        NotificationCenter.default.post(name: .petankoOpenNotifications, object: nil, userInfo: userInfo)
    }

    func drainPendingUserInfos() -> [[AnyHashable: Any]] {
        let userInfos = pendingUserInfos
        pendingUserInfos = []
        return userInfos
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        PushNotificationService.shared.configureMessagingDelegate()

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard userInfo["petankoDestination"] != nil else { return }
        await MainActor.run {
            RemoteNotificationRouter.shared.enqueue(userInfo)
        }
    }
}

@main
struct petankoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
