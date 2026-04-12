import Dependencies
import Foundation

struct HabitDraft: Sendable {
    var kind: HabitKind
    var character: CharacterType
    var name: String?
    var goalDeadline: String
    var goalPerDay: Int
    var sortOrder: Int
}

protocol HabitUseCaseProtocol: Sendable {
    func createHabit(_ draft: HabitDraft, yesterdayCount: Int, now: Date) throws -> Habit
    func updateHabit(_ habit: Habit, now: Date) throws
    func archiveHabit(_ habit: Habit, now: Date) throws
    func deleteHabit(_ habit: Habit) throws
    func recordDelta(habitID: Habit.ID, delta: Int, source: HabitEventSource, now: Date) throws
    func undoDelta(habitID: Habit.ID, count: Int, now: Date) throws
}

struct HabitUseCase: HabitUseCaseProtocol, Sendable {
    @Dependency(\.habitDataStore) private var habitDataStore
    @Dependency(\.habitEventDataStore) private var habitEventDataStore

    func createHabit(_ draft: HabitDraft, yesterdayCount: Int = 0, now: Date = Date()) throws -> Habit {
        let habit = Habit(
            id: Habit.ID(),
            kind: draft.kind,
            character: draft.character,
            name: draft.name,
            goalDeadline: draft.goalDeadline,
            goalPerDay: max(0, draft.goalPerDay),
            isArchived: false,
            sortOrder: draft.sortOrder,
            createdAt: now,
            updatedAt: now
        )
        try habitDataStore.create(habit)

        if yesterdayCount > 0 {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
            let setupEvent = HabitEvent(
                id: HabitEvent.ID(),
                habitID: habit.id,
                delta: yesterdayCount,
                source: .setup,
                occurredAt: yesterday,
                revokedAt: nil,
                createdAt: now
            )
            try habitEventDataStore.create(setupEvent)
        }

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

    func deleteHabit(_ habit: Habit) throws {
        try habitDataStore.delete(id: habit.id)
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
