import Dependencies
import Foundation
import SQLiteData

protocol HabitEventDataStoreProtocol: Sendable {
    func create(_ event: HabitEvent) throws
    func update(_ event: HabitEvent) throws
    func delete(id: HabitEvent.ID) throws
    func revokeLast(habitID: Habit.ID, count: Int, now: Date) throws
}

struct HabitEventDataStore: HabitEventDataStoreProtocol, Sendable {
    func create(_ event: HabitEvent) throws {
        @Dependency(\.defaultDatabase) var database
        try database.write { db in
            try HabitEvent.insert { event }.execute(db)
        }
    }

    func update(_ event: HabitEvent) throws {
        @Dependency(\.defaultDatabase) var database
        try database.write { db in
            try HabitEvent.upsert { event }.execute(db)
        }
    }

    func delete(id: HabitEvent.ID) throws {
        @Dependency(\.defaultDatabase) var database
        try database.write { db in
            try HabitEvent.where { $0.id.eq(id) }.delete().execute(db)
        }
    }

    func revokeLast(habitID: Habit.ID, count: Int, now: Date) throws {
        guard count > 0 else { return }

        @Dependency(\.defaultDatabase) var database
        try database.write { db in
            let latestEvents = try HabitEvent
                .where { $0.habitID.eq(habitID).and($0.revokedAt.eq(nil as Date?)) }
                .order { $0.occurredAt.desc() }
                .limit(count)
                .fetchAll(db)

            for var event in latestEvents {
                event.revokedAt = now
                try HabitEvent.upsert { event }.execute(db)
            }
        }
    }
}

private enum HabitEventDataStoreKey: DependencyKey {
    static let liveValue: any HabitEventDataStoreProtocol = HabitEventDataStore()
}

extension DependencyValues {
    var habitEventDataStore: any HabitEventDataStoreProtocol {
        get { self[HabitEventDataStoreKey.self] }
        set { self[HabitEventDataStoreKey.self] = newValue }
    }
}
