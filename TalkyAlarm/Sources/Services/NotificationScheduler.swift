import Foundation
@preconcurrency import UserNotifications

protocol NotificationSchedulingCenter {
    func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @Sendable @escaping (Bool, Error?) -> Void)
    func getPendingNotificationRequests(completionHandler: @Sendable @escaping ([UNNotificationRequest]) -> Void)
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?)
}

extension UNUserNotificationCenter: NotificationSchedulingCenter {}

final class NotificationScheduler: @unchecked Sendable {
    private let center: NotificationSchedulingCenter
    private let calendar: Calendar
    private let now: () -> Date
    private let medicineLookaheadCount = 32

    init(
        center: NotificationSchedulingCenter = UNUserNotificationCenter.current(),
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.center = center
        self.calendar = calendar
        self.now = now
    }

    func requestAuthorizationIfNeeded() {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    func rescheduleAlarms(_ alarms: [Alarm], recordingsDirectory: URL) {
        let requestsToSchedule = alarms
            .filter(\.isEnabled)
            .flatMap { makeRequests(for: $0, recordingsDirectory: recordingsDirectory) }

        center.getPendingNotificationRequests { [self] pending in
            let alarmIdentifiers = pending
                .map(\.identifier)
                .filter { $0.hasPrefix("alarm-") }

            center.removePendingNotificationRequests(withIdentifiers: alarmIdentifiers)

            for request in requestsToSchedule {
                center.add(request) { _ in }
            }
        }
    }

    private func makeRequests(for alarm: Alarm, recordingsDirectory: URL) -> [UNNotificationRequest] {
        let content = UNMutableNotificationContent()
        content.title = alarm.title
        content.body = alarm.spokenSentence
        content.sound = sound(for: alarm, recordingsDirectory: recordingsDirectory)
        content.interruptionLevel = .timeSensitive
        content.userInfo = [
            "alarmId": alarm.id.uuidString,
            "gradualVolume": alarm.gradualVolume
        ]

        let baseID = "alarm-\(alarm.id.uuidString)"

        switch alarm.repeatRule {
        case .once:
            guard let nextDate = nextOccurrence(hour: alarm.hour, minute: alarm.minute) else { return [] }
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextDate)
            components.second = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            return [UNNotificationRequest(identifier: baseID, content: content, trigger: trigger)]

        case .daily:
            var components = DateComponents()
            components.hour = alarm.hour
            components.minute = alarm.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            return [UNNotificationRequest(identifier: baseID, content: content, trigger: trigger)]

        case .weekdays:
            return weekdayRequests(baseID: baseID, content: content, hour: alarm.hour, minute: alarm.minute, weekdays: [2, 3, 4, 5, 6])

        case .customDays(let weekdays):
            return weekdayRequests(baseID: baseID, content: content, hour: alarm.hour, minute: alarm.minute, weekdays: weekdays)

        case .everyXHours(let interval):
            let normalizedInterval = max(1, interval)
            let startDate = nextIntervalOccurrence(
                hour: alarm.hour,
                minute: alarm.minute,
                component: .hour,
                interval: normalizedInterval
            )
            return intervalRequests(
                baseID: baseID,
                content: content,
                startDate: startDate,
                component: .hour,
                interval: normalizedInterval
            )

        case .everyXDays(let interval):
            let normalizedInterval = max(1, interval)
            let startDate = nextIntervalOccurrence(
                hour: alarm.hour,
                minute: alarm.minute,
                component: .day,
                interval: normalizedInterval
            )
            return intervalRequests(
                baseID: baseID,
                content: content,
                startDate: startDate,
                component: .day,
                interval: normalizedInterval
            )
        }
    }

    private func weekdayRequests(baseID: String, content: UNMutableNotificationContent, hour: Int, minute: Int, weekdays: [Int]) -> [UNNotificationRequest] {
        weekdays.map { weekday in
            var components = DateComponents()
            components.weekday = weekday
            components.hour = hour
            components.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            return UNNotificationRequest(identifier: "\(baseID)-\(weekday)", content: content, trigger: trigger)
        }
    }

    private func intervalRequests(
        baseID: String,
        content: UNMutableNotificationContent,
        startDate: Date?,
        component: Calendar.Component,
        interval: Int
    ) -> [UNNotificationRequest] {
        guard interval > 0, var nextDate = startDate else { return [] }
        var requests: [UNNotificationRequest] = []

        for index in 0 ..< medicineLookaheadCount {
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextDate)
            components.second = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = "\(baseID)-interval-\(index)"
            requests.append(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))

            guard let following = calendar.date(byAdding: component, value: interval, to: nextDate) else {
                break
            }
            nextDate = following
        }

        return requests
    }

    private func sound(for alarm: Alarm, recordingsDirectory: URL) -> UNNotificationSound {
        guard alarm.voice == .recorded,
              let recordingFileName = alarm.recordingFileName else {
            return .default
        }

        let fileURL = recordingsDirectory.appendingPathComponent(recordingFileName).appendingPathExtension("caf")
        let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
        guard fileExists else { return .default }
        return .init(named: .init("\(recordingFileName).caf"))
    }

    private func nextOccurrence(hour: Int, minute: Int) -> Date? {
        let currentDate = now()
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: currentDate)
        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.second = 0

        guard let today = calendar.date(from: dateComponents) else { return nil }
        if today > currentDate { return today }

        return calendar.date(byAdding: .day, value: 1, to: today)
    }

    private func nextIntervalOccurrence(
        hour: Int,
        minute: Int,
        component: Calendar.Component,
        interval: Int
    ) -> Date? {
        let safeInterval = max(1, interval)
        let currentDate = now()

        var dateComponents = calendar.dateComponents([.year, .month, .day], from: currentDate)
        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.second = 0

        guard var candidate = calendar.date(from: dateComponents) else { return nil }
        if candidate > currentDate {
            return candidate
        }

        while candidate <= currentDate {
            guard let next = calendar.date(byAdding: component, value: safeInterval, to: candidate) else {
                return nil
            }
            candidate = next
        }

        return candidate
    }
}
