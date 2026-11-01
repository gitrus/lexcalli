# Data management: source list

These are the raw research sources behind [docs/data-management.md](../../docs/data-management.md), collected on 2026-10-18.

The tables use these columns:

- **Read** says how a source was consulted:
  - **fetched:** I read the page itself.
  - **search:** I only saw the search engine's summary of the page.
  - **local:** a skill file in this repo.
  - **grep:** I only matched lines in a local file, without reading the whole file.
- **Doc** says whether the source made it into the doc:
  - **cited:** it is listed in the doc's Sources.
  - **used:** it shaped the text but is not cited.
  - **skipped:** it was considered and left out; the Notes say why.

Before a claim drives a decision, check it if it rests only on a search summary.

## Skills

### Included

| Skill reference | Read | Doc | Used for |
| --- | --- | --- | --- |
| `swiftui-expert-skill/references/state-management.md` | local | cited | Choosing property wrappers, Observation granularity, `@ObservationIgnored` for wrappers, the SDK 27 `@State` macro, binding rules |
| `swiftui-expert-skill/references/environment-patterns.md` | local | cited | `@Entry`, stable defaults, no closures in keys, type-based `@Environment` for `@Observable` |
| `swiftui-expert-skill/references/performance-patterns.md` | grep | used | Narrowing state scope; passing a row only the fields it reads |
| `swiftui-expert-skill/references/list-patterns.md` | grep | used | Creating ids in storage, never inside `body` (supports UUID primary keys) |
| `swift-concurrency/SKILL.md` | grep | used | `@concurrent` for background work instead of `Task.detached` |
| `swift-concurrency/references/observation.md` | local | cited | `@MainActor @Observable`, the `Observations` AsyncSequence (Swift 6.2+), Sendable snapshots |
| `swift-concurrency/references/core-data.md` | local | cited | Passing DAOs or object IDs, `nonisolated` managed objects under MainActor default isolation |

### Excluded

