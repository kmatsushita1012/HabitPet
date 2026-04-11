import Foundation
import SQLiteData

func appDatabase() throws -> any DatabaseWriter {
    var configuration = Configuration()
    configuration.foreignKeysEnabled = true

    let database = try makeDefaultDatabase(configuration: configuration)
    let migrator = makeDatabaseMigrator()
    try migrator.migrate(database)
    return database
}

nonisolated private func makeDefaultDatabase(configuration: Configuration) throws -> DatabaseQueue {
    let databaseURL = try appGroupDatabaseURL()
    return try DatabaseQueue(path: databaseURL.path(), configuration: configuration)
}

nonisolated private func makeDatabaseMigrator() -> DatabaseMigrator {
    var migrator = DatabaseMigrator()
    #if DEBUG
    migrator.eraseDatabaseOnSchemaChange = true
    #endif

    migrator.registerMigration("Create tables") { db in
        try createTables(in: db)
    }

    return migrator
}

nonisolated private func createTables(in db: Database) throws {
    try #sql(
        """
        CREATE TABLE IF NOT EXISTS "habits" (
          "id" TEXT NOT NULL PRIMARY KEY,
          "kind" TEXT NOT NULL,
          "character" TEXT NOT NULL,
          "name" TEXT,
          "goalDeadline" TEXT NOT NULL,
          "goalPerDay" INTEGER NOT NULL,
          "isArchived" INTEGER NOT NULL,
          "sortOrder" INTEGER NOT NULL,
          "createdAt" TEXT NOT NULL,
          "updatedAt" TEXT NOT NULL
        ) STRICT
        """
    )
    .execute(db)

    try #sql(
        """
        CREATE TABLE IF NOT EXISTS "habitEvents" (
          "id" TEXT NOT NULL PRIMARY KEY,
          "habitID" TEXT NOT NULL,
          "delta" INTEGER NOT NULL,
          "source" TEXT NOT NULL,
          "occurredAt" TEXT NOT NULL,
          "revokedAt" TEXT,
          "createdAt" TEXT NOT NULL
        ) STRICT
        """
    )
    .execute(db)

    try #sql(
        """
        CREATE INDEX IF NOT EXISTS "idx_habitEvents_habitID_occurredAt"
        ON "habitEvents"("habitID", "occurredAt")
        """
    )
    .execute(db)

    try #sql(
        """
        CREATE INDEX IF NOT EXISTS "idx_habitEvents_habitID_revokedAt"
        ON "habitEvents"("habitID", "revokedAt")
        """
    )
    .execute(db)
}

nonisolated private func appGroupDatabaseURL() throws -> URL {
    let appGroupID = "group.com.studiomk.HabitPet"
    guard let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupID
    ) else {
        throw NSError(
            domain: "AppDatabase",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "App Group container is unavailable: \(appGroupID)"]
        )
    }
    return containerURL.appending(path: "habitpet.sqlite")
}
