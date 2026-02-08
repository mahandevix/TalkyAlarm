import Foundation
import Combine

@MainActor
final class AlarmListViewModel: ObservableObject {
    enum ActiveSheet: Identifiable {
        case editor(Alarm?)
        case paywall(String)

        var id: String {
            switch self {
            case .editor(let alarm):
                return "editor-\(alarm?.id.uuidString ?? "new")"
            case .paywall:
                return "paywall"
            }
        }
    }

    @Published var alarms: [Alarm] = []
    @Published var activeSheet: ActiveSheet?
    @Published private(set) var tier: SubscriptionTier

    let subscriptionService: SubscriptionService
    private let alarmStore: AlarmStore
    private let notificationScheduler: NotificationScheduler
    private let speechService: SpeechService
    let recorderService: AudioRecorderService
    private var cancellables = Set<AnyCancellable>()

    init(
        alarmStore: AlarmStore = AlarmStore(),
        notificationScheduler: NotificationScheduler = NotificationScheduler(),
        speechService: SpeechService = SpeechService(),
        subscriptionService: SubscriptionService = SubscriptionService(),
        recorderService: AudioRecorderService = AudioRecorderService()
    ) {
        self.alarmStore = alarmStore
        self.notificationScheduler = notificationScheduler
        self.speechService = speechService
        self.subscriptionService = subscriptionService
        self.recorderService = recorderService
        self.tier = subscriptionService.tier

        alarms = alarmStore.load().sorted(by: sortComparator)

        subscriptionService.$tier
            .receive(on: RunLoop.main)
            .sink { [weak self] newTier in
                guard let self else { return }
                self.tier = newTier
                if newTier == .pro, case .paywall = self.activeSheet {
                    self.activeSheet = nil
                }
            }
            .store(in: &cancellables)

        notificationScheduler.requestAuthorizationIfNeeded()
        rescheduleNotifications()
    }

    var isFreeTierLimitReached: Bool {
        tier == .free && alarms.count >= tier.maxAlarms
    }

    func addAlarmTapped() {
        guard !isFreeTierLimitReached else {
            activeSheet = .paywall(L10n.tr("paywall.reason.free_limit"))
            return
        }
        activeSheet = .editor(nil)
    }

    func editAlarmTapped(_ alarm: Alarm) {
        activeSheet = .editor(alarm)
    }

    func saveAlarm(_ alarm: Alarm) {
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[index] = alarm
        } else {
            guard alarms.count < tier.maxAlarms else {
                activeSheet = .paywall(L10n.tr("paywall.reason.unlimited"))
                return
            }
            alarms.append(alarm)
        }

        alarms.sort(by: sortComparator)
        persistAndReschedule()
    }

    func setEnabled(_ isEnabled: Bool, for alarm: Alarm) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[index].isEnabled = isEnabled
        persistAndReschedule()
    }

    func deleteAlarm(_ alarm: Alarm) {
        alarms.removeAll(where: { $0.id == alarm.id })
        persistAndReschedule()
    }

    func previewVoice(for alarm: Alarm) {
        speechService.preview(sentence: alarm.spokenSentence, voice: alarm.voice, tier: tier)
    }

    func showPaywall(reason: String) {
        activeSheet = .paywall(reason)
    }

    func closeSheet() {
        activeSheet = nil
    }

    func canUse(_ voice: AlarmVoice) -> Bool {
        tier == .pro || !voice.isProOnly
    }

    func canUse(_ rule: AlarmRepeatRule) -> Bool {
        tier == .pro || !rule.isProOnly
    }

    func refreshSchedulesForLifecycle() {
        rescheduleNotifications()
    }

    private func persistAndReschedule() {
        do {
            try alarmStore.save(alarms)
        } catch {
            // Ignore save errors for MVP and keep in-memory state.
        }

        rescheduleNotifications()
    }

    private func rescheduleNotifications() {
        notificationScheduler.rescheduleAlarms(alarms, recordingsDirectory: recorderService.recordingsDirectory)
    }

    private var sortComparator: (Alarm, Alarm) -> Bool {
        { lhs, rhs in
            if lhs.hour == rhs.hour {
                return lhs.minute < rhs.minute
            }
            return lhs.hour < rhs.hour
        }
    }
}
