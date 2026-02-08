import SwiftUI
@preconcurrency import UserNotifications

@MainActor
struct DiagnosticsSheet: View {
    @ObservedObject var viewModel: AlarmListViewModel
    let onClose: () -> Void

    @State private var snapshot = DiagnosticsSnapshot.empty
    @State private var isLoading = false
    private let collector = DiagnosticsCollector()

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.tr("diagnostics.section.app")) {
                    row(L10n.tr("diagnostics.row.version"), snapshot.version)
                    row(L10n.tr("diagnostics.row.build"), snapshot.build)
                }

                Section(L10n.tr("diagnostics.section.account")) {
                    row(L10n.tr("diagnostics.row.tier"), tierLabel(viewModel.tier))
                }

                Section(L10n.tr("diagnostics.section.locale")) {
                    row(L10n.tr("diagnostics.row.language"), snapshot.language)
                    row(L10n.tr("diagnostics.row.locale"), snapshot.localeIdentifier)
                }

                Section(L10n.tr("diagnostics.section.alarms")) {
                    row(L10n.tr("diagnostics.row.total_alarms"), "\(snapshot.totalAlarms)")
                    row(L10n.tr("diagnostics.row.enabled_alarms"), "\(snapshot.enabledAlarms)")
                    row(L10n.tr("diagnostics.row.medicine_alarms"), "\(snapshot.medicineAlarms)")
                }

                Section(L10n.tr("diagnostics.section.notifications")) {
                    row(L10n.tr("diagnostics.row.authorization"), authorizationLabel(snapshot.authorizationStatus))
                    row(L10n.tr("diagnostics.row.pending_alarm_requests"), "\(snapshot.pendingAlarmRequests)")
                    row(L10n.tr("diagnostics.row.recordings_path"), snapshot.recordingsDirectoryPath)

                    if snapshot.pendingSummaries.isEmpty {
                        Text(L10n.tr("diagnostics.pending.none"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(L10n.tr("diagnostics.pending.header"))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(Array(snapshot.pendingSummaries.enumerated()), id: \.offset) { _, item in
                            Text(item)
                                .font(.footnote)
                        }
                    }
                }
            }
            .navigationTitle(L10n.tr("diagnostics.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.tr("common.close")) {
                        onClose()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.tr("diagnostics.refresh")) {
                        refresh()
                    }
                    .disabled(isLoading)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
            .task {
                await refreshAsync()
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func tierLabel(_ tier: SubscriptionTier) -> String {
        switch tier {
        case .free:
            return L10n.tr("diagnostics.value.tier.free")
        case .pro:
            return L10n.tr("diagnostics.value.tier.pro")
        }
    }

    private func authorizationLabel(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return L10n.tr("diagnostics.value.auth.not_determined")
        case .denied:
            return L10n.tr("diagnostics.value.auth.denied")
        case .authorized:
            return L10n.tr("diagnostics.value.auth.authorized")
        case .provisional:
            return L10n.tr("diagnostics.value.auth.provisional")
        case .ephemeral:
            return L10n.tr("diagnostics.value.auth.ephemeral")
        @unknown default:
            return L10n.tr("diagnostics.value.auth.unknown")
        }
    }

    private func refresh() {
        Task {
            await refreshAsync()
        }
    }

    private func refreshAsync() async {
        isLoading = true
        let collected = await collector.collect(
            alarms: viewModel.alarms,
            tier: viewModel.tier,
            recordingsDirectory: viewModel.recorderService.recordingsDirectory
        )
        snapshot = collected
        isLoading = false
    }
}

@MainActor
private final class DiagnosticsCollector {
    private let center = UNUserNotificationCenter.current()
    private let formatter: DateFormatter
    private struct PendingRequestInfo: Sendable {
        let identifier: String
        let nextDate: Date?
    }

    init() {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        self.formatter = formatter
    }

    func collect(alarms: [Alarm], tier: SubscriptionTier, recordingsDirectory: URL) async -> DiagnosticsSnapshot {
        let status = await authorizationStatus()
        let pending = await pendingRequests()

        let alarmPending = pending.filter { $0.identifier.hasPrefix("alarm-") }
        let pendingSummaries = alarmPending
            .compactMap { request -> String? in
                guard let date = request.nextDate else { return nil }
                return L10n.format(
                    "diagnostics.pending.item",
                    request.identifier,
                    formatter.string(from: date)
                )
            }
            .sorted()

        let medicineCount = alarms.filter {
            if case .everyXHours = $0.repeatRule { return true }
            if case .everyXDays = $0.repeatRule { return true }
            return false
        }.count

        let localeIdentifier = Locale.current.identifier
        let language = Locale.current.localizedString(forLanguageCode: Locale.current.language.languageCode?.identifier ?? "en") ?? localeIdentifier
        let infoDictionary = Bundle.main.infoDictionary ?? [:]
        let version = (infoDictionary["CFBundleShortVersionString"] as? String) ?? "1.0.0"
        let build = (infoDictionary["CFBundleVersion"] as? String) ?? "1"

        return DiagnosticsSnapshot(
            version: version,
            build: build,
            language: language,
            localeIdentifier: localeIdentifier,
            totalAlarms: alarms.count,
            enabledAlarms: alarms.filter(\.isEnabled).count,
            medicineAlarms: medicineCount,
            authorizationStatus: status,
            pendingAlarmRequests: alarmPending.count,
            pendingSummaries: Array(pendingSummaries.prefix(12)),
            recordingsDirectoryPath: recordingsDirectory.path
        )
    }

    private func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    private func pendingRequests() async -> [PendingRequestInfo] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                let mapped = requests.map { request in
                    PendingRequestInfo(
                        identifier: request.identifier,
                        nextDate: Self.nextDate(for: request.trigger)
                    )
                }
                continuation.resume(returning: mapped)
            }
        }
    }

    private nonisolated static func nextDate(for trigger: UNNotificationTrigger?) -> Date? {
        guard let trigger else { return nil }
        if let calendar = trigger as? UNCalendarNotificationTrigger {
            return calendar.nextTriggerDate()
        }
        if let timeInterval = trigger as? UNTimeIntervalNotificationTrigger {
            return Date().addingTimeInterval(timeInterval.timeInterval)
        }
        return nil
    }
}

private struct DiagnosticsSnapshot {
    let version: String
    let build: String
    let language: String
    let localeIdentifier: String
    let totalAlarms: Int
    let enabledAlarms: Int
    let medicineAlarms: Int
    let authorizationStatus: UNAuthorizationStatus
    let pendingAlarmRequests: Int
    let pendingSummaries: [String]
    let recordingsDirectoryPath: String

    static let empty = DiagnosticsSnapshot(
        version: "-",
        build: "-",
        language: "-",
        localeIdentifier: "-",
        totalAlarms: 0,
        enabledAlarms: 0,
        medicineAlarms: 0,
        authorizationStatus: .notDetermined,
        pendingAlarmRequests: 0,
        pendingSummaries: [],
        recordingsDirectoryPath: "-"
    )
}
