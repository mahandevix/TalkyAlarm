import Foundation

/// Represents motivational sounds that can be used for alarms
enum MotivationalSound: String, Codable, CaseIterable, Hashable, Identifiable {
    // Nature sounds
    case oceanWaves
    case rain
    case birds
    case forest
    case sunrise

    // English motivational sentences
    case wakeUpAndShine
    case todayIsYourDay
    case riseAndGrind
    case makeItHappen
    case youGotThis

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oceanWaves:
            return L10n.tr("sound.ocean_waves")
        case .rain:
            return L10n.tr("sound.rain")
        case .birds:
            return L10n.tr("sound.birds")
        case .forest:
            return L10n.tr("sound.forest")
        case .sunrise:
            return L10n.tr("sound.sunrise")
        case .wakeUpAndShine:
            return L10n.tr("sound.wake_up_and_shine")
        case .todayIsYourDay:
            return L10n.tr("sound.today_is_your_day")
        case .riseAndGrind:
            return L10n.tr("sound.rise_and_grind")
        case .makeItHappen:
            return L10n.tr("sound.make_it_happen")
        case .youGotThis:
            return L10n.tr("sound.you_got_this")
        }
    }

    var sentence: String {
        switch self {
        case .oceanWaves:
            return L10n.tr("sound.sentence.ocean_waves")
        case .rain:
            return L10n.tr("sound.sentence.rain")
        case .birds:
            return L10n.tr("sound.sentence.birds")
        case .forest:
            return L10n.tr("sound.sentence.forest")
        case .sunrise:
            return L10n.tr("sound.sentence.sunrise")
        case .wakeUpAndShine:
            return L10n.tr("sound.sentence.wake_up_and_shine")
        case .todayIsYourDay:
            return L10n.tr("sound.sentence.today_is_your_day")
        case .riseAndGrind:
            return L10n.tr("sound.sentence.rise_and_grind")
        case .makeItHappen:
            return L10n.tr("sound.sentence.make_it_happen")
        case .youGotThis:
            return L10n.tr("sound.sentence.you_got_this")
        }
    }

    /// Category for grouping sounds in the UI
    var category: String {
        switch self {
        case .oceanWaves, .rain, .birds, .forest, .sunrise:
            return L10n.tr("sound.category.nature")
        case .wakeUpAndShine, .todayIsYourDay, .riseAndGrind, .makeItHappen, .youGotThis:
            return L10n.tr("sound.category.motivational")
        }
    }

    /// Whether this sound is only available in Pro tier
    var isProOnly: Bool {
        switch self {
        case .oceanWaves, .rain, .birds:
            return false
        case .forest, .sunrise, .wakeUpAndShine, .todayIsYourDay, .riseAndGrind, .makeItHappen, .youGotThis:
            return true
        }
    }

    /// All available categories
    static var categories: [String] {
        [
            L10n.tr("sound.category.nature"),
            L10n.tr("sound.category.motivational")
        ]
    }

    /// Get all sounds in a specific category
    static func sounds(in category: String) -> [MotivationalSound] {
        allCases.filter { $0.category == category }
    }
}