| Skill reference | Why excluded |
| --- | --- |
| `swiftui-expert-skill/references/localization.md` | Matched by grep (use `LocalizedStringResource` for user-facing text in models). It is about text, not storage, so it was left out of the doc. |
| `swiftui-expert-skill/references/layout-best-practices.md` | Matched by grep (don't cache size classes in models). It is about layout. |
| `swiftui-expert-skill/references/document-apps.md` | Matched by grep. Document-based apps don't fit Lexcalli. |
| `swiftui-expert-skill/references/previews.md` | Relevant (seeding previews with an in-memory store) but not read; see To read next. |
| `swiftui-expert-skill/references/view-structure.md`, `sheet-navigation-patterns.md` | Not read. They cover view composition and navigation, not data. |
| `swiftui-expert-skill/references/accessibility-patterns.md`, `animation-*.md`, `charts*.md`, `focus-patterns.md`, `image-optimization.md`, `iphone-duo.md`, `latest-apis.md`, `liquid-glass.md`, `modifier-patterns.md`, `scroll-patterns.md`, `soft-deprecation.md`, `styled-text-editing.md`, `text-patterns.md`, `toolbar-patterns.md`, `trace-*.md`, `webkit-integration.md` | Out of scope: UI, rendering, or tooling. |
| `swiftui-expert-skill/references/macos-*.md` | Out of scope: macOS only. |
| `swift-concurrency/references/sendable.md`, `threading.md`, `tasks.md`, `actors.md`, `testing.md` | Relevant to the store layer but not read in this pass; see To read next. |
| `swift-concurrency/references/async-sequences.md`, `async-algorithms.md` | Not read. `observation.md` covered the AsyncSequence bridge the doc needs. |
| `swift-concurrency/references/async-await-basics.md`, `glossary.md`, `linting.md`, `memory-management.md`, `migration.md`, `performance.md`, `_index.md` | Out of scope: basics, tooling, or migrating from Combine. |
| `update-swiftui-apis` (the whole skill) | A maintenance tool for refreshing the SwiftUI skill against Apple docs. It has no data guidance. |

User-level skills (`~/.claude/skills`, such as `ripwire-*` and `my-rules-loader`) were not used: they hold no iOS or persistence guidance, and my-rules has no Swift directory.

## SwiftData (iOS 26–27, WWDC26)

| Source | Read | Doc | Notes |
| --- | --- | --- | --- |
| [Michael Tsai: SwiftData in appleOS 27](https://mjtsai.com/blog/2026/06/23/swiftdata-in-appleos-27/) | fetched | cited | New APIs. Community issues: ModelActor sometimes runs on the main thread, `propertiesToFetch` doesn't work, no shared-database sync. |
| [Blake Crosley: SwiftData in iOS 27, Observation and History](https://blakecrosley.com/blog/swiftdata-ios-27-observation-history) | fetched | cited | `ResultsObserver`, `HistoryObserver`, `@Attribute(.codable)`, `fetchCount`/`fetchIdentifiers` |
| [Point-Free ep. 372: WWDC26 SwiftData](https://www.pointfree.co/episodes/ep372-wwdc26-swiftdata) | fetched (description) | cited | Sectioning works on strings only; `.codable` fields are opaque; inheritance. Point-Free sells SQLiteData, so its comparison is a vendor's view. |
| [Fatbobman's Swift Weekly #140](https://fatbobman.com/en/weekly/issue-140/) | fetched | cited | WWDC26 overview: incremental updates |
| [Blake Crosley: SwiftData Migrations, Lightweight vs Custom](https://blakecrosley.com/blog/swiftdata-migrations-guide) | search | cited | A defaulted new property needs no V2 (declaring one crashes with "duplicate version checksums") |
| [Azam Sharp: What's New in SwiftData for iOS 27](https://azamsharp.medium.com/whats-new-in-swiftdata-for-ios-27-8afbd045f968) | search | skipped | Duplicates the feature list of the cited sources |
| [SwiftChronicle: What's New in SwiftData (iOS 27)](https://swiftchronicle.com/features/swiftdata-whats-new-ios27) | search | skipped | Duplicate feature list |
| [SwiftUI Snippets: What's New in SwiftData for iOS 27](https://swiftuisnippets.wordpress.com/2026/06/16/whats-new-in-swiftdata-for-ios-27/) | search | skipped | Duplicate; low-trust blog |
| [Use Your Loaf: WWDC 2026 Viewing Guide](https://useyourloaf.com/blog/wwdc-2026-viewing-guide/) | search | skipped | Session index only |
| [Blake Crosley: What's New in SwiftUI for iOS 27](https://blakecrosley.com/blog/whats-new-swiftui-ios-27) | search | skipped | About SwiftUI, not data |
| [Hacking with Swift: complex migration using VersionedSchema](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-create-a-complex-migration-using-versionedschema) | search | skipped | Covered by the cited migrations guide |
| [WWDC23 session 10195: Model your schema with SwiftData](https://nonstrict.eu/wwdcindex/wwdc2023/10195/) | search | skipped | Background only; it predates the iOS 27 changes |

## SwiftData and Swift concurrency

| Source | Read | Doc | Notes |
| --- | --- | --- | --- |
| [Apple Developer Forums 788262: @ModelActor with default actor isolation = MainActor](https://developer.apple.com/forums/thread/788262) | fetched | cited | Apple DTS answer: `@Model nonisolated class`, how to use ModelActor |
| [Fatbobman: Concurrent Programming in SwiftData](https://fatbobman.com/en/posts/concurret-programming-in-swiftdata/) | fetched | cited | A context or actor executor runs on the thread that creates it; `PersistentIdentifier` is the Sendable bridge |
| [Fatbobman: Default Actor Isolation, New Problems from Good Intentions](https://fatbobman.com/en/posts/default-actor-isolation/) | search | cited | The consequences of SE-0466 |
| [Apple Developer Forums 775661: Swift 6 errors with ModelActor / Core Data actors](https://developer.apple.com/forums/thread/775661) | search | skipped | Same point as 788262 (a context can't be shared across actors) |
| [Use Your Loaf: SwiftData Background Tasks](https://useyourloaf.com/blog/swiftdata-background-tasks/) | search | skipped | Covered by Fatbobman's article |
| [Fatbobman: Core Data Reform, SwiftData-like concurrency](https://fatbobman.com/en/posts/core-data-reform-achieving-elegant-concurrency-operations-like-swiftdata/) | search | skipped | Core Data path (CoreDataEvolution); Core Data isn't a candidate |
| [Donny Wals: actor-isolated protocol conformance errors in Swift 6.2](https://www.donnywals.com/solving-actor-isolated-protocol-conformance-related-errors-in-swift-6-2/) | search | skipped | General Swift 6.2 diagnostics, not data |
| [Swift Forums: defaultIsolation MainActor and Core Data background tasks](https://forums.swift.org/t/defaultisolation-mainactor-and-core-data-background-tasks/80569) | search | skipped | Core Data specific |
| [Swift Forums: @concurrent and main actor isolation](https://forums.swift.org/t/concurrent-and-main-actor-isolation/80406) | search | skipped | Covered by the Swift Concurrency skill |
| [Apple Developer Forums 803827: Core Data main-actor property from a Sendable closure](https://developer.apple.com/forums/thread/803827) | search | skipped | Core Data specific |

## SQLite-based alternatives and comparisons

| Source | Read | Doc | Notes |
| --- | --- | --- | --- |
| [GRDB.swift](https://github.com/groue/GRDB.swift) | GitHub API (releases) | cited | Latest release v7.11.1 (2026-06-18) |
| [GRDB migration guides (mintlify mirror)](https://www.mintlify.com/groue/GRDB.swift/resources/migration-guides) | search | used | GRDB 7 supports Swift 6; `ValueObservation` calls back on the main actor by default. Unofficial mirror. |
| [pointfreeco/sqlite-data](https://github.com/pointfreeco/sqlite-data) | fetched (README) | cited | `@Table`, the `@Fetch*` wrappers, `SyncEngine`, UUID primary keys for sync, dependencies |
| [sqlite-data releases](https://github.com/pointfreeco/sqlite-data/releases) | fetched + GitHub API | used | Latest release 1.12.1 (2026-10-09). The fetched summary gave the wrong years, so the dates come from the API. |
| [Fractal Dev: iOS Databases in 2026](https://fractal-dev.com/blog/ios-databases) | fetched | cited | Option comparison and benchmarks, directional only. Its claim that SwiftData supports only lightweight migrations is **wrong**: custom stages exist. |
| [pistack: GRDB vs SwiftData vs Core Data in 2026](https://www.pistack.xyz/posts/2026-08-11-grdb-swiftdata-core-data-swift-persistence-comparison/) | search | skipped | Low-trust source; repeats Fractal Dev |
| [dev.co: SQLiteData overview](https://dev.co/databases/open-source/sqlite-data) | search | skipped | Low-trust marketing summary |
| [BigGo News: SQLiteData CloudKit sync](https://biggo.com/news/202509181942_SQLiteData_CloudKit_Sync_Performance) | search | skipped | News rewrite of vendor-reported performance claims |
| [Hacker News: SQLiteData discussion](https://news.ycombinator.com/item?id=45275582) | search | skipped | Opinions only; not read |
| [sqlitedata-extensions-playbook](https://github.com/anukulgosavi1-coder/sqlitedata-extensions-playbook) | search | skipped | Unknown author; SEO-style list |
| [Wikipedia: Local-first software](https://en.wikipedia.org/wiki/Local-first_software) | search | skipped | Background only |

## Sync (CloudKit)

| Source | Read | Doc | Notes |
| --- | --- | --- | --- |
| [Apple Developer Forums 731435: CKSyncEngine & SwiftData](https://developer.apple.com/forums/thread/731435) | search | cited | Using `CKSyncEngine` with custom persistence |
| [markbattistella/SwiftDataSync](https://github.com/markbattistella/SwiftDataSync) | search | cited | A `CKSyncEngine` outbox over a SwiftData store, with shared zones |
| [Axiom skill: cloud-sync](https://skills.cat/skills/charleswiltgen/axiom/axiom-cloud-sync) | search | used | Decision table: SwiftData with CloudKit, `CKSyncEngine`, or raw CloudKit. Third-party skill, not installed. |
| [Axiom skill: cloudkit-ref](https://playbooks.com/skills/charleswiltgen/axiom/axiom-cloudkit-ref) | search | skipped | Duplicates cloud-sync |
| [Axiom skill: storage](https://playbooks.com/skills/charleswiltgen/axiom/axiom-storage) | search | used | Documents, Application Support, Caches, tmp; backup exclusion |
| [swift-ios-skills: file storage patterns](https://tessl.io/registry/dpearson2699/swift-ios-skills/3.9.0/files/skills/ios-networking/references/file-storage-patterns.md) | search | skipped | Same storage-location guidance as Axiom |
| [rshankras: cloudkit-sync skill](https://skillselion.com/skills/rshankras/claude-code-apple-skills/cloudkit-sync), [derklinke: ios-cloud-sync](https://playbooks.com/skills/derklinke/codex-config/ios-cloud-sync) | search | skipped | Duplicate third-party skills |

## Architecture (data flow into views)

| Source | Read | Doc | Notes |
| --- | --- | --- | --- |
| [MV vs MVVM in SwiftUI (2025)](https://kitemetric.com/blogs/mv-vs-mvvm-in-swiftui-2025-architecting-your-ios-apps) | search | used | Start with MV and `@Observable`; escalate only when needed. It agrees with the agent guide's "no frameworks without need". |
| [swift-ios-skills: swift-architecture](https://tessl.io/registry/dpearson2699/swift-ios-skills/3.6.0/files/skills/swift-architecture/SKILL.md) | search | skipped | Third-party skill; generic |
| [OneUptime: SwiftUI MVVM architecture](https://oneuptime.com/blog/post/2026-02-02-swiftui-mvvm-architecture/view) | search | skipped | Generic; its claim that MVVM is the 2026 default conflicts with the project's MV direction |
| [The Swift Kit: SwiftUI app architecture](https://theswiftk.it.com/blog/swiftui-app-architecture-mvvm-guide) | search | skipped | Generic |
| [Fora Soft: advanced iOS MVVM](https://forasoft.com/blog/article/advanced-ios-app-architecture-explained-on-mvvm-977) | search | skipped | Agency marketing |
| [barreiro-max/ToDoList](https://github.com/barreiro-max/ToDoList) | search | skipped | Sample app, not guidance |

## Anki file format

| Source | Read | Doc | Notes |
| --- | --- | --- | --- |
| [Eiko Wagenknecht: Understanding the Anki APKG Format](https://eikowagenknecht.com/posts/understanding-the-anki-apkg-format/) | fetched | cited | `collection.anki21b` (schema v18, zstd); Protobuf `meta` and media manifest |
| [Anki manual: Exporting](https://docs.ankiweb.net/manual/exporting) | search | cited | Export options for `.apkg` and `.colpkg` |
| [ankiR: Getting Started (CRAN)](https://cran.r-project.org/web/packages/ankiR/vignettes/getting-started.html) | search | cited | What the `cards` and `revlog` columns mean; FSRS stability, difficulty and decay in `cards.data` |
| [Eiko Wagenknecht: APKG format, legacy part 2](https://eikowagenknecht.com/posts/understanding-the-anki-apkg-format-legacy-2/) | search | used | Legacy schema v11 tables and the JSON `media` map |
| [brandur.org: apkg fragment](https://brandur.org/fragments/apkg) | search | skipped | Short note; covered by Wagenknecht |
| [AnkiWeb forums: update to the latest Anki version](https://forums.ankiweb.net/t/please-update-to-the-latest-anki-version/60478) | search | skipped | About version compatibility; not needed yet |
| [nofate/anki-writer](https://awesome.ecosyste.ms/projects/github.com%2Fnofate%2Fanki-writer) | search | skipped | Writer library; maybe useful for test fixtures later |
| [scrapbox: apkg data structure (JP)](https://scrapbox.io/takker/apkg%E3%81%AE%E3%83%87%E3%83%BC%E3%82%BF%E6%A7%8B%E9%80%A0), [Anki code reading (JP)](https://scrapbox.io/takker/Ankiのcode%20reading) | search | skipped | Personal notes; duplicates Wagenknecht |
| [Obsidian FSRS plugin](https://community.obsidian.md/plugins/fsrs) | search | skipped | Not about Anki storage |

## Added after the research review (2026-10-19)

The review proposed these sources. I checked each URL; the doc revision cites the ones marked cited.

| Source | Read | Doc | Notes |
| --- | --- | --- | --- |
| [Apple: Managing model data in your app](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app) | URL checked | cited | State ownership and Observation (primary source behind the skill rules) |
| [Apple: Encrypting your app's files](https://developer.apple.com/documentation/uikit/encrypting-your-app-s-files) | URL checked | cited | Data protection classes; keep the default for the database |
| [Apple: Optimizing your app's data for iCloud backup](https://developer.apple.com/documentation/foundation/optimizing-your-app-s-data-for-icloud-backup) | URL checked | cited | Backup scope, Caches exclusion |
| [Apple: BGTaskScheduler](https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler) | URL checked | cited | Background work runs at the system's discretion, so correctness can't depend on it |
| [Android: Build an offline-first app](https://developer.android.com/topic/architecture/data-layer/offline-first) | URL checked | cited | Local database as the source of truth; sync and conflicts |
| [Android: State holders and UI state](https://developer.android.com/topic/architecture/ui-layer/stateholders) | URL checked | cited | Plain classes are fine where a state holder adds nothing |
| [SQLite: Online backup API](https://www.sqlite.org/backup.html) | URL checked | cited | Consistent snapshot before a migration (GRDB `backup(to:)`) |
| [SQLite: VACUUM INTO](https://www.sqlite.org/lang_vacuum.html) | URL checked | cited | Alternative consistent snapshot |
| [SQLite: Write-ahead logging](https://www.sqlite.org/wal.html) | URL checked | cited | Why copying a live database file is unsafe |
| [Anki manual: Importing packaged decks](https://docs.ankiweb.net/importing/packaged-decks.html) | fetched | cited | Notes are updated when the file's copy is newer; since 23.10, importing learning progress is optional |
| [SQLiteData issues: sync](https://github.com/pointfreeco/sqlite-data/issues?q=is%3Aissue+sync) | GitHub API | cited (#274, #354, #418, #547) | Open reports: cross-device divergence, last-edit-wins violations, data loss after delete and re-insert, child deletion after a quota error. Also #563 (sync errors). Many related bugs are already closed (#315, #424, #432). |
| swift-fsrs `FSRS.reschedule(currentCard:reviews:options:)` | local (checkout) | used | Confirms that scheduling state can be replayed from review events |
| [Embarcadero: Data Modules](https://docwiki.embarcadero.com/RADStudio/Athens/en/Data_Modules) | URL returned 403 to curl | used (Prior art) | Delphi's separation of data from forms. Unverified link. |
| [Embarcadero: Caching Updates (FireDAC)](https://docwiki.embarcadero.com/RADStudio/Athens/en/Caching_Updates_(FireDAC)) | URL returned 403 to curl | used (Prior art) | Unit of work with cached updates. Unverified link. |
| WWDC26: What's New in SwiftData; WWDC26: Swift Testing | not found | skipped | Named in the review without links; still on the reading list |

## To read next

- **Skills:**
  - `swift-concurrency/references/sendable.md`, `threading.md`, `tasks.md`, `actors.md` and `testing.md`, for the store layer and its tests.
  - `swiftui-expert-skill/references/previews.md`, for previews backed by an in-memory store.
- **Apple documentation:** [SwiftData](https://developer.apple.com/documentation/swiftdata), [Observation](https://developer.apple.com/documentation/observation), [CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine), and the WWDC26 SwiftData session. None of these was read directly in this pass.
- **Anki source:** [rslib](https://github.com/ankitects/anki/tree/main/rslib) holds the authoritative definitions of the v18 schema and the media manifest. Read it before writing the importer.
- **GRDB documentation:** [`ValueObservation`, `DatabaseMigrator` and `DatabasePool`](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb), for the spike.
