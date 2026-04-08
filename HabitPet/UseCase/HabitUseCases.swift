import Dependencies
import Foundation

struct HabitDraft: Sendable {
    var name: String
    var modeRaw: String
    var characterIDRaw: String
    var countUnitRaw: String
    var baselineSourceRaw: String
    var baselineManualValue: Double?
    var goalTypeRaw: String
    var goalValue: Int?
    var goalDate: String?
    var sortOrder: Int
}

protocol CreateHabitUseCaseProtocol: Sendable {
    func execute(_ draft: HabitDraft, now: Date) throws -> Habit
}

struct CreateHabitUseCase: CreateHabitUseCaseProtocol, Sendable {
    @Dependency(\.habitDataStore) private var habitDataStore

    func execute(_ draft: HabitDraft, now: Date = Date()) throws -> Habit {
        let habit = Habit(
            id: UUID(),
            name: draft.name,
            modeRaw: draft.modeRaw,
            characterIDRaw: draft.characterIDRaw,
            countUnitRaw: draft.countUnitRaw,
            baselineSourceRaw: draft.baselineSourceRaw,
            baselineManualValue: draft.baselineManualValue,
            goalTypeRaw: draft.goalTypeRaw,
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
}

protocol UpdateHabitUseCaseProtocol: Sendable {
    func execute(_ habit: Habit, now: Date) throws
}

struct UpdateHabitUseCase: UpdateHabitUseCaseProtocol, Sendable {
    @Dependency(\.habitDataStore) private var habitDataStore

    func execute(_ habit: Habit, now: Date = Date()) throws {
        var updated = habit
        updated.updatedAt = now
        try habitDataStore.update(updated)
    }
}

protocol ArchiveHabitUseCaseProtocol: Sendable {
    func execute(_ habit: Habit, now: Date) throws
}

struct ArchiveHabitUseCase: ArchiveHabitUseCaseProtocol, Sendable {
    @Dependency(\.habitDataStore) private var habitDataStore

    func execute(_ habit: Habit, now: Date = Date()) throws {
        var archived = habit
        archived.isArchived = true
        archived.updatedAt = now
        try habitDataStore.update(archived)
    }
}

protocol RecordHabitDeltaUseCaseProtocol: Sendable {
    func execute(habitID: UUID, delta: Int, sourceRaw: String, now: Date) throws
}

struct RecordHabitDeltaUseCase: RecordHabitDeltaUseCaseProtocol, Sendable {
    @Dependency(\.habitEventDataStore) private var habitEventDataStore

    func execute(habitID: UUID, delta: Int, sourceRaw: String, now: Date = Date()) throws {
        let event = HabitEvent(
            id: UUID(),
            habitID: habitID,
            delta: delta,
            sourceRaw: sourceRaw,
            occurredAt: now,
            revokedAt: nil,
            createdAt: now
        )
        try habitEventDataStore.create(event)
    }
}

protocol UndoHabitDeltaUseCaseProtocol: Sendable {
    func execute(habitID: UUID, count: Int, now: Date) throws
}

struct UndoHabitDeltaUseCase: UndoHabitDeltaUseCaseProtocol, Sendable {
    @Dependency(\.habitEventDataStore) private var habitEventDataStore

    func execute(habitID: UUID, count: Int, now: Date = Date()) throws {
        try habitEventDataStore.revokeLast(habitID: habitID, count: count, now: now)
    }
}

protocol ResolveHabitStateUseCaseProtocol: Sendable {
    func execute(todayUsage: Int, baseline: Double) -> Int
}

struct ResolveHabitStateUseCase: ResolveHabitStateUseCaseProtocol, Sendable {
    func execute(todayUsage: Int, baseline: Double) -> Int {
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

private enum CreateHabitUseCaseKey: DependencyKey {
    static let liveValue: any CreateHabitUseCaseProtocol = CreateHabitUseCase()
}

private enum UpdateHabitUseCaseKey: DependencyKey {
    static let liveValue: any UpdateHabitUseCaseProtocol = UpdateHabitUseCase()
}

private enum ArchiveHabitUseCaseKey: DependencyKey {
    static let liveValue: any ArchiveHabitUseCaseProtocol = ArchiveHabitUseCase()
}

private enum RecordHabitDeltaUseCaseKey: DependencyKey {
    static let liveValue: any RecordHabitDeltaUseCaseProtocol = RecordHabitDeltaUseCase()
}

private enum UndoHabitDeltaUseCaseKey: DependencyKey {
    static let liveValue: any UndoHabitDeltaUseCaseProtocol = UndoHabitDeltaUseCase()
}

private enum ResolveHabitStateUseCaseKey: DependencyKey {
    static let liveValue: any ResolveHabitStateUseCaseProtocol = ResolveHabitStateUseCase()
}

extension DependencyValues {
    var createHabitUseCase: any CreateHabitUseCaseProtocol {
        get { self[CreateHabitUseCaseKey.self] }
        set { self[CreateHabitUseCaseKey.self] = newValue }
    }

    var updateHabitUseCase: any UpdateHabitUseCaseProtocol {
        get { self[UpdateHabitUseCaseKey.self] }
        set { self[UpdateHabitUseCaseKey.self] = newValue }
    }

    var archiveHabitUseCase: any ArchiveHabitUseCaseProtocol {
        get { self[ArchiveHabitUseCaseKey.self] }
        set { self[ArchiveHabitUseCaseKey.self] = newValue }
    }

    var recordHabitDeltaUseCase: any RecordHabitDeltaUseCaseProtocol {
        get { self[RecordHabitDeltaUseCaseKey.self] }
        set { self[RecordHabitDeltaUseCaseKey.self] = newValue }
    }

    var undoHabitDeltaUseCase: any UndoHabitDeltaUseCaseProtocol {
        get { self[UndoHabitDeltaUseCaseKey.self] }
        set { self[UndoHabitDeltaUseCaseKey.self] = newValue }
    }

    var resolveHabitStateUseCase: any ResolveHabitStateUseCaseProtocol {
        get { self[ResolveHabitStateUseCaseKey.self] }
        set { self[ResolveHabitStateUseCaseKey.self] = newValue }
    }
}
