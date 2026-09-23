import SwiftUI

/// Main alarm list view with Vibe design system styling
struct AlarmListView: View {
    @ObservedObject var viewModel: AlarmListViewModel
    @State private var isDiagnosticsPresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VibeSpacing.md) {
                    // Header
                    VStack(alignment: .leading, spacing: VibeSpacing.xs) {
                        Text(L10n.tr("app.name"))
                            .font(VibeFont.largeTitle)
                            .foregroundStyle(VibeColor.textPrimary)
                            .padding(.leading, VibeSpacing.lg)

                        if viewModel.alarms.isEmpty {
                            VibeCard {
                                VStack(spacing: VibeSpacing.md) {
                                    Image(systemName: "alarm")
                                        .font(.system(size: 48))
                                        .foregroundStyle(VibeColor.accent.opacity(0.5))

                                    Text(L10n.tr("alarm.list.empty.title"))
                                        .font(VibeFont.title2)
                                        .foregroundStyle(VibeColor.textPrimary)

                                    Text(L10n.tr("alarm.list.empty.description"))
                                        .font(VibeFont.body)
                                        .foregroundStyle(VibeColor.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(VibeSpacing.xl)
                            }
                            .padding(.horizontal, VibeSpacing.lg)
                        }
                    }

                    // Alarm List
                    if !viewModel.alarms.isEmpty {
                        VStack(spacing: VibeSpacing.md) {
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
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    viewModel.deleteAlarm(viewModel.alarms[index])
                                }
                            }
                        }
                        .padding(.horizontal, VibeSpacing.lg)
                    }

                    Spacer()
                }
            }
            .background(VibeColor.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.tier == .free {
                        Button {
                            viewModel.showPaywall(reason: L10n.tr("paywall.reason.unlock_features"))
                        } label: {
                            VibeBadge(L10n.tr("common.upgrade"))
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isDiagnosticsPresented = true
                    } label: {
                        Image(systemName: "stethoscope")
                            .foregroundStyle(VibeColor.accent)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VibeCard(padding: EdgeInsets(top: VibeSpacing.md, leading: VibeSpacing.lg, bottom: VibeSpacing.md, trailing: VibeSpacing.lg)) {
                    Button {
                        viewModel.addAlarmTapped()
                    } label: {
                        HStack(spacing: VibeSpacing.sm) {
                            Image(systemName: "plus.circle.fill")
                            Text(L10n.tr("alarm.add"))
                        }
                        .font(VibeFont.headline)
                        .frame(maxWidth: .infinity)
                    }
                    .vibePrimaryButton()
                }
                .padding(.bottom, VibeSpacing.md)
            }
            .sheet(item: $viewModel.activeSheet) { sheet in
                switch sheet {
                case .editor(let alarm):
                    NavigationStack {
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
                        .background(VibeColor.background)
                    }
                    .presentationDetents([.medium, .large])

                case .paywall(let reason):
                    NavigationStack {
                        PaywallSheet(
                            reason: reason,
                            subscriptionService: viewModel.subscriptionService,
                            onClose: {
                                viewModel.closeSheet()
                            }
                        )
                        .background(VibeColor.background)
                    }
                    .presentationDetents([.medium])
                }
            }
            .sheet(isPresented: $isDiagnosticsPresented) {
                NavigationStack {
                    DiagnosticsSheet(
                        viewModel: viewModel,
                        onClose: {
                            isDiagnosticsPresented = false
                        }
                    )
                    .background(VibeColor.background)
                }
                .presentationDetents([.large])
            }
        }
    }
}

// MARK: - Alarm Row Component

private struct AlarmRow: View {
    let alarm: Alarm
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            VibeCard {
                HStack(spacing: VibeSpacing.md) {
                    // Time and Info
                    VStack(alignment: .leading, spacing: VibeSpacing.xs) {
                        Text(alarm.timeLabel)
                            .font(VibeFont.title3)
                            .foregroundStyle(alarm.isEnabled ? VibeColor.textPrimary : VibeColor.textSecondary)

                        Text(alarm.title)
                            .font(VibeFont.body.weight(.semibold))
                            .foregroundStyle(alarm.isEnabled ? VibeColor.textPrimary : VibeColor.textSecondary)

                        // Repeat rule and next reminder
                        HStack(spacing: VibeSpacing.sm) {
                            Text(alarm.repeatRule.label)
                                .font(VibeFont.footnote)
                                .foregroundStyle(VibeColor.textSecondary)

                            if let nextReminderText {
                                Text(nextReminderText)
                                    .font(VibeFont.footnote)
                                    .foregroundStyle(VibeColor.accent)
                            }
                        }

                        // Challenge indicator
                        if let challenge = alarm.challenge {
                            VibeBadge(challenge.title)
                        }
                    }

                    Spacer()

                    // Toggle
                    Toggle("", isOn: Binding(get: {
                        alarm.isEnabled
                    }, set: { newValue in
                        onToggle(newValue)
                    }))
                    .labelsHidden()
                    .tint(VibeColor.accent)
                }
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

// MARK: - Preview

#Preview {
    let viewModel = AlarmListViewModel()
    return NavigationStack {
        AlarmListView(viewModel: viewModel)
            .background(VibeColor.background)
    }
}
