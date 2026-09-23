import Foundation

enum AlarmVoice: Codable, CaseIterable, Hashable, Identifiable {
    case basicTTS
    case premiumTTS
    case recorded
    case motivationalSound(MotivationalSound)

    var id: String {
        switch self {
        case .basicTTS:
            return "basicTTS"
        case .premiumTTS:
            return "premiumTTS"
        case .recorded:
            return "recorded"
        case .motivationalSound(let sound):
            return "motivational_" + sound.rawValue
        }
    }

    var title: String {
        switch self {
        case .basicTTS:
            return L10n.tr("voice.basic")
        case .premiumTTS:
            return L10n.tr("voice.natural")
        case .recorded:
            return L10n.tr("voice.recorded")
        case .motivationalSound(let sound):
            return sound.title
        }
    }

    var isProOnly: Bool {
        switch self {
        case .basicTTS:
            return false
        case .premiumTTS, .recorded:
            return true
        case .motivationalSound(let sound):
            return sound.isProOnly
        }
    }

    /// Returns the associated motivational sound if applicable
    var motivationalSound: MotivationalSound? {
        switch self {
        case .motivationalSound(let sound):
            return sound
        default:
            return nil
        }
    }
}
