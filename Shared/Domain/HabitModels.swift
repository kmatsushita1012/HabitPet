import Foundation
import SQLiteData

enum HabitMode: String, CaseIterable, Sendable, Codable, QueryBindable {
    case avoid
    case doMore
}

enum HabitCountUnit: String, CaseIterable, Sendable, Codable, QueryBindable {
    case count
    case minute
    case hour
}

enum HabitBaselineSource: String, CaseIterable, Sendable, Codable, QueryBindable {
    case manual
    case rolling7
}

enum HabitGoalType: String, CaseIterable, Sendable, Codable, QueryBindable {
    case none
    case count
    case date
}

enum HabitEventSource: String, CaseIterable, Sendable, Codable, QueryBindable {
    case app
    case widget
}

@Table
struct Habit: Sendable, Identifiable {
    typealias ID = UUID

    var id: Habit.ID
    var name: String
    var mode: HabitMode
    var characterID: String
    var countUnit: HabitCountUnit
    var baselineSource: HabitBaselineSource
    var baselineManualValue: Double?
    var goalType: HabitGoalType
    var goalValue: Int?
    var goalDate: String?
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

@Selection
struct HabitRecentEventSelection: Sendable, Identifiable {
    var event: HabitEvent

    var id: HabitEvent.ID { event.id }
}

@Selection
struct HabitTodayUsageSelection: Sendable, Identifiable {
    var habitID: Habit.ID
    var todayUsage: Int

    var id: Habit.ID { habitID }
}

@Selection
struct HabitBaselineSelection: Sendable, Identifiable {
    var habitID: Habit.ID
    var baseline: Double

    var id: Habit.ID { habitID }
}

@Selection
struct HabitStateSelection: Sendable, Identifiable {
    var habitID: Habit.ID
    var stateLevel: Int
    var baseline: Double
    var todayUsage: Int

    var id: Habit.ID { habitID }
}

@Selection
struct HabitCardSelection: Sendable, Identifiable {
    var habit: Habit
    var todayUsage: Int
    var stateLevel: Int

    var id: Habit.ID { habit.id }
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
