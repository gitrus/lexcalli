// Preserve the short local names in the shipped migration without changing its source.
// swiftlint:disable identifier_name
import GRDB

/// Append-only: never edit a shipped migration. Each runs in its own transaction.
extension DatabaseMigrator {
    static var lexcalli: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1-content-and-reviews", migrate: createContentAndReviews)
        migrator.registerMigration("v2-exercise-attempts") { db in
            try db.create(index: "practice_session_deck", on: "practice_session", columns: ["deck_id"])
            try db.alter(table: "practice_session") { table in
                table.add(column: "mode", .integer).notNull().defaults(to: 0).check { [0, 1].contains($0) }
            }
            try db.create(table: "exercise_event") { table in
                table.primaryKey("idempotency_key", .blob)
                table.column("practice_session_id", .blob).notNull().indexed().references("practice_session")
                table.column("note_id", .blob).notNull()
                table.column("direction", .integer).notNull()
                table.column("answered_at", .integer).notNull()
                // Versioned Codable snapshot includes ordered options, references and target identity.
                table.column("payload", .blob).notNull()
                table.foreignKey(["note_id", "direction"], references: "card")
            }
        }
        return migrator
    }
}

/// Keys are the domain identities. Event times are whole milliseconds; due dates are exact seconds.
private func createContentAndReviews(_ db: Database) throws {
    try db.create(table: "deck") { t in
        t.primaryKey("id", .blob)
        t.column("name", .text).notNull()
        t.column("term_language", .text).notNull()
        t.column("meaning_language", .text).notNull()
    }

    try db.create(table: "note") { t in
        t.primaryKey("id", .blob)
        t.column("deck_id", .blob).notNull().indexed().references("deck")
        t.column("position", .integer).notNull()
        t.column("term", .text).notNull()
        t.column("meaning", .text).notNull()
        t.column("transcription", .text)
        t.column("example", .text)
    }

    // Relative references; files live in the media library.
    try db.create(table: "note_media") { t in
        t.column("note_id", .blob).notNull().references("note", onDelete: .cascade)
        t.column("role", .text).notNull().check { ["image", "audio"].contains($0) }
        t.column("position", .integer).notNull()
        t.column("hash", .text).notNull().indexed()
        t.column("filename", .text).notNull()
        t.primaryKey(["note_id", "role", "position"])
    }

    // A card and its baseline, where rebuilding starts.
    try db.create(table: "card") { t in
        t.column("note_id", .blob).notNull().references("note")
        t.column("direction", .integer).notNull().check { [0, 1].contains($0) }
        schedulingColumns(t, prefix: "baseline_")
        checkpointColumns(t, prefix: "baseline_")
        t.primaryKey(["note_id", "direction"])
    }

    // Recomputable: a schema change may drop and rebuild it.
    try db.create(table: "card_scheduling") { t in
        t.column("note_id", .blob).notNull()
        t.column("direction", .integer).notNull()
        schedulingColumns(t, prefix: "")
        checkpointColumns(t, prefix: "")
        t.primaryKey(["note_id", "direction"])
        t.foreignKey(["note_id", "direction"], references: "card", onDelete: .cascade)
    }

    try db.create(table: "practice_session") { t in
        t.primaryKey("id", .blob)
        t.column("deck_id", .blob).notNull().references("deck")
        t.column("opened_at", .integer).notNull()
        t.column("ended_at", .integer)
    }
    try db.create(index: "practice_session_open", on: "practice_session", columns: ["ended_at"])

    // Append-only.
    try db.create(table: "card_review_event") { t in
        t.primaryKey("idempotency_key", .blob)
        t.column("practice_session_id", .blob).indexed().references("practice_session")
        t.column("note_id", .blob).notNull()
        t.column("direction", .integer).notNull()
        t.column("rating", .integer).notNull().check { [1, 2, 3, 4].contains($0) }
        t.column("answered_at", .integer).notNull()
        t.foreignKey(["note_id", "direction"], references: "card")
    }
    try db.create(
        index: "card_review_event_card", on: "card_review_event", columns: ["note_id", "direction", "answered_at"])
}

private func schedulingColumns(_ t: TableDefinition, prefix: String) {
    t.column(prefix + "state", .integer).notNull().check { [0, 1, 2, 3].contains($0) }
    t.column(prefix + "due", .double).notNull()
    t.column(prefix + "stability", .double).notNull()
    t.column(prefix + "difficulty", .double).notNull()
    t.column(prefix + "elapsed_days", .double).notNull()
    t.column(prefix + "scheduled_days", .double).notNull()
    t.column(prefix + "learning_steps", .integer).notNull()
    t.column(prefix + "reps", .integer).notNull()
    t.column(prefix + "lapses", .integer).notNull()
    t.column(prefix + "last_review", .double)
}

/// All set or all null.
private func checkpointColumns(_ t: TableDefinition, prefix: String) {
    t.column(prefix + "checkpoint_answered_at", .integer)
    t.column(prefix + "checkpoint_key", .blob)
    t.column(prefix + "checkpoint_count", .integer)
    t.check(
        sql: """
            (\(prefix)checkpoint_answered_at IS NULL) = (\(prefix)checkpoint_key IS NULL)
            AND (\(prefix)checkpoint_key IS NULL) = (\(prefix)checkpoint_count IS NULL)
            """)
}
