import Foundation

enum AlarmRepeatRule: Hashable {
    case once
    case daily
    case weekdays
    case customDays([Int])
    case everyXHours(Int)
    case everyXDays(Int)
}

extension AlarmRepeatRule: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case days
        case interval
    }

    private enum Kind: String, Codable {
        case once
        case daily
        case weekdays
        case customDays
        case everyXHours
        case everyXDays
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .once:
            try container.encode(Kind.once, forKey: .type)
        case .daily:
            try container.encode(Kind.daily, forKey: .type)
        case .weekdays:
            try container.encode(Kind.weekdays, forKey: .type)
        case .customDays(let days):
            try container.encode(Kind.customDays, forKey: .type)
            try container.encode(days, forKey: .days)
        case .everyXHours(let interval):
            try container.encode(Kind.everyXHours, forKey: .type)
            try container.encode(interval, forKey: .interval)
        case .everyXDays(let interval):
            try container.encode(Kind.everyXDays, forKey: .type)
            try container.encode(interval, forKey: .interval)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(Kind.self, forKey: .type)

        switch type {
        case .once:
            self = .once
        case .daily:
            self = .daily
        case .weekdays:
            self = .weekdays
        case .customDays:
            self = .customDays(try container.decode([Int].self, forKey: .days))
        case .everyXHours:
            self = .everyXHours(try container.decode(Int.self, forKey: .interval))
        case .everyXDays:
            self = .everyXDays(try container.decode(Int.self, forKey: .interval))
        }
    }
}

extension AlarmRepeatRule {
    var isProOnly: Bool {
        switch self {
        case .everyXHours, .everyXDays:
            return true
        case .once, .daily, .weekdays, .customDays:
            return false
        }
    }

    var label: String {
        switch self {
        case .once:
            return L10n.tr("repeat.once")
        case .daily:
            return L10n.tr("repeat.daily")
        case .weekdays:
            return L10n.tr("repeat.weekdays")
        case .customDays(let days):
            if days.isEmpty {
                return L10n.tr("repeat.custom_days")
            }
            let symbols = days
                .sorted()
                .compactMap { Calendar.current.shortWeekdaySymbols[safe: max(1, min(7, $0)) - 1] }
            return ListFormatter.localizedString(byJoining: symbols)
        case .everyXHours(let interval):
            if interval == 1 {
                return L10n.format("repeat.every_x_hour", interval)
            }
            return L10n.format("repeat.every_x_hours", interval)
        case .everyXDays(let interval):
            if interval == 1 {
                return L10n.format("repeat.every_x_day", interval)
            }
            return L10n.format("repeat.every_x_days", interval)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
