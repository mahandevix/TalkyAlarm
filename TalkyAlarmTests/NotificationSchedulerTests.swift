import Foundation
@preconcurrency import UserNotifications
import XCTest
@testable import TalkyAlarm

final class NotificationSchedulerTests: XCTestCase {
    func testRequestAuthorizationRequestsAlertBadgeAndSound() {
        let center = FakeNotificationCenter()
        let scheduler = makeScheduler(center: center)

        scheduler.requestAuthorizationIfNeeded()

        XCTAssertEqual(center.requestedOptions, [.alert, .badge, .sound])
    }

    func testRescheduleRemovesOnlyAlarmPendingIdentifiersAndSchedulesEnabledAlarms() {
        let center = FakeNotificationCenter()
        center.pendingRequests = [
            pendingRequest(id: "alarm-old-1"),
            pendingRequest(id: "not-alarm")
        ]

        let scheduler = makeScheduler(center: center)
        let enabledID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let disabledID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

        let alarms = [
            alarm(id: enabledID, hour: 7, minute: 30, repeatRule: .daily, isEnabled: true),
            alarm(id: disabledID, hour: 8, minute: 0, repeatRule: .daily, isEnabled: false)
        ]

        scheduler.rescheduleAlarms(alarms, recordingsDirectory: FileManager.default.temporaryDirectory)

        XCTAssertEqual(center.removedIdentifiersHistory.first, ["alarm-old-1"])
        XCTAssertEqual(center.addedRequests.count, 1)
        XCTAssertEqual(center.addedRequests.first?.identifier, "alarm-\(enabledID.uuidString)")
    }

    func testDailyAlarmCreatesRepeatingTriggerAtAlarmTime() {
        let center = FakeNotificationCenter()
        let scheduler = makeScheduler(center: center)
        let alarm = alarm(hour: 9, minute: 5, repeatRule: .daily)

        scheduler.rescheduleAlarms([alarm], recordingsDirectory: FileManager.default.temporaryDirectory)

        guard let request = center.addedRequests.first else {
            return XCTFail("Expected one request")
        }
        guard let trigger = request.trigger as? UNCalendarNotificationTrigger else {
            return XCTFail("Expected calendar trigger")
        }

        XCTAssertTrue(trigger.repeats)
        XCTAssertEqual(trigger.dateComponents.hour, 9)
        XCTAssertEqual(trigger.dateComponents.minute, 5)
        XCTAssertNil(trigger.dateComponents.weekday)
        XCTAssertEqual(request.content.userInfo["alarmId"] as? String, alarm.id.uuidString)
        XCTAssertEqual(request.content.userInfo["gradualVolume"] as? Bool, alarm.gradualVolume)
    }

    func testWeekdaysAlarmCreatesFiveRequestsForMondayToFriday() {
        let center = FakeNotificationCenter()
        let scheduler = makeScheduler(center: center)
        let alarm = alarm(hour: 7, minute: 0, repeatRule: .weekdays)

        scheduler.rescheduleAlarms([alarm], recordingsDirectory: FileManager.default.temporaryDirectory)

        XCTAssertEqual(center.addedRequests.count, 5)
        let weekdays = Set(
            center.addedRequests.compactMap {
                ($0.trigger as? UNCalendarNotificationTrigger)?.dateComponents.weekday
            }
        )
        XCTAssertEqual(weekdays, Set([2, 3, 4, 5, 6]))
        XCTAssertTrue(center.addedRequests.allSatisfy { ($0.trigger as? UNCalendarNotificationTrigger)?.repeats == true })
    }

    func testCustomDaysAlarmCreatesOnlySelectedWeekdayRequests() {
        let center = FakeNotificationCenter()
        let scheduler = makeScheduler(center: center)
        let alarm = alarm(hour: 6, minute: 45, repeatRule: .customDays([1, 4, 7]))

        scheduler.rescheduleAlarms([alarm], recordingsDirectory: FileManager.default.temporaryDirectory)

        XCTAssertEqual(center.addedRequests.count, 3)
        let weekdays = Set(
            center.addedRequests.compactMap {
                ($0.trigger as? UNCalendarNotificationTrigger)?.dateComponents.weekday
            }
        )
        XCTAssertEqual(weekdays, Set([1, 4, 7]))
    }

    func testEveryXHoursCreatesLookaheadSequenceWithExpectedInterval() {
        let center = FakeNotificationCenter()
        let now = date(year: 2026, month: 2, day: 8, hour: 10, minute: 15)
        let calendar = utcCalendar()
        let scheduler = NotificationScheduler(center: center, calendar: calendar, now: { now })
        let alarm = alarm(hour: 9, minute: 0, repeatRule: .everyXHours(3))

        scheduler.rescheduleAlarms([alarm], recordingsDirectory: FileManager.default.temporaryDirectory)

        XCTAssertEqual(center.addedRequests.count, 32)
        guard center.addedRequests.count >= 2 else {
            return XCTFail("Expected at least two interval requests")
        }

        let firstDate = scheduledDate(for: center.addedRequests[0], calendar: calendar)
        let secondDate = scheduledDate(for: center.addedRequests[1], calendar: calendar)

        XCTAssertEqual(firstDate, date(year: 2026, month: 2, day: 8, hour: 12, minute: 0))
        XCTAssertEqual(secondDate, date(year: 2026, month: 2, day: 8, hour: 15, minute: 0))
        XCTAssertEqual(secondDate.timeIntervalSince(firstDate), 3 * 60 * 60)
        XCTAssertTrue(center.addedRequests.allSatisfy { ($0.trigger as? UNCalendarNotificationTrigger)?.repeats == false })
    }

