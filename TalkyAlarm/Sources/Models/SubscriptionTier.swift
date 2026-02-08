import Foundation

enum SubscriptionTier {
    case free
    case pro

    var maxAlarms: Int {
        switch self {
        case .free:
            return 3
        case .pro:
            return .max
        }
    }
}
