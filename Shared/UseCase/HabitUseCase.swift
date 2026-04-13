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
    func resetAllData() throws
    func injectAppStoreScreenshotSampleData(now: Date) throws
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

    func resetAllData() throws {
        try habitEventDataStore.deleteAll()
        try habitDataStore.deleteAll()
    }

    func injectAppStoreScreenshotSampleData(now: Date = Date()) throws {
        try resetAllData()

        let calendar = Calendar.current
        let smokingCreatedAt = calendar.date(byAdding: .day, value: -42, to: now) ?? now
        let alcoholCreatedAt = calendar.date(byAdding: .day, value: -35, to: now) ?? now

        let smokingHabit = Habit(
            id: Habit.ID(),
            kind: .nonSmoking,
            character: .hamster,
            name: "綺麗な肺にするぞ！",
            goalDeadline: Self.goalDeadlineString(daysFromNow: 45, now: now),
            goalPerDay: 3,
            isArchived: false,
            sortOrder: 0,
            createdAt: smokingCreatedAt,
            updatedAt: now
        )
        let alcoholHabit = Habit(
            id: Habit.ID(),
            kind: .nonAlcohol,
            character: .rabbit,
            name: "朝スッキリ起きる！",
            goalDeadline: Self.goalDeadlineString(daysFromNow: 30, now: now),
            goalPerDay: 1,
            isArchived: false,
            sortOrder: 1,
            createdAt: alcoholCreatedAt,
            updatedAt: now
        )

        try habitDataStore.create(smokingHabit)
        try habitDataStore.create(alcoholHabit)

        let smokingSeries = Self.makeImprovementSeries(totalDays: 14, start: 6, end: 0)
        let alcoholSeries = Self.makeImprovementSeries(totalDays: 14, start: 3, end: 0)

        try createDailyEvents(
            habitID: smokingHabit.id,
            dailyCounts: smokingSeries,
            now: now
        )
        try createDailyEvents(
            habitID: alcoholHabit.id,
            dailyCounts: alcoholSeries,
            now: now
        )
    }

    private func createDailyEvents(habitID: Habit.ID, dailyCounts: [Int], now: Date) throws {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let count = dailyCounts.count

        for (index, dailyCount) in dailyCounts.enumerated() where dailyCount > 0 {
            let daysFromToday = -(count - 1 - index)
            guard
                let day = calendar.date(byAdding: .day, value: daysFromToday, to: startOfToday),
                let occurredAt = calendar.date(byAdding: .hour, value: 12, to: day)
            else {
                continue
            }

            let event = HabitEvent(
                id: HabitEvent.ID(),
                habitID: habitID,
                delta: dailyCount,
                source: .app,
                occurredAt: occurredAt,
                revokedAt: nil,
                createdAt: occurredAt
            )
            try habitEventDataStore.create(event)
        }
    }

    private static func goalDeadlineString(daysFromNow: Int, now: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(byAdding: .day, value: daysFromNow, to: now) ?? now
        return goalDeadlineFormatter.string(from: date)
    }

    private static func makeImprovementSeries(totalDays: Int, start: Int, end: Int) -> [Int] {
        guard totalDays > 0 else { return [] }
        guard totalDays > 1 else { return [max(start, 0)] }

        let clampedStart = max(start, 0)
        let clampedEnd = max(end, 0)
        let delta = Double(clampedEnd - clampedStart)
        let denominator = Double(totalDays - 1)

        return (0..<totalDays).map { index in
            let progress = Double(index) / denominator
            let value = Double(clampedStart) + (delta * progress)
            return max(Int(round(value)), 0)
        }
    }

    private static let goalDeadlineFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
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
