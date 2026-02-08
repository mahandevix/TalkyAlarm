import Foundation

enum AlarmVoice: String, Codable, CaseIterable, Hashable, Identifiable {
    case basicTTS
    case premiumTTS
    case recorded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basicTTS:
            return L10n.tr("voice.basic")
        case .premiumTTS:
            return L10n.tr("voice.natural")
        case .recorded:
            return L10n.tr("voice.recorded")
        }
    }

    var isProOnly: Bool {
        self != .basicTTS
    }
}