    func testEveryXDaysNormalizesZeroIntervalToOneDay() {
        let center = FakeNotificationCenter()
        let now = date(year: 2026, month: 2, day: 8, hour: 10, minute: 15)
        let calendar = utcCalendar()
        let scheduler = NotificationScheduler(center: center, calendar: calendar, now: { now })
        let alarm = alarm(hour: 9, minute: 0, repeatRule: .everyXDays(0))

        scheduler.rescheduleAlarms([alarm], recordingsDirectory: FileManager.default.temporaryDirectory)

        guard center.addedRequests.count >= 2 else {
            return XCTFail("Expected at least two interval requests")
        }
        let firstDate = scheduledDate(for: center.addedRequests[0], calendar: calendar)
        let secondDate = scheduledDate(for: center.addedRequests[1], calendar: calendar)

        XCTAssertEqual(firstDate, date(year: 2026, month: 2, day: 9, hour: 9, minute: 0))
        XCTAssertEqual(secondDate, date(year: 2026, month: 2, day: 10, hour: 9, minute: 0))
        XCTAssertEqual(secondDate.timeIntervalSince(firstDate), 24 * 60 * 60)
    }

    func testOnceAlarmSchedulesNextFutureDate() {
        let center = FakeNotificationCenter()
        let now = date(year: 2026, month: 2, day: 8, hour: 10, minute: 15)
        let calendar = utcCalendar()
        let scheduler = NotificationScheduler(center: center, calendar: calendar, now: { now })
        let alarm = alarm(hour: 9, minute: 0, repeatRule: .once)

        scheduler.rescheduleAlarms([alarm], recordingsDirectory: FileManager.default.temporaryDirectory)

        guard let request = center.addedRequests.first else {
            return XCTFail("Expected one request")
        }
        guard let trigger = request.trigger as? UNCalendarNotificationTrigger else {
            return XCTFail("Expected calendar trigger")
        }

        XCTAssertFalse(trigger.repeats)
        XCTAssertEqual(trigger.dateComponents.year, 2026)
        XCTAssertEqual(trigger.dateComponents.month, 2)
        XCTAssertEqual(trigger.dateComponents.day, 9)
        XCTAssertEqual(trigger.dateComponents.hour, 9)
        XCTAssertEqual(trigger.dateComponents.minute, 0)
    }

    private func makeScheduler(center: FakeNotificationCenter) -> NotificationScheduler {
        NotificationScheduler(center: center, calendar: utcCalendar(), now: {
            self.date(year: 2026, month: 2, day: 8, hour: 10, minute: 15)
        })
    }

    private func alarm(
        id: UUID = UUID(),
        hour: Int,
        minute: Int,
        repeatRule: AlarmRepeatRule,
        isEnabled: Bool = true
    ) -> Alarm {
        Alarm(
            id: id,
            title: "Test Alarm",
            hour: hour,
            minute: minute,
            repeatRule: repeatRule,
            isEnabled: isEnabled,
            gradualVolume: true,
            voice: .basicTTS,
            message: "Time to focus."
        )
    }

    private func pendingRequest(id: String) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Pending"
        return UNNotificationRequest(identifier: id, content: content, trigger: nil)
    }

    private func scheduledDate(for request: UNNotificationRequest, calendar: Calendar) -> Date {
        guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
              let date = calendar.date(from: trigger.dateComponents) else {
            XCTFail("Expected calendar trigger with full date components")
            return .distantPast
        }
        return date
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.calendar = utcCalendar()
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        return components.date ?? .distantPast
    }
}

private final class FakeNotificationCenter: NotificationSchedulingCenter {
    var requestedOptions: UNAuthorizationOptions?
    var pendingRequests: [UNNotificationRequest] = []
    var removedIdentifiersHistory: [[String]] = []
    var addedRequests: [UNNotificationRequest] = []

    func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @Sendable @escaping (Bool, Error?) -> Void) {
        requestedOptions = options
        completionHandler(true, nil)
    }

    func getPendingNotificationRequests(completionHandler: @Sendable @escaping ([UNNotificationRequest]) -> Void) {
        completionHandler(pendingRequests)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiersHistory.append(identifiers)
        pendingRequests.removeAll(where: { identifiers.contains($0.identifier) })
    }

    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?) {
        addedRequests.append(request)
        completionHandler?(nil)
    }
}
