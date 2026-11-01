# Data management

How Lexcalli stores data on device, keeps it correct, and passes it to SwiftUI views. Terms are defined in the [glossary](glossary.md).
[Data layering](data-layering.md) defines *what* data exists and who owns it; this document covers *how* the iOS app holds it.

The guidance comes from the project's installed skills (SwiftUI Expert, Swift Concurrency), from Apple, Android, and SQLite documentation, and from articles current as of October 2026; see [Sources](#sources).


## Principles

- **Durable data has one authoritative representation.** The UI, sync, and learning-data import/export consume or transform it; none of them keeps its own copy as a second source of truth.
- **Commands travel toward storage; observed state travels back to views.** A view never edits durable data in place. It sends a command (`submit a review`, `rename a deck`) and re-renders from what storage then reports.
- **The meaning and lifecycle of learning data matter more than the storage library.** Identity, card review and exercise review events, import, and recovery must stay correct whatever framework stores them.
- **Compatibility is a boundary, not a schema.** Lexcalli reads and writes Anki's format but keeps its own schema internally (see [data layering](data-layering.md#anki-compatible-foundation)).
- **Add layers where they earn their place.** Layers like ViewModel, repository, or use-case class per screen are optional. Try to keep essential layers in sync within views.

## Kinds of data and where each lives

| Data | Example | Lives in | Lifetime |
| --- | --- | --- | --- |
| Transient view state | card flipped, sheet shown, menu open | `@State private` in the view that owns it | while the view is on screen |
| Presentation configuration | sizes, radii, durations | `…Configuration` structs in the environment (`@Entry`) | code |
| User preferences | appearance, serif text, show transcription | `UserDefaults` through `@AppStorage`, keys in `PreferenceKey` | device, survives updates |
| Learning content | decks, notes, cards, topics | database | user data, never lost silently |
| Learning history | card review events, exercise review events | database, append-only | user data |
| Scheduling state | per-card FSRS memory state, due date | database, derived from card review events | user data, **recomputable** |
| Media | images, audio | files in Application Support; the database stores references | user data |
| Operations in flight | import staging, events not yet projected, future sync outbox | staging directory and database tables | until finished or recovered |
| Re-creatable data | thumbnails, decoded waveforms | `Library/Caches` | may be purged by the system |
| Secrets (future: sync accounts, API tokens) | — | Keychain | — |

Only user preferences go to `UserDefaults`. Everything the learner creates or earns goes to the database or the media store, behind the core package.

## Identities

Every identifier needs a stated purpose. An entity doesn't get two ids "just in case".

