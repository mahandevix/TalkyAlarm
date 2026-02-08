import SwiftUI

struct AlarmEditorSheet: View {
    let existingAlarm: Alarm?
    let tier: SubscriptionTier
    let recorderService: AudioRecorderService
    let onPreview: (Alarm) -> Void
    let onRequirePro: (String) -> Void
    let onSave: (Alarm) -> Void
    let onCancel: () -> Void

    @State private var title: String
    @State private var time: Date
    @State private var repeatRule: AlarmRepeatRule
    @State private var gradualVolume: Bool
    @State private var voice: AlarmVoice
    @State private var message: String
    @State private var recordingFileName: String?
    @State private var customDays: Set<Int>
    @State private var hourInterval: Int
    @State private var dayInterval: Int
    @State private var validationMessage: String?

    init(
        existingAlarm: Alarm?,
        tier: SubscriptionTier,
        recorderService: AudioRecorderService,
        onPreview: @escaping (Alarm) -> Void,
        onRequirePro: @escaping (String) -> Void,
        onSave: @escaping (Alarm) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.existingAlarm = existingAlarm
        self.tier = tier
        self.recorderService = recorderService
        self.onPreview = onPreview
        self.onRequirePro = onRequirePro
        self.onSave = onSave
        self.onCancel = onCancel

        let currentAlarm = existingAlarm
        var components = DateComponents()
        components.hour = currentAlarm?.hour ?? 7
        components.minute = currentAlarm?.minute ?? 30

        _title = State(initialValue: currentAlarm?.title ?? L10n.tr("alarm.default_title"))
        _time = State(initialValue: Calendar.current.date(from: components) ?? .now)
        _repeatRule = State(initialValue: currentAlarm?.repeatRule ?? .daily)
        _gradualVolume = State(initialValue: currentAlarm?.gradualVolume ?? true)
        _voice = State(initialValue: currentAlarm?.voice ?? .basicTTS)
        _message = State(initialValue: currentAlarm?.message ?? L10n.tr("alarm.default_message"))
        _recordingFileName = State(initialValue: currentAlarm?.recordingFileName)

        if case .customDays(let days) = currentAlarm?.repeatRule {
            _customDays = State(initialValue: Set(days))
        } else {
            _customDays = State(initialValue: [2, 3, 4, 5, 6])
        }

        if case .everyXHours(let interval) = currentAlarm?.repeatRule {
            _hourInterval = State(initialValue: max(1, interval))
        } else {
            _hourInterval = State(initialValue: 8)
        }

        if case .everyXDays(let interval) = currentAlarm?.repeatRule {
            _dayInterval = State(initialValue: max(1, interval))
        } else {
            _dayInterval = State(initialValue: 1)
        }

        _validationMessage = State(initialValue: nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.tr("alarm.editor.section.schedule")) {
                    DatePicker(L10n.tr("alarm.editor.time"), selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)

                    Picker(L10n.tr("alarm.editor.repeat"), selection: $repeatRule) {
                        Text(L10n.tr("repeat.once")).tag(AlarmRepeatRule.once)
                        Text(L10n.tr("repeat.daily")).tag(AlarmRepeatRule.daily)
                        Text(L10n.tr("repeat.weekdays")).tag(AlarmRepeatRule.weekdays)
                        Text(L10n.tr("repeat.custom_days")).tag(AlarmRepeatRule.customDays(Array(customDays)))
                        Text(L10n.tr("alarm.editor.repeat.every_x_hours_option")).tag(AlarmRepeatRule.everyXHours(hourInterval))
                        Text(L10n.tr("alarm.editor.repeat.every_x_days_option")).tag(AlarmRepeatRule.everyXDays(dayInterval))
                    }
                    .onChange(of: repeatRule) { _, newValue in
                        if newValue.isProOnly && tier == .free {
                            repeatRule = .daily
                            onRequirePro(L10n.tr("paywall.reason.medicine_repeat"))
                        }
                    }

                    switch repeatRule {
                    case .customDays:
                        WeekdaySelector(days: $customDays)
                            .onChange(of: customDays) { _, newValue in
                                repeatRule = .customDays(newValue.sorted())
                            }
                    case .everyXHours:
                        Stepper(value: $hourInterval, in: 1 ... 24) {
                            Text(hoursStepperLabel)
                        }
                        .onChange(of: hourInterval) { _, newValue in
                            repeatRule = .everyXHours(newValue)
                        }
                        NextTriggersPreview(
                            title: L10n.tr("alarm.editor.next_triggers"),
                            dates: upcomingIntervalDates(component: .hour, interval: hourInterval)
                        )
                    case .everyXDays:
                        Stepper(value: $dayInterval, in: 1 ... 30) {
                            Text(daysStepperLabel)
                        }
                        .onChange(of: dayInterval) { _, newValue in
                            repeatRule = .everyXDays(newValue)
                        }
                        NextTriggersPreview(
                            title: L10n.tr("alarm.editor.next_triggers"),
                            dates: upcomingIntervalDates(component: .day, interval: dayInterval)
                        )
                    case .once, .daily, .weekdays:
                        EmptyView()
                    }
                }

                Section(L10n.tr("alarm.editor.section.voice")) {
                    Picker(L10n.tr("alarm.editor.voice_type"), selection: $voice) {
                        ForEach(AlarmVoice.allCases) { candidate in
                            if candidate.isProOnly && tier == .free {
                                Text(L10n.format("voice.option.pro_format", candidate.title, L10n.tr("plan.pro_short"))).tag(candidate)
                            } else {
                                Text(candidate.title).tag(candidate)
                            }
                        }
                    }
                    .onChange(of: voice) { _, newValue in
                        if newValue.isProOnly && tier == .free {
                            voice = .basicTTS
                            onRequirePro(L10n.tr("paywall.reason.voice_features"))
                        }
                    }

                    if voice == .recorded {
                        HStack {
                            Button(recorderService.isRecording ? L10n.tr("alarm.editor.record.stop") : L10n.tr("alarm.editor.record.start")) {
                                toggleRecording()
                            }
                            .buttonStyle(.borderedProminent)

                            if let recordingFileName {
                                Text(L10n.format("alarm.editor.record.saved", recordingFileName))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Toggle(L10n.tr("alarm.editor.gradual_volume"), isOn: $gradualVolume)
                }

                Section(L10n.tr("alarm.editor.section.message")) {
                    TextField(L10n.tr("alarm.editor.title_placeholder"), text: $title)
                    TextField(L10n.tr("alarm.editor.message_placeholder"), text: $message, axis: .vertical)
                        .lineLimit(2 ... 4)

                    Button(L10n.tr("alarm.editor.preview_voice")) {
                        onPreview(buildAlarm(isEnabled: true))
                    }
                }

                if let validationMessage {
                    Section {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(existingAlarm == nil ? L10n.tr("alarm.editor.title.new") : L10n.tr("alarm.editor.title.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.tr("common.cancel")) { onCancel() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.tr("common.save")) {
                        saveTapped()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveTapped() {
        let builtAlarm = buildAlarm(isEnabled: existingAlarm?.isEnabled ?? true)

        if builtAlarm.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationMessage = L10n.tr("alarm.editor.validation.title_required")
            return
        }

        if case .customDays(let days) = builtAlarm.repeatRule, days.isEmpty {
            validationMessage = L10n.tr("alarm.editor.validation.custom_days_required")
            return
        }

        if builtAlarm.voice == .recorded && builtAlarm.recordingFileName == nil {
            validationMessage = L10n.tr("alarm.editor.validation.recording_required")
            return
        }

        validationMessage = nil
        onSave(builtAlarm)
    }

    private func buildAlarm(isEnabled: Bool) -> Alarm {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let selectedRepeat: AlarmRepeatRule
        switch repeatRule {
        case .customDays:
            selectedRepeat = .customDays(customDays.sorted())
        case .everyXHours:
            selectedRepeat = .everyXHours(hourInterval)
        case .everyXDays:
            selectedRepeat = .everyXDays(dayInterval)
        case .once, .daily, .weekdays:
            selectedRepeat = repeatRule
        }

        return Alarm(
            id: existingAlarm?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            hour: components.hour ?? 7,
            minute: components.minute ?? 30,
            repeatRule: selectedRepeat,
            isEnabled: isEnabled,
            gradualVolume: gradualVolume,
            voice: voice,
            message: message.trimmingCharacters(in: .whitespacesAndNewlines),
            recordingFileName: recordingFileName,
            createdAt: existingAlarm?.createdAt ?? .now
        )
    }

    private func toggleRecording() {
        Task {
            if recorderService.isRecording {
                _ = recorderService.stop()
                return
            }

            let granted = await recorderService.requestPermission()
            guard granted else {
                validationMessage = L10n.tr("alarm.editor.validation.microphone_required")
                return
            }

            do {
                let fileName = "alarm-\(UUID().uuidString.lowercased())"
                _ = try recorderService.start(fileName: fileName)
                recordingFileName = fileName
                validationMessage = nil
            } catch {
                validationMessage = L10n.tr("alarm.editor.validation.recording_failed")
            }
        }
    }

    private var hoursStepperLabel: String {
        if hourInterval == 1 {
            return L10n.format("repeat.every_x_hour", hourInterval)
        }
        return L10n.format("repeat.every_x_hours", hourInterval)
    }

    private var daysStepperLabel: String {
        if dayInterval == 1 {
            return L10n.format("repeat.every_x_day", dayInterval)
        }
        return L10n.format("repeat.every_x_days", dayInterval)
    }

    private func upcomingIntervalDates(component: Calendar.Component, interval: Int, count: Int = 3) -> [Date] {
        guard count > 0, interval > 0, let start = nextIntervalOccurrence(component: component, interval: interval) else {
            return []
        }

        var dates: [Date] = [start]
        var current = start
        let calendar = Calendar.current

        for _ in 1 ..< count {
            guard let next = calendar.date(byAdding: component, value: interval, to: current) else {
                break
            }
            dates.append(next)
            current = next
        }

        return dates
    }

    private func nextIntervalOccurrence(component: Calendar.Component, interval: Int) -> Date? {
        let safeInterval = max(1, interval)
        let now = Date()
        let calendar = Calendar.current

        let selectedTime = calendar.dateComponents([.hour, .minute], from: time)
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: now)
        dateComponents.hour = selectedTime.hour
        dateComponents.minute = selectedTime.minute
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
}

private struct WeekdaySelector: View {
    @Binding var days: Set<Int>

    private let weekdaySymbols = Calendar.current.veryShortWeekdaySymbols

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...7, id: \.self) { day in
                Button {
                    if days.contains(day) {
                        days.remove(day)
                    } else {
                        days.insert(day)
                    }
                } label: {
                    Text(weekdaySymbols[day - 1])
                        .font(.footnote.weight(.semibold))
                        .frame(width: 32, height: 32)
                        .background(days.contains(day) ? Color.accentColor : Color.secondary.opacity(0.2))
                        .foregroundStyle(days.contains(day) ? .white : .primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 4)
    }
}

private struct NextTriggersPreview: View {
    let title: String
    let dates: [Date]

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        if !dates.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(dates, id: \.self) { date in
                    Text(Self.formatter.string(from: date))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
        }
    }
}
