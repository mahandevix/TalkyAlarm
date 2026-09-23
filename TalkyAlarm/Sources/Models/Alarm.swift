import Foundation

struct Alarm: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var hour: Int
    var minute: Int
    var repeatRule: AlarmRepeatRule
    var isEnabled: Bool
    var gradualVolume: Bool
    var voice: AlarmVoice
    var message: String
    var recordingFileName: String?
    var createdAt: Date
    var challenge: PhysicalChallenge?
    var challengeTarget: Int

    init(
        id: UUID = UUID(),
        title: String,
        hour: Int,
        minute: Int,
        repeatRule: AlarmRepeatRule = .once,
        isEnabled: Bool = true,
        gradualVolume: Bool = true,
        voice: AlarmVoice = .basicTTS,
        message: String,
        recordingFileName: String? = nil,
        createdAt: Date = .now,
        challenge: PhysicalChallenge? = nil,
        challengeTarget: Int = 10
    ) {
        self.id = id
        self.title = title
        self.hour = hour
        self.minute = minute
        self.repeatRule = repeatRule
        self.isEnabled = isEnabled
        self.gradualVolume = gradualVolume
        self.voice = voice
        self.message = message
        self.recordingFileName = recordingFileName
        self.createdAt = createdAt
        self.challenge = challenge
        self.challengeTarget = challengeTarget
    }

    var timeLabel: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeStyle = .short
        formatter.dateStyle = .none

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let date = Calendar.current.date(from: components) ?? .now
        return formatter.string(from: date)
    }

    var spokenSentence: String {
        let cleanedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedMessage.isEmpty {
            return L10n.format("alarm.spoken.empty", timeLabel, title)
        }
        return L10n.format("alarm.spoken.with_message", timeLabel, cleanedMessage)
    }
}
