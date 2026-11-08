import GRDB

/// Frozen v1 schema, independent of the production migrator. Never add new columns here.
extension DatabaseMigrator {
    static var v1Fixture: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1-content-and-reviews") { database in
            try database.create(table: "deck") { table in
                table.primaryKey("id", .blob)
                table.column("name", .text).notNull()
                table.column("term_language", .text).notNull()
                table.column("meaning_language", .text).notNull()
            }
            try database.create(table: "note") { table in
                table.primaryKey("id", .blob)
                table.column("deck_id", .blob).notNull().indexed().references("deck")
                table.column("position", .integer).notNull()
                table.column("term", .text).notNull()
                table.column("meaning", .text).notNull()
                table.column("transcription", .text)
                table.column("example", .text)
            }
            try database.create(table: "note_media") { table in
                table.column("note_id", .blob).notNull().references("note", onDelete: .cascade)
                table.column("role", .text).notNull().check { ["image", "audio"].contains($0) }
                table.column("position", .integer).notNull()
                table.column("hash", .text).notNull().indexed()
                table.column("filename", .text).notNull()
                table.primaryKey(["note_id", "role", "position"])
            }
            try database.create(table: "card") { table in
                table.column("note_id", .blob).notNull().references("note")
                table.column("direction", .integer).notNull().check { [0, 1].contains($0) }
                v1Scheduling(table, prefix: "baseline_")
                table.primaryKey(["note_id", "direction"])
            }
            try database.create(table: "card_scheduling") { table in
                table.column("note_id", .blob).notNull()
                table.column("direction", .integer).notNull()
                v1Scheduling(table, prefix: "")
                table.primaryKey(["note_id", "direction"])
                table.foreignKey(["note_id", "direction"], references: "card", onDelete: .cascade)
            }
            try database.create(table: "practice_session") { table in
                table.primaryKey("id", .blob)
                table.column("deck_id", .blob).notNull().references("deck")
                table.column("opened_at", .integer).notNull()
                table.column("ended_at", .integer)
            }
            try database.create(index: "practice_session_open", on: "practice_session", columns: ["ended_at"])
            try database.create(table: "card_review_event") { table in
                table.primaryKey("idempotency_key", .blob)
                table.column("practice_session_id", .blob).indexed().references("practice_session")
                table.column("note_id", .blob).notNull()
                table.column("direction", .integer).notNull()
                table.column("rating", .integer).notNull().check { [1, 2, 3, 4].contains($0) }
                table.column("answered_at", .integer).notNull()
                table.foreignKey(["note_id", "direction"], references: "card")
            }
            try database.create(
                index: "card_review_event_card", on: "card_review_event",
                columns: ["note_id", "direction", "answered_at"])
        }
        return migrator
    }
}

private func v1Scheduling(_ table: TableDefinition, prefix: String) {
    table.column(prefix + "state", .integer).notNull().check { [0, 1, 2, 3].contains($0) }
    table.column(prefix + "due", .double).notNull()
    table.column(prefix + "stability", .double).notNull()
    table.column(prefix + "difficulty", .double).notNull()
    table.column(prefix + "elapsed_days", .double).notNull()
    table.column(prefix + "scheduled_days", .double).notNull()
    table.column(prefix + "learning_steps", .integer).notNull()
    table.column(prefix + "reps", .integer).notNull()
    table.column(prefix + "lapses", .integer).notNull()
    table.column(prefix + "last_review", .double)
    table.column(prefix + "checkpoint_answered_at", .integer)
    table.column(prefix + "checkpoint_key", .blob)
    table.column(prefix + "checkpoint_count", .integer)
    table.check(
        sql: """
            (\(prefix)checkpoint_answered_at IS NULL) = (\(prefix)checkpoint_key IS NULL)
            AND (\(prefix)checkpoint_key IS NULL) = (\(prefix)checkpoint_count IS NULL)
            """)
}
