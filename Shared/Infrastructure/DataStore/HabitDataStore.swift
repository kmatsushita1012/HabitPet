import Dependencies
import Foundation
import SQLiteData

protocol HabitDataStoreProtocol: Sendable {
    func create(_ habit: Habit) throws
    func update(_ habit: Habit) throws
    func delete(id: Habit.ID) throws
    func upsert(_ habit: Habit) throws
}

struct HabitDataStore: HabitDataStoreProtocol, Sendable {
    func create(_ habit: Habit) throws {
        @Dependency(\.defaultDatabase) var database
        try database.write { db in
            try Habit.insert { habit }.execute(db)
        }
    }

    func update(_ habit: Habit) throws {
        @Dependency(\.defaultDatabase) var database
        try database.write { db in
            try Habit.upsert { habit }.execute(db)
        }
    }

    func delete(id: Habit.ID) throws {
        @Dependency(\.defaultDatabase) var database
        try database.write { db in
            try Habit.where { $0.id.eq(id) }.delete().execute(db)
        }
    }

    func upsert(_ habit: Habit) throws {
        @Dependency(\.defaultDatabase) var database
        try database.write { db in
            try Habit.upsert { habit }.execute(db)
        }
    }
}

private enum HabitDataStoreKey: DependencyKey {
    static let liveValue: any HabitDataStoreProtocol = HabitDataStore()
}

extension DependencyValues {
    var habitDataStore: any HabitDataStoreProtocol {
        get { self[HabitDataStoreKey.self] }
        set { self[HabitDataStoreKey.self] = newValue }
    }
}
