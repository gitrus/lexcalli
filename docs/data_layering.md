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
- **Exercise references:** an exercise refers to content and cards in roles such as target, contextual evidence, distractor, and companion.
- **Exercise attempts and practice sessions:** durable exercise events retain confirmed writing/choice responses and prompt/option snapshots. Practice sessions group card and exercise events and persist their Flashcards/Mixed mode.

### Review logs

There are two separate durable review logs. Exercise grades and their scheduling effects below describe the agreed target design, not implemented yet.

- **Card review log:** part of the Anki-compatible foundation; records *card review events*: flashcard ratings and imported Anki history. It never holds copies of exercise results.
- **Exercise review log:** part of the Lexcalli learning extensions; records immutable *exercise review events* with kind/version, confirmation time, assessed card/direction, prompt/expected-answer snapshots, raw response, selected option, or pairing, ordered option or pair references, and an optional frozen grade. The grade is recorded once with the event: Again, Hard, or Good, never Easy.

The logs stay separate; the projector takes scheduling observations from card events and graded exercise events in one deterministic `ReviewPosition` order. Only the target card is rated, never distractors or companions. Writing gives Good/Hard/Again, Pick-one gives Good/Again, and Match pairs gives no rating. Ungraded events, including every pre-v3 exercise row, have no scheduling effect and are never backfilled. The [learning engine](learning_engine.md#exercise-grades-target-design) defines the rating rules; [data management](data_management.md#reviews) defines recording, projection, and repair.

### Application and backend

- The data models should be offline-first.
- The data model should support synchronization (offloading and downloading).
- The data model should include content/media and be declarative.

## Not decided yet

- Persistence beyond content, cards, practice sessions, card/exercise events (see [data management](data_management.md)), sync conflicts, and offline-first implementation.
- AnkiWeb / two-way sync (not an initial requirement).
- Storage representation for configurable exercise types.
- Media conversion/storage strategy.
