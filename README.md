# lexcalli
[![Swift](https://github.com/gitrus/lexcalli/actions/workflows/swift.yml/badge.svg)](https://github.com/gitrus/lexcalli/actions/workflows/swift.yml)

An Anki-inspired language-learning app for mastering vocabulary, collocations, and expressions through spaced repetition, active recall, and interactive exercises.

## Development notes

- [Docs](docs/README.md) — documentation for recording project decisions.
- [Agent instructions](AGENTS.md) — entry point for coding agents.
- [Agent skills](.agents/AGENTS.md) — reference for installed skills, iOS engineering conventions, SwiftUI architecture conventions, and verification guidance.

## Getting started

- Requirements: Xcode 26.4+ (Swift 6.3+) and [just](https://github.com/casey/just). UI-test result checks also require Python 3.
- `just open` opens the project; `just run` launches the app in a simulator (`just run booted` reuses the one already open); `just check` runs lint, package tests and the app build.

## Tests

| Suite | Framework | Covers | Run |
|---|---|---|---|
| `LexcalliKit/Tests/LexcalliCoreTests` | Swift Testing | Scheduling, projection, study queue, practice runs | `just test` |
| `LexcalliKit/Tests/LexcalliStoreTests` | Swift Testing | Store contract, durability (reopen, WAL, migrations), media files | `just test` |
| `LexcalliKit/Tests/LexcalliImportTests` | Swift Testing | Package unpacking against generated fixtures, hostile archives | `just test` |
| `LexcalliUITests` | XCTest | Navigation, studying, Mixed practice, and progress kept across app termination | `just ui-test [simulator name or UDID]` |

- Package tests need no simulator; `just test --filter <name>` runs a subset.
- Store contract tests run against both `DatabaseStore` (in-memory SQLite) and `ReferenceStore`, a simple in-memory implementation kept only in tests, so the contract describes behavior rather than GRDB details.
- UI tests launch the app with `LEXCALLI_LIBRARY` (a fresh library per test) and `LEXCALLI_SEED_SAMPLES` (sample decks instead of the starter deck). Locally, `just ui-test` also fails unless every journey listed in `scripts/check_ui_tests.py` ran and passed.
- `just check` runs lint, package tests and the app build before a commit; `just check-all` adds the UI tests. `just fmt` fixes formatting.
- CI ([`swift.yml`](.github/workflows/swift.yml)) runs the same lint, package tests, app build and UI tests on pushes and PRs to `main`, with Xcode 27.2; keep it in sync with the `justfile`.

## Contributor guide

- Review and install the skills listed in `.agents/AGENTS.md`.
- Run `just skill-update` to update installed skills (requires Node.js/npm); review changes before committing.
- Third-party libraries and assets are credited in the app under Settings → About, with version and license.
