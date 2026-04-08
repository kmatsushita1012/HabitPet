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
    var id: UUID
    var name: String
    var modeRaw: String
    var characterIDRaw: String
    var countUnitRaw: String
    var baselineSourceRaw: String
    var baselineManualValue: Double?
    var goalTypeRaw: String
    var goalValue: Int?
    var goalDate: String?
    var isArchived: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
}

@Table
struct HabitEvent: Sendable, Identifiable {
    var id: UUID
    var habitID: UUID
    var delta: Int
    var sourceRaw: String
    var occurredAt: Date
    var revokedAt: Date?
    var createdAt: Date
}

@Selection
struct HabitRecentEventSelection: Sendable, Identifiable {
    var event: HabitEvent

    var id: UUID { event.id }
}

@Selection
struct HabitTodayUsageSelection: Sendable, Identifiable {
    var habitID: UUID
    var todayUsage: Int

    var id: UUID { habitID }
}

@Selection
struct HabitBaselineSelection: Sendable, Identifiable {
    var habitID: UUID
    var baseline: Double

    var id: UUID { habitID }
}

@Selection
struct HabitStateSelection: Sendable, Identifiable {
    var habitID: UUID
    var stateLevel: Int
    var baseline: Double
    var todayUsage: Int

    var id: UUID { habitID }
}

@Selection
struct HabitCardSelection: Sendable, Identifiable {
    var habit: Habit
    var todayUsage: Int
    var stateLevel: Int

    var id: UUID { habit.id }
}
