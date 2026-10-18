# lexcalli
An Anki-inspired language-learning app for mastering vocabulary, collocations, and expressions through spaced repetition, active recall, and interactive exercises.

## Development notes

- [Docs](docs/README.md) — documentation for recording project decisions.
- [Agent instructions](AGENTS.md) — entry point for coding agents.
- [Agent skills](.agents/AGENTS.md) — reference for installed skills, iOS engineering conventions, SwiftUI architecture conventions, and verification guidance.

## Getting started

- Requirements: Xcode 26.4+ (Swift 6.3+) and [just](https://github.com/casey/just).
- `just open` opens the project; `just run` launches the app in a simulator (`just run booted` reuses the one already open); `just check` runs lint, core tests and the app build.

## Contributor guide

- Review and install the skills listed in `.agents/AGENTS.md`.
- Run `just skill-update` to update installed skills; review changes before committing.