| Identity | Purpose | Form |
| --- | --- | --- |
| Local entity id | relationships inside the database | the database's own key; integer or a UUID |
| Anki identity | matching on re-import, writing back on export | note `guid` (Anki's import key) and notetype; card = note + template `ord` |
| Idempotency key | deduplicating retries, re-imports, and, later, sync | client-generated UUID on every card review event and exercise review event |
| Content hash | media integrity and optional deduplication | SHA-256 of the file |

- **Idempotency keys** are required from day one: they make retries safe.
- **Global UUIDs for every entity** are not required now. CloudKit sync through SQLiteData would require globally unique primary keys on synced tables. That would be a requirement of a specific sync implementation, so it is decided when sync is.
- **Numeric ids from exports** (millisecond timestamps) are not primary keys. For example, Anki itself identifies notes by `guid` on import, and its numeric ids can collide across collections.

## Learning data lifecycle

### Reviews

User activity is collected in practice sessions and recorded as events. Scheduling state is calculated from those events, separately from recording them.

> One accepted scheduled review = one durable card review event. Every event is applied to the card's scheduling state exactly once.

- **Recording a review appends one event.** The command validates the answer and inserts the event. That insert is the only write the study screen waits for; it doesn't compute FSRS or touch the card.
- **Idempotent.** Each card review event has an `idempotency_key` column with a unique constraint. The key is a client-generated UUID, created once per answer and reused on retry, so a retry can't record a second review.
  - A composite key such as `practice_session_id + card_id` assumes a card is answered once per session, which learning steps may break (see [Open questions](#open-questions)).
  - `practice_session_id` is still stored on each event as a plain attribute, for grouping and statistics.
- **Scheduling state is a projection.** A projector runs unapplied events through FSRS in order and updates the card's scheduling state, like a materialized view refreshed in waves. It processes only cards with unapplied events.
  - *Checkpoint.* The projector records the last applied event per card, in the same write as the new state. An event is never applied twice, and after a crash the projector resumes from the checkpoint.
  - *Triggers.* The end of a session, and new events delivered by sync or import. iOS can terminate a suspended app without notice, so opening a session first ends any session still marked open, which runs the projector for it. The checkpoint makes running at both points safe.
  - *Rebuild.* An event that arrives out of order, from sync or import, is earlier than the card's checkpoint; a **Recalculate** button rebuilds that card from its events. The whole projection can also be dropped and rebuilt, for example after an FSRS parameter change or a projector bug.
- **The study queue is prepared once, when a session opens,** from up-to-date scheduling state. Answers don't reorder it; their effect appears when the session ends.
- **Exercise review events are separate.** They go to the exercise review log; card review events go to the card review log. An attempt that doesn't qualify as a scheduled review writes only an exercise review event; one that qualifies also writes a linked card review event. The rules for which attempts count are in [learning engine](learning-engine.md#relationship-to-fsrs).

### Import

SQLite transactions are atomic only inside the database. An import therefore follows a small recovery protocol:

1. Unpack and validate the archive in a staging directory, and record the import as *in progress*.
2. Write media to staging under temporary names. Verify the hashes and that every reference resolves.
3. Move the media into its final content-addressed location. A file named by its hash is safe to write early: it is either referenced later or garbage.
4. Commit one database transaction with all imported records, card review events, and media references, and mark the import *done*.
5. Trigger the projector for the imported cards.
6. On failure, and on the next launch, delete the staging files and media that no record references, and drop imports still marked *in progress*.

Re-importing an updated deck matches notes by `guid`. Scheduling history is imported only when the user chooses to, as Anki 23.10+ allows; otherwise cards start as new and no card review events are imported.

Imported scheduling follows the review model:

- **Anki's card state becomes a baseline.** Anki's revlog can be incomplete (deleted entries, SM-2-era history), so replaying it may not reproduce the card's real state. The imported FSRS memory state and due date are stored as the card's starting point.
- **Imported revlog entries become card review events already covered by that baseline.** The card's checkpoint is set past them, so the projector applies only reviews made in Lexcalli. Recalculate rebuilds from the baseline, not from the first imported event.

Anki's own `.apkg` importer handles cases the protocol above must match:

- **Media name collisions.** Note fields reference media by filename (`<img src>`, `[sound:…]`). Anki keeps a same-named file with different content under a hash-suffixed name and rewrites the references. Lexcalli stores files by hash, so it keeps a filename-to-hash map with unique names per collection and resolves references through it. Files starting with `_` or `latex-` belong to templates and are never renamed.
- **Update policy.** An existing note is updated *if newer* (by modification time), *always*, or *never*. The imported modification time is kept, so the same file can be re-imported cleanly.
- **Notetype conflicts.** Notetypes match by id. If the fields or templates differ, the incoming one is added as a copy. A note whose `guid` exists under a different notetype is skipped as a conflict, unless the user chooses to merge notetypes.
- **Existing cards are not updated.** A card is skipped when its note already has a card for the same template.
- **Due dates are relative.** Anki stores review due dates as days since the collection was created, so the importer shifts them by the difference between the two collections. Lexcalli stores absolute dates and converts only at the boundary.
- **Revlog deduplication.** Only entries for imported cards are kept, and identical entries are skipped. Lexcalli derives the idempotency key of an imported review deterministically from the source entry, so re-importing the same file adds no history.
- **An import report.** Anki reports notes as new, updated, duplicate, or conflicting. Lexcalli shows the same summary.

Lexcalli also treats the archive as untrusted input: it rejects entry names with path components, caps the total uncompressed size, and decompresses zstd as a stream. Archive reading sits behind its own protocol: the first implementation uses the system libarchive, and ZIP and zstd libraries can replace it.

### Deletion

Deleted content leaves a tombstone, which Anki calls a `grave`, so export and future sync can propagate the deletion. The projector skips events of deleted cards. Whether those events are kept is decided with export, following Anki's rule.

### Schema evolution and recovery

- **Migrations are serialized and append-only.** They are checked into the repo, never edited after release, each runs in one transaction, and each has a fixture test that upgrades a real previous-version database.
- **Snapshot before migrating.** Don't copy the database file directly: in WAL mode, recent changes may still be in the `-wal` file, and copying a live database gives an inconsistent copy. Take a consistent snapshot with SQLite's online backup API (GRDB exposes it as `backup(to:)`) or with `VACUUM INTO`.
- **A failed migration** keeps the snapshot, opens nothing in a half-migrated state, and tells the user, so they don't see an empty library.
- **Prefer additive changes.** A destructive change (dropping or retyping a column) goes through copy, verify, and swap.
- **Projection tables aren't migrated with data.** A schema change to scheduling state can drop those tables and rebuild them from events and baselines. Events and baselines always migrate in place.

### Backups and protection

These are three different mechanisms; none replaces another:

- **Device backup (iCloud or a computer).** It covers Application Support, including the database and media. Re-creatable files are excluded through `Library/Caches`.
- **User-level export.** A `.colpkg`- or `.apkg`-compatible export is the learner's own recovery path and portability guarantee. Export runs the projector first, so the exported scheduling state includes every card review event.
- **Sync.** It is replication, not backup: it replicates deletions and corruptions too.

For file protection, keep the system default (*complete until first user authentication*) for the database and media, so that future background work such as reminders or sync can open them. Stricter classes are unnecessary for this data.

### Synchronization (deferred)

Sync is not part of the first milestone, but the model must not rule it out:

- **Treat sync as asynchronous reconciliation.** It tolerates delays, duplicate and out-of-order delivery, offline edits, and termination at any point.
- **Events are already an outbox.** Card review and exercise review events are append-only and uniquely identified, so sync needs no separate outbox table for them.
- **Persist an outbox for mutable data.** Note edits, deck renames, and settings changes are recorded in a durable outbox table in the same transaction as the change itself.
- **Events are authoritative across devices; state is derived.** Two offline devices can review the same card, and last-write-wins on scheduling state would discard valid history. This is a domain rule, not a sync-framework setting:
  - *Events never conflict.* Each is immutable and uniquely identified, so merging two histories is a set union; an event received twice is ignored.
  - *Scheduling state is recomputed, not resolved.* Received events go through the projector like local ones. Replaying a card's events ordered by answer time, with the idempotency key as tiebreak, gives every device the same state; swift-fsrs already ships rescheduling from history. Both offline reviews of the same card are kept, since FSRS-6 models same-day reviews.
  - *Mutable data gets a default resolution.* Note edits, deck renames, and study settings can conflict. The default is last writer wins per field, ordered by a hybrid logical clock rather than the device wall clock.
- **Never rely on background execution for correctness.** iOS schedules `BGTaskScheduler` work at its own discretion, and force-quitting the app stops background transfers. Correctness must hold if sync runs only while the app is open.
- **Evaluate our own backend or iCloud** against the event model above, not against feature lists.

## Data flow into views

These rules are already used in the codebase. They follow the SwiftUI Expert skill's state-management and environment references.

```
SwiftUI views (Lexcalli target, MainActor)
   │ commands ▼                    ▲ observed values
Feature models (@Observable) — only where a feature coordinates operations or holds session state
   │ async calls with Sendable values
LexcalliCore — domain value types, FSRS policy, commands (append review, import), stores;
   │           nonisolated, tested with `swift test`
Persistence — database + media files
```

- **Domain types stay `Sendable` value types.** `Deck` and `Note` already are.
- **Use a feature model when it pays:** a practice session coordinating its queue, answers, and lifecycle, or an import with progress and cancellation. A simple screen (deck list, word list) reads an observed query directly into `@State` and sends commands to the store.
- **Persistence is testable without SwiftUI**, as [the way](the-way.md#principles) requires: core tests run against an in-memory database.

### Choose the property wrapper by ownership

```
Owned by this view?
├─ yes, a value          → @State private var
├─ yes, an @Observable   → @State private var model = Model()
└─ no, passed in
   ├─ only displayed     → let
   ├─ child changes it   → @Binding var
   └─ @Observable, needs bindings → @Bindable var
Shared model             → .environment(model) at its owner, @Environment(Model.self) in readers
Preference               → @AppStorage(PreferenceKey.x) private var x = default
Configuration            → @Environment(\.x) private var configuration
```

- `@State` is always `private`. Never store a parent-owned input as `@State`: it keeps the first value and ignores updates. Since SDK 27, `@State` is a macro; to seed it from `init`, declare it without a default and assign it once.
- Pass views **only the values they read**. A row gets its `Note`, not the deck plus an index: reading one element of an observed array subscribes the row to the whole array.
- Use `@Binding var`, never `let x: Binding<T>`. A plain binding property isn't tracked, and that often breaks only in Release builds.
- Prefer key-path bindings (`$model.name`) over `Binding(get:set:)` closures.

### Examples

A simple screen reads an observed projection directly:

```swift
struct DecksView: View {
    @Environment(\.deckStore) private var store
    @State private var decks: [Deck] = []

    var body: some View {
        List(decks) { DeckRow(deck: $0) }
            // Structured: cancelled with the view.
            .task { for await decks in store.decks() { self.decks = decks } }
    }
}
```

A feature model coordinates a session and owns the retry rule; the lifecycle follows [Reviews](#reviews):

```swift
@Observable
final class PracticeSession {  // MainActor by the app target's default isolation
    private(set) var current: Card?
    private(set) var failed: ReviewEvent?

    @ObservationIgnored private let reviews: any ReviewStore
    @ObservationIgnored private var queue: [Card] = []
    @ObservationIgnored private let sessionID = UUID()

    init(reviews: any ReviewStore) { self.reviews = reviews }

    /// Opens the session: ends sessions left open by a terminated app, then prepares the queue once.
    func start(deck: Deck.ID) async throws {
        try await reviews.endUnfinishedSessions()
        try await reviews.openSession(sessionID, deck: deck)
        queue = try await reviews.dueCards(in: deck)
        advance()
    }

    func rate(_ rating: Rating) async {
        guard let card = current else { return }
        await append(ReviewEvent(
            idempotencyKey: UUID(), sessionID: sessionID,
            cardID: card.id, rating: rating, answeredAt: .now))
    }

    /// Resends the same event, so a retry can't record a second review.
    func retry() async {
        if let failed { await append(failed) }
    }

    /// Normal end: marks the session ended and applies its events.
    func finish() async throws {
        try await reviews.endSession(sessionID)
    }

    private func append(_ event: ReviewEvent) async {
        do {
            try await reviews.append(event)
            failed = nil
            advance()
        } catch {
            failed = event
        }
    }

    private func advance() {
        current = queue.isEmpty ? nil : queue.removeFirst()
    }
}
```

- Models expose `private(set)` state and command methods.
- Make frequently written property types `Equatable` so redundant writes don't invalidate views. Precompute derived values in `didSet` rather than in computed properties that read whole collections.
- Inside an `@Observable` class, any property wrapper (`@AppStorage`, `@Query`, `@FetchAll`) needs `@ObservationIgnored`.
- Use `.task` for observation and loading, not `Task {}` in `onAppear`. To observe an `@Observable` from non-view code, use `Observations { … }` (Swift 6.2+, iOS 26).

### Environment values

- `@Entry` for custom keys, with **stable defaults**. `@Entry var store = Store()` allocates on every fallback read and invalidates readers; hold the default instance in a `static let`.
- Don't store closures in custom keys; use a struct with `callAsFunction`, or a model.
- Don't put high-frequency values, such as scroll offsets or drag positions, in the environment.

### Previews and samples

- Previews get data through the same seams as the app: an in-memory store seeded from `Deck.samples`.
- `Deck.samples` stays a fixture for previews and tests; it disappears from `RootView` once a real store exists.

## Persistence engine

### Constraints, in order of weight

1. **Data correctness.** Card review and exercise review events, projection, idempotency, constraints, migrations, and recovery, as described above.
2. **Anki interchange.** `.apkg` and `.colpkg` files are SQLite databases; import and export are mappings between SQL schemas.
3. **Volume.** A real collection has tens of thousands of notes and hundreds of thousands of card review events; imports are bulk and statistics are aggregate queries.
4. **Swift 6 strict concurrency**, with MainActor default isolation in the app and a nonisolated core.
5. **Deployment target iOS 26.** APIs that need the iOS 27 SDK and runtime are unavailable without availability checks.
6. **Few dependencies** ([agent guide](../.agents/AGENTS.md#engineering-decisions)).

### Options

| | SwiftData | GRDB | SQLiteData (on GRDB) |
| --- | --- | --- | --- |
| Owner | Apple | open source, maintained for about a decade (v7.11.1) | Point-Free, open source (v1.12.1) |
| Model shape | `@Model` classes | structs (`Codable`, `FetchableRecord`) | `@Table` structs |
| Sendable models | no; pass `PersistentIdentifier` | yes | yes |
| SQL access | none (predicates only) | full | full, type-safe query builder plus raw SQL |
| Observation | `@Query`; `ResultsObserver` outside views, **iOS 27+** | `ValueObservation` (main-actor callbacks by default) | `@FetchAll` / `@FetchOne` / `@Fetch` |
| Migrations | `VersionedSchema` + `SchemaMigrationPlan` | ordered `DatabaseMigrator` steps in SQL | the same as GRDB |
| iCloud sync | private database only; no unique constraints; all properties optional or defaulted | not built in | `SyncEngine` on CloudKit, including sharing; globally unique primary keys |
| Extra dependencies | none | GRDB | GRDB, StructuredQueries, swift-dependencies |

Core Data is left out: Lexcalli has no existing Core Data store to carry, and Core Data brings the same class-based object model as SwiftData.

### Assessment

- **GRDB is the conservative starting point.** Its SQLite semantics (transactions, constraints, `ON CONFLICT`, the backup API) are part of domain correctness here, and the core keeps `Sendable` structs.
- **GRDB stays behind store protocols.** LexcalliCore defines domain-shaped stores (deck, review, import), never generic CRUD, and doesn't import GRDB; a separate store target implements them. A shared contract test suite checks idempotent appends, atomic projection writes, observation, and migrations against every implementation, so SwiftData can replace GRDB if the experiment calls for it.
- **SwiftData remains a legitimate comparison**, but not the default:
  - It needs `@Model` classes, which means either leaking them into the core or mapping them to structs.
  - With MainActor default isolation it needs `@Model nonisolated` and a `@ModelActor` created off the main thread.
  - Its CloudKit sync forbids unique constraints.
  - Most of its 2026 improvements (`ResultsObserver`, `HistoryObserver`, `sectionBy`, `@Attribute(.codable)`, `Predicate(all:)`) need iOS 27, above our deployment target. Reviewers also report open problems: `ModelActor` sometimes runs on the main thread, and `propertiesToFetch` doesn't work.
- **Don't adopt SQLiteData just for CloudKit sync yet.** As of October 2026 its issue tracker has open reports of divergence between devices after concurrent offline edits (#274), violations of last-edit-wins (#354), data loss after delete and re-insert (#418), and local child deletion after a quota error (#547). These are reports, not proof that Lexcalli would be affected. But progress preservation is non-negotiable, so the sync layer would have to be validated against our event model first.

The experiment below decides between GRDB and SwiftData with evidence, not feature lists.

## Concurrency

- **App target:** MainActor by default. Views and models live there and `await` the core.
- **Core:** nonisolated. Stores do their work off the main actor, through `@concurrent` async functions or the database library's queues, not `Task.detached`.
- **Only `Sendable` values cross boundaries:** domain structs, commands, and identifiers.
- **Writes are serialized:** a GRDB `DatabasePool` has one writer, and readers work on consistent snapshots.
- **The projector** runs off the main actor as a cancellable task. Its checkpoint makes cancellation safe: the next trigger resumes where it stopped.
- **Long work** (imports, media conversion) runs as a cancellable task that reports progress to a MainActor model and follows the [import protocol](#import).

## Media

- Store files under `Application Support/Media/<hash-prefix>/<hash>.<ext>`: app-managed, not user-browsable, and backed up because they are user content.
- The database stores a **relative** reference (hash, original filename, MIME type), never an absolute `URL`, because the container path can change between launches and restores. Resolve to a `URL` at the edge.
  - Today `Note.imageURL` and `audioURLs` are absolute bundle URLs. That is fine for samples and should become references once persistence lands.
- Keep media out of database blobs: files stream for audio playback and export straight back into an `.apkg`.
- Unreferenced files are garbage-collected by the same recovery pass as imports.

## Preferences

- Use `@AppStorage` with keys from `PreferenceKey` only for small device-local settings.
- Known debt (deferred): each default value is repeated at every `@AppStorage` use site. When it starts to hurt, centralize the defaults with `UserDefaults.standard.register(defaults:)` or with one typed accessor per preference.
- Study settings (daily limits, desired retention, FSRS parameters) are **learning data**, not preferences. They belong in the database because they affect scheduling and are exported to Anki deck options.

## Testing

- Use realistic fixtures, not generic library benchmarks. An imported collection must survive launch, study, termination, migration, re-import, and export without losing semantic content or review history.
- **Core:** Swift Testing against an in-memory database, and real `.apkg` fixtures for import and export.
- **Projector:** applying events incrementally and rebuilding from scratch must give the same state, including after a crash between events.
- **App:** XCTest UI tests launched with a seeded store. Simulator checks come first; device checks cover performance and lifecycle (see [the way](the-way.md#verification-strategy)).

## Anki file format notes

These notes were collected for the importer. The format is defined by Anki's source code and changes between versions.

- `.apkg` (a deck) and `.colpkg` (a whole collection) are ZIP archives.
  - **Current:** `collection.anki21b` is SQLite schema v18, compressed with zstd inside the ZIP. `meta` and the `media` manifest are Protobuf. Media files inside are named `0`, `1`, … and mapped to their real names by the manifest.
  - **Legacy:** `collection.anki21` or `collection.anki2` (schema v11, configuration as JSON in `col`) with a JSON `media` map. A dummy `collection.anki2` is still included for old clients.
- Tables relevant to Lexcalli:
  - `notes`: `id`, `guid`, `mid` (notetype), `flds` (fields separated by `0x1f`), `tags`.
  - `cards`: `id`, `nid`, `did`, `ord` (template), `type` 0–3, `queue`, `due`, `ivl`, `factor`, `reps`, `lapses`. Its `data` JSON holds the FSRS memory state: stability, difficulty, and for FSRS-6 the per-card decay.
  - `revlog`: `id` (millisecond timestamp), `cid`, `ease` 1–4, `ivl`, `lastIvl`, `factor`, `time`, `type`.
  - Also `decks`, `deck_config`, `notetypes`, `fields`, `templates`, `tags`, `config`, and `graves` (deletions).
- Rating (1–4) and card type (0–3) numbering already match `CompatibilityTests` in LexcalliCore.

## Next experiment

This is a narrowly scoped persistence experiment rather than the full design. It follows the [first milestone](the-way.md#first-milestone): import a small Anki deck with media, review a card, persist the result, and reopen the app.

| Experiment | Acceptance criterion |
| --- | --- |
| Store | Decks and notes are saved and loaded; changes reach SwiftUI without refreshing unrelated rows |
| Card review event and projection | A retry never creates an extra card review event; a crash during projection never applies an event twice; rebuilding from events and baselines gives the same state |
| Import with media | A failure or forced interruption never leaves committed references to missing media |
| Migration | Data survives upgrading a real previous-version fixture, and a failed migration restores from the snapshot |
| Large collection | Import and query times, and UI responsiveness, are measured on a device |
| Anki round-trip | Notes, identifiers, media, and supported review history come back semantically equivalent |

Build it on GRDB first. Repeat only the store and card-review-event rows on SwiftData if GRDB shows real friction.

## Open questions

- Whether local entity ids are integers or UUIDs: decided by the experiment and the sync choice.
- Our own backend versus iCloud sync.
- Whether out-of-order events should trigger recalculation automatically instead of through the Recalculate button.
- How learning steps work when the queue is prepared once and projected only when the session ends: a card answered *Again* can't come back in the same session.
- Undo policy for reviews.
- Whether to delete review history together with its card, or keep it.
- Media deduplication across decks.
- Which side wins when one device edits a note that another device deleted.

## Prior art

These ideas are older than the current frameworks; the tooling changed more than the concepts.

| School | Established approach | What Lexcalli borrows | What to avoid |
| --- | --- | --- | --- |
| Delphi / FireDAC | data modules, datasets, cached updates, explicit transactions | persistence separate from screens; an explicit unit of work per operation (`submit review`) | binding mutable database records throughout the UI |
| Android / Jetpack | Room, repositories, Flow, unidirectional data flow, offline-first | the local database as source of truth; observed queries; commands that write locally first | a mandatory ViewModel, repository, and use case for every screen; Android's own guide allows plain classes where a state holder adds nothing |
| Relational design | constraints, transactions, migrations, stable identity | invariants enforced by the schema | hiding SQL behind generic CRUD interfaces |
| Event sourcing / CQRS | append-only event log, projections, rebuild from history | card review events as the source of truth; scheduling state as a checkpointed projection | event-sourcing everything: notes, decks, and settings stay plain mutable rows |
| Modern SwiftUI | Observation, ownership-based state, async/await | native reactive UI with thin adaptation | copying persistent state into large observable objects |

## Sources

The full list, including skipped sources and reasons, is in [operational/raw/data-managemeent-source-list.md](../operational/raw/data-managemeent-source-list.md).

Skills (local, `.agents/skills/`):

- SwiftUI Expert, `references/state-management.md` and `references/environment-patterns.md`.
- Swift Concurrency, `references/observation.md` and `references/core-data.md`.

Platform documentation:

- [Apple: Managing model data in your app](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app)
- [Apple: Encrypting your app's files](https://developer.apple.com/documentation/uikit/encrypting-your-app-s-files) (data protection classes)
- [Apple: Optimizing your app's data for iCloud backup](https://developer.apple.com/documentation/foundation/optimizing-your-app-s-data-for-icloud-backup)
- [Apple: BGTaskScheduler](https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler)
- [Android: Build an offline-first app](https://developer.android.com/topic/architecture/data-layer/offline-first)
- [Android: State holders and UI state](https://developer.android.com/topic/architecture/ui-layer/stateholders)
- [SQLite: Online backup API](https://www.sqlite.org/backup.html), [VACUUM INTO](https://www.sqlite.org/lang_vacuum.html), [Write-ahead logging](https://www.sqlite.org/wal.html)

SwiftData (iOS 26–27):

- [SwiftData in appleOS 27](https://mjtsai.com/blog/2026/06/23/swiftdata-in-appleos-27/) (Michael Tsai)
- [SwiftData in iOS 27: Observation and History](https://blakecrosley.com/blog/swiftdata-ios-27-observation-history)
- [WWDC26: SwiftData](https://www.pointfree.co/episodes/ep372-wwdc26-swiftdata) (Point-Free)
- [Fatbobman's Swift Weekly #140](https://fatbobman.com/en/weekly/issue-140/)
- [SwiftData Migrations: Lightweight vs Custom](https://blakecrosley.com/blog/swiftdata-migrations-guide)
- [Concurrent Programming in SwiftData](https://fatbobman.com/en/posts/concurret-programming-in-swiftdata/) (Fatbobman)
- [@ModelActor with default actor isolation = MainActor](https://developer.apple.com/forums/thread/788262) (Apple Developer Forums)

SQLite-based libraries:

- [GRDB.swift](https://github.com/groue/GRDB.swift)
- [SQLiteData](https://github.com/pointfreeco/sqlite-data) and its open sync issues: [#274](https://github.com/pointfreeco/sqlite-data/issues/274), [#354](https://github.com/pointfreeco/sqlite-data/issues/354), [#418](https://github.com/pointfreeco/sqlite-data/issues/418), [#547](https://github.com/pointfreeco/sqlite-data/issues/547)

Anki:

- [Understanding the Anki APKG Format](https://eikowagenknecht.com/posts/understanding-the-anki-apkg-format/) (Eiko Wagenknecht)
- [Anki manual: Exporting](https://docs.ankiweb.net/manual/exporting), [Importing packaged decks](https://docs.ankiweb.net/importing/packaged-decks.html)
- [ankiR: Getting Started](https://cran.r-project.org/web/packages/ankiR/vignettes/getting-started.html)
- Anki source, `.apkg` importer: [notes.rs](https://github.com/ankitects/anki/blob/main/rslib/src/import_export/package/apkg/import/notes.rs), [cards.rs](https://github.com/ankitects/anki/blob/main/rslib/src/import_export/package/apkg/import/cards.rs), [media.rs](https://github.com/ankitects/anki/blob/main/rslib/src/import_export/package/apkg/import/media.rs)
