import SQLiteData

func appDatabase() throws -> any DatabaseWriter {
    var configuration = Configuration()
    configuration.foreignKeysEnabled = true

    let database = try defaultDatabase(configuration: configuration)

    var migrator = DatabaseMigrator()
    #if DEBUG
    migrator.eraseDatabaseOnSchemaChange = true
    #endif

    migrator.registerMigration("Create tables") { db in
        try #sql(
            """
            CREATE TABLE "habit" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "name" TEXT NOT NULL,
              "modeRaw" TEXT NOT NULL,
              "characterIDRaw" TEXT NOT NULL,
              "countUnitRaw" TEXT NOT NULL,
              "baselineSourceRaw" TEXT NOT NULL,
              "baselineManualValue" REAL,
              "goalTypeRaw" TEXT NOT NULL,
              "goalValue" INTEGER,
              "goalDate" TEXT,
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
            CREATE TABLE "habitEvent" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "habitID" TEXT NOT NULL,
              "delta" INTEGER NOT NULL,
              "sourceRaw" TEXT NOT NULL,
              "occurredAt" TEXT NOT NULL,
              "revokedAt" TEXT,
              "createdAt" TEXT NOT NULL
            ) STRICT
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE INDEX "idx_habitEvent_habitID_occurredAt"
            ON "habitEvent"("habitID", "occurredAt")
            """
        )
        .execute(db)

        try #sql(
            """
            CREATE INDEX "idx_habitEvent_habitID_revokedAt"
            ON "habitEvent"("habitID", "revokedAt")
            """
        )
        .execute(db)
    }

    try migrator.migrate(database)
    return database
}
