import Foundation

/// Represents a physical challenge that must be completed to dismiss an alarm
enum PhysicalChallenge: String, Codable, CaseIterable, Hashable, Identifiable {
    case pushUps
    case squats
    case plank

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pushUps:
            return L10n.tr("challenge.push_ups")
        case .squats:
            return L10n.tr("challenge.squats")
        case .plank:
            return L10n.tr("challenge.plank")
        }
    }

    var description: String {
        switch self {
        case .pushUps:
            return L10n.tr("challenge.push_ups_description")
        case .squats:
            return L10n.tr("challenge.squats_description")
        case .plank:
            return L10n.tr("challenge.plank_description")
        }
    }

    /// Default number of repetitions or duration for the challenge
    var defaultTarget: Int {
        switch self {
        case .pushUps:
            return 10
        case .squats:
            return 15
        case .plank:
            return 30 // seconds
        }
    }

    /// Unit for the challenge (reps or seconds)
    var unit: String {
        switch self {
        case .pushUps, .squats:
            return L10n.tr("challenge.unit_reps")
        case .plank:
            return L10n.tr("challenge.unit_seconds")
        }
    }

    /// Whether this is a duration-based challenge (plank) or repetition-based
    var isDurationBased: Bool {
        self == .plank
    }
}
