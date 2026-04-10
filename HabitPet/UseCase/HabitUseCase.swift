import Dependencies
import Foundation

struct HabitDraft: Sendable {
    var name: String
    var mode: HabitMode
    var characterID: String
    var countUnit: HabitCountUnit
    var baselineSource: HabitBaselineSource
    var baselineManualValue: Double?
    var goalType: HabitGoalType
    var goalValue: Int?
    var goalDate: String?
    var sortOrder: Int
}

protocol HabitUseCaseProtocol: Sendable {
    func createHabit(_ draft: HabitDraft, now: Date) throws -> Habit
    func updateHabit(_ habit: Habit, now: Date) throws
    func archiveHabit(_ habit: Habit, now: Date) throws
    func recordDelta(habitID: Habit.ID, delta: Int, source: HabitEventSource, now: Date) throws
    func undoDelta(habitID: Habit.ID, count: Int, now: Date) throws
    func resolveStateLevel(todayUsage: Int, baseline: Double) -> Int
}

struct HabitUseCase: HabitUseCaseProtocol, Sendable {
    @Dependency(\.habitDataStore) private var habitDataStore
    @Dependency(\.habitEventDataStore) private var habitEventDataStore

    func createHabit(_ draft: HabitDraft, now: Date = Date()) throws -> Habit {
        let habit = Habit(
            id: Habit.ID(),
            name: draft.name,
            mode: draft.mode,
            characterID: draft.characterID,
            countUnit: draft.countUnit,
            baselineSource: draft.baselineSource,
            baselineManualValue: draft.baselineManualValue,
            goalType: draft.goalType,
            goalValue: draft.goalValue,
            goalDate: draft.goalDate,
            isArchived: false,
            sortOrder: draft.sortOrder,
            createdAt: now,
            updatedAt: now
        )
        try habitDataStore.create(habit)
        return habit
    }

    func updateHabit(_ habit: Habit, now: Date = Date()) throws {
        var updated = habit
        updated.updatedAt = now
        try habitDataStore.update(updated)
    }

    func archiveHabit(_ habit: Habit, now: Date = Date()) throws {
        var archived = habit
        archived.isArchived = true
        archived.updatedAt = now
        try habitDataStore.update(archived)
    }

    func recordDelta(habitID: Habit.ID, delta: Int, source: HabitEventSource, now: Date = Date()) throws {
        let event = HabitEvent(
            id: HabitEvent.ID(),
            habitID: habitID,
            delta: delta,
            source: source,
            occurredAt: now,
            revokedAt: nil,
            createdAt: now
        )
        try habitEventDataStore.create(event)
    }

    func undoDelta(habitID: Habit.ID, count: Int, now: Date = Date()) throws {
        try habitEventDataStore.revokeLast(habitID: habitID, count: count, now: now)
    }

    func resolveStateLevel(todayUsage: Int, baseline: Double) -> Int {
        guard baseline > 0 else { return 1 }
        let ratio = Double(todayUsage) / baseline
        switch ratio {
        case ..<0.25:
            return 1
        case ..<0.5:
            return 2
        case ..<0.75:
            return 3
        case ..<1.0:
            return 4
        default:
            return 5
        }
    }
}

private enum HabitUseCaseKey: DependencyKey {
    static let liveValue: any HabitUseCaseProtocol = HabitUseCase()
}

extension DependencyValues {
    var habitUseCase: any HabitUseCaseProtocol {
        get { self[HabitUseCaseKey.self] }
        set { self[HabitUseCaseKey.self] = newValue }
    }
}
