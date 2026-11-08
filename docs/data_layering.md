# Data layering

Lexcalli is a language-learning application built around spaced repetition and active recall. Currently, the best and most well-established ecosystem is Anki. So Lexcalli builds on top of Anki's established data models, learning model, and ecosystem.
This document describes the current product and data boundaries rather than a database schema.

Terms are defined in the [glossary](glossary.md), and product requirements are defined in [required capabilities](product.md#required-capabilities) and [product boundaries](product.md#product-boundaries). The sections below describe their data representation and ownership.

## Data layers

### Anki-compatible foundation

- **Notes / fields:** learning content and references to media.
- **Cards:** card data derived from notes, including references to the source notes and the study direction.
- **Decks / media:** familiar packaging and organization; images and multiple audio files (e.g., isolated pronunciation and sentence audio) are supported.
- **Scheduling:** Anki-compatible per-card scheduling state.

Anki compatibility is a domain and interchange boundary, **not a commitment to copy Anki's internal database schema or UI**.

### Lexcalli learning extensions

- **Topics and relationships:** group notes and connect words, collocations, and example contexts (for example, these can be covered by a tagging system).
- **Exercise types:** built into the app for now; configurable exercise types (declarative interaction and validation settings) may become Lexcalli data later.
- **Exercise references:** an exercise refers to content and cards in roles such as target, contextual evidence, and distractor.
- **Exercise attempts and practice sessions:** durable exercise events retain confirmed writing/choice responses and prompt/option snapshots. Practice sessions group card and exercise events and persist their Flashcards/Mixed mode.

### Review logs

There are two separate durable review logs.

- **Card review log:** part of the Anki-compatible foundation; records *card review events*: per-card ratings used for scheduling and FSRS.
- **Exercise review log:** part of the Lexcalli learning extensions; records immutable *exercise review events* with kind/version, confirmation time, assessed card/direction, prompt/expected-answer snapshots, raw response or selected option, and ordered option references. Writing stores no automatic grade.

The data layer stores both histories separately. Exercise-only answers currently do not create card reviews or scheduling credit. The [learning engine](learning_engine.md#review-logs) leaves future links between the logs to an explicit policy.

### Application and backend

- The data models should be offline-first.
- The data model should support synchronization (offloading and downloading).
- The data model should include content/media and be declarative.

## Not decided yet

- Persistence beyond content, cards, practice sessions, card/exercise events (see [data management](data_management.md)), sync conflicts, and offline-first implementation.
- AnkiWeb / two-way sync (not an initial requirement).
- Storage representation for configurable exercise types and future links between the two review logs.
- Media conversion/storage strategy.
