import SwiftUI

struct AlarmListView: View {
    @ObservedObject var viewModel: AlarmListViewModel
    @State private var isDiagnosticsPresented = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.alarms.isEmpty {
                    ContentUnavailableView(
                        L10n.tr("alarm.list.empty.title"),
                        systemImage: "alarm",
                        description: Text(L10n.tr("alarm.list.empty.description"))
                    )
                } else {
                    List {
                        ForEach(viewModel.alarms) { alarm in
                            AlarmRow(
                                alarm: alarm,
                                onToggle: { isOn in
                                    viewModel.setEnabled(isOn, for: alarm)
                                },
                                onEdit: {
                                    viewModel.editAlarmTapped(alarm)
                                }
                            )
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                viewModel.deleteAlarm(viewModel.alarms[index])
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(L10n.tr("app.name"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.tier == .free {
                        Button(L10n.tr("common.upgrade")) {
                            viewModel.showPaywall(reason: L10n.tr("paywall.reason.unlock_features"))
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isDiagnosticsPresented = true
                    } label: {
                        Label(L10n.tr("diagnostics.open"), systemImage: "stethoscope")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    viewModel.addAlarmTapped()
                } label: {
                    Label(L10n.tr("alarm.add"), systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(.ultraThinMaterial)
            }
            .sheet(item: $viewModel.activeSheet) { sheet in
                switch sheet {
                case .editor(let alarm):
                    AlarmEditorSheet(
                        existingAlarm: alarm,
                        tier: viewModel.tier,
                        recorderService: viewModel.recorderService,
                        onPreview: { viewModel.previewVoice(for: $0) },
                        onRequirePro: { reason in viewModel.showPaywall(reason: reason) },
                        onSave: { alarm in
                            viewModel.saveAlarm(alarm)
                            viewModel.closeSheet()
                        },
                        onCancel: {
                            viewModel.closeSheet()
                        }
                    )
                    .presentationDetents([.medium, .large])

                case .paywall(let reason):
                    PaywallSheet(
                        reason: reason,
                        subscriptionService: viewModel.subscriptionService,
                        onClose: {
                            viewModel.closeSheet()
                        }
                    )
                    .presentationDetents([.medium])
                }
            }
            .sheet(isPresented: $isDiagnosticsPresented) {
                DiagnosticsSheet(
                    viewModel: viewModel,
                    onClose: {
                        isDiagnosticsPresented = false
                    }
                )
                .presentationDetents([.large])
            }
        }
    }
}

private struct AlarmRow: View {
    let alarm: Alarm
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(alarm.timeLabel)
                        .font(.title2)
                        .foregroundStyle(alarm.isEnabled ? .primary : .secondary)
                    Text(alarm.title)
                        .font(.subheadline.weight(.semibold))
                    Text(alarm.repeatRule.label)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let nextReminderText {
                        Text(nextReminderText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(get: {
                    alarm.isEnabled
                }, set: { newValue in
                    onToggle(newValue)
                }))
                .labelsHidden()
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(L10n.tr("alarm.row.accessibility.hint"))
    }

    private var accessibilityLabel: String {
        if let nextReminderText {
            return L10n.format("alarm.row.accessibility.label_with_next", alarm.title, alarm.timeLabel, alarm.repeatRule.label, nextReminderText)
        }
        return L10n.format("alarm.row.accessibility.label", alarm.title, alarm.timeLabel, alarm.repeatRule.label)
    }

    private var nextReminderText: String? {
        guard alarm.isEnabled, let date = nextReminderDate else { return nil }
        return L10n.format("alarm.row.next_reminder", Self.nextReminderFormatter.string(from: date))
    }

    private var nextReminderDate: Date? {
        switch alarm.repeatRule {
        case .everyXHours(let interval):
            return nextIntervalOccurrence(component: .hour, interval: interval)
        case .everyXDays(let interval):
            return nextIntervalOccurrence(component: .day, interval: interval)
        case .once, .daily, .weekdays, .customDays:
            return nil
        }
    }

    private func nextIntervalOccurrence(component: Calendar.Component, interval: Int) -> Date? {
        let safeInterval = max(1, interval)
        let now = Date()
        let calendar = Calendar.current

        var dateComponents = calendar.dateComponents([.year, .month, .day], from: now)
        dateComponents.hour = alarm.hour
        dateComponents.minute = alarm.minute
        dateComponents.second = 0

        guard var candidate = calendar.date(from: dateComponents) else { return nil }
        if candidate > now {
            return candidate
        }

        while candidate <= now {
            guard let next = calendar.date(byAdding: component, value: safeInterval, to: candidate) else {
                return nil
            }
            candidate = next
        }
        return candidate
    }

    private static let nextReminderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
