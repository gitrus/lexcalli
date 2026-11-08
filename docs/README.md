# Docs

This directory contains decisions and notes related to the project.

## Contents

- [Review checklist](../.agents/review-checklist.md) — what not to forget about navigation, async work, recovery, data access, accessibility, and behavioral verification.

- [Glossary](glossary.md) — shared terms and their Anki equivalents.
- [Product](product.md) — purpose, intended users, required capabilities, product boundaries, and open questions.
- [Data layering](data_layering.md) — Anki-data-format compatible foundations, Lexcalli extensions, data ownership, and application/backend requirements.
- [Data management](data_management.md) — how the iOS app stores data (persistence engine, media, preferences, migrations) and passes it to SwiftUI views.
- [Learning engine](learning_engine.md) — exercise/knowledge internal technical concepts: cards, exercises, practice modes, practice history, validation, and the relationship to FSRS scheduling.
- [Learning use cases](learning_usecases.md) — how a learner practices: choosing a mode, answering each exercise type, feedback, and session summaries.
- [Data use cases](data_usecases.md) — what the learner sees of their library: first launch, opening after an update, import, and export.
- [The way](the_way.md) — development workflow, verification, data invariants, delivery, and release practices.
