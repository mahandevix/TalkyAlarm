import SwiftUI
@preconcurrency import UserNotifications

@main
struct TalkyAlarmApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = AlarmListViewModel()
    private let runtimeCoordinator: NotificationRuntimeCoordinator

    init() {
        let coordinator = NotificationRuntimeCoordinator()
        coordinator.start()
        runtimeCoordinator = coordinator
    }

    var body: some Scene {
        WindowGroup {
            AlarmListView(viewModel: viewModel)
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active, .background:
                        viewModel.refreshSchedulesForLifecycle()
                        runtimeCoordinator.refreshSchedulesFromStore()
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
        }
    }
}

@MainActor
private let sharedAlarmPlaybackService = AlarmPlaybackService()

private final class NotificationRuntimeCoordinator: NSObject, UNUserNotificationCenterDelegate {
    private let center: UNUserNotificationCenter
    private let alarmStore: AlarmStore
    private let notificationScheduler: NotificationScheduler

    init(
        center: UNUserNotificationCenter = .current(),
        alarmStore: AlarmStore = AlarmStore(),
        notificationScheduler: NotificationScheduler = NotificationScheduler()
    ) {
        self.center = center
        self.alarmStore = alarmStore
        self.notificationScheduler = notificationScheduler
    }

    func start() {
        center.delegate = self
        notificationScheduler.requestAuthorizationIfNeeded()
        refreshSchedulesFromStore()
    }

    func refreshSchedulesFromStore() {
        let alarms = alarmStore.load()
        notificationScheduler.rescheduleAlarms(alarms, recordingsDirectory: Self.recordingsDirectory)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        handle(notification: notification)
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handle(notification: response.notification)
        completionHandler()
    }

    private func handle(notification: UNNotification) {
        guard let alarm = alarmForNotificationUserInfo(notification.request.content.userInfo) else {
            return
        }

        Task { @MainActor in
            sharedAlarmPlaybackService.play(alarm: alarm, recordingsDirectory: Self.recordingsDirectory)
        }

        if case .everyXHours = alarm.repeatRule {
            refreshSchedulesFromStore()
        } else if case .everyXDays = alarm.repeatRule {
            refreshSchedulesFromStore()
        }
    }

    private func alarmForNotificationUserInfo(_ userInfo: [AnyHashable: Any]) -> Alarm? {
        guard let rawAlarmID = userInfo["alarmId"] as? String,
              let alarmID = UUID(uuidString: rawAlarmID) else {
            return nil
        }

        let alarms = alarmStore.load()
        return alarms.first(where: { $0.id == alarmID && $0.isEnabled })
    }

    private static var recordingsDirectory: URL {
        let fileManager = FileManager.default
        let libraryDirectory = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let directory = libraryDirectory.appendingPathComponent("Sounds", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
