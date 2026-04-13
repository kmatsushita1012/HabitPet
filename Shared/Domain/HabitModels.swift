import Foundation
import SQLiteData

enum HabitKind: String, CaseIterable, Sendable, Codable, QueryBindable {
    case nonSmoking
    case nonAlcohol
    case nonGambling
    case other

    var title: String {
        switch self {
        case .nonSmoking: "禁煙"
        case .nonAlcohol: "禁酒"
        case .nonGambling: "脱ギャンブル"
        case .other: "その他"
        }
    }

    var unitTitle: String {
        switch self {
        case .nonSmoking: "本"
        case .nonAlcohol: "杯"
        case .nonGambling: "回"
        case .other: "回"
        }
    }
}

private enum HabitKindFeatureFlags {
    static let nonGamblingEnabled = false
    static let otherEnabled = false
}

extension HabitKind {
    static var selectableKinds: [HabitKind] {
        var kinds: [HabitKind] = [.nonSmoking, .nonAlcohol]
        if HabitKindFeatureFlags.nonGamblingEnabled {
            kinds.append(.nonGambling)
        }
        if HabitKindFeatureFlags.otherEnabled {
            kinds.append(.other)
        }
        return kinds
    }

    static func selectableKinds(including current: HabitKind) -> [HabitKind] {
        var kinds = selectableKinds
        if !kinds.contains(current) {
            kinds.insert(current, at: 0)
        }
        return kinds
    }
}

enum CharacterType: String, CaseIterable, Sendable, Codable, QueryBindable {
    case hamster
    case fox
    case cat
    case rabbit

    var title: String {
        switch self {
        case .hamster: "ハムスター"
        case .fox: "キツネ"
        case .cat: "ネコ"
        case .rabbit: "ウサギ"
        }
    }
}

extension CharacterType {
    static func candidates(for kind: HabitKind) -> [CharacterType] {
        switch kind {
        case .nonSmoking:
            return [.hamster, .rabbit]
        case .nonAlcohol:
            return [.hamster, .rabbit]
        case .nonGambling:
            return [.fox, .cat]
        case .other:
            return Self.allCases
        }
    }
}

enum HabitEventSource: String, CaseIterable, Sendable, Codable, QueryBindable {
    case app
    case widget
    case setup
}

@Table
struct Habit: Sendable, Identifiable {
    typealias ID = UUID

    var id: Habit.ID
    var kind: HabitKind
    var character: CharacterType
    var name: String?
    var goalDeadline: String
    var goalPerDay: Int
    var isArchived: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
}

@Table
struct HabitEvent: Sendable, Identifiable {
    typealias ID = UUID

    var id: HabitEvent.ID
    var habitID: Habit.ID
    var delta: Int
    var source: HabitEventSource
    var occurredAt: Date
    var revokedAt: Date?
    var createdAt: Date
}

func habitStateLevel(forTotalCount totalCount: Int) -> Int {
    switch totalCount {
    case ..<5:
        return 1
    case ..<10:
        return 2
    case ..<20:
        return 3
    case ..<30:
        return 4
    default:
        return 5
    }
}

func habitCharacterAssetNames(kind: HabitKind, character: CharacterType, level: Int) -> [String] {
    let clampedLevel = min(max(level, 1), 5)
    return [
        "character_\(kind.rawValue)_\(character.rawValue)_lv\(clampedLevel)",
        "character_\(character.rawValue)_lv\(clampedLevel)",
    ]
}
