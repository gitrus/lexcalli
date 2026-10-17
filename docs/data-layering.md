# Data layering

Lexcalli builds on Anki's established learning model and ecosystem rather than inventing a new flashcard format. We reuse what is useful and add our own language-learning capabilities. This document describes the current product and data boundaries, not a database schema.

## Requirements

- Use Anki-compatible concepts and formats to benefit from existing algorithms, parsers, tools, and community knowledge.
- Import Anki decks and media; preserve a path to exporting compatible decks.
- Support words, collocations, examples, images, and multiple audio recordings (e.g. isolated pronunciation and sentence audio).
- Organize similar vocabulary into topics; support exercises that deliberately contrast related words.
- Support Anki-style flashcards **and** interactive exercises: multiple choice, typing words, listening, completing sentences, arranging words, etc.
- Allow a single exercise to reference several cards, without assuming every referenced card was tested.
- Make new exercises configurable from the backend where feasible; SwiftUI is the intended client.
- Preserve learning and practice history without conflating exercise success with memorization.

## Data layers

### Anki-compatible foundation

- **Notes / fields:** learning content and references to media.
- **Cards:** study prompts derived from notes; different recall directions can be distinct cards.
- **Decks / media:** familiar packaging and organization; images and multiple audio files are supported.
- **Scheduling / review log:** Anki-compatible per-card scheduling and review history, preferably using established FSRS implementations.

Anki compatibility is a domain and interchange boundary, **not a commitment to copy Anki's entire internal database schema or UI**.

### Lexcalli learning extensions

- **Topics and relationships:** group notes and connect words, collocations, and example contexts.
- **Exercise definitions:** describe what is tested, how it is presented, and how an answer is checked.
- **Exercise instances:** reference one or more Anki cards with roles (target, contextual evidence, distractor).
- **Exercise attempts and sessions:** record answers, correctness, hints, time, and associated cards independently of Anki's review log.

**Knowledge accounting:** distractors and context cards do not receive knowledge credit just because the user answered an exercise correctly. Completing an exercise does not automatically become an FSRS review. A designated review must explicitly identify the card assessed and the scheduling rating.

### Application and backend

- **SwiftUI:** native presentation and interaction.
- **Backend:** content/media preparation and declarative, versioned exercise configuration; can support offline downloads and later synchronization.
- **Client:** renders supported exercise components and records outcomes.

## Deliberately not adopted

- **A new proprietary flashcard core:** discards Anki ecosystem compatibility and mature scheduling work.
- **Only Anki's existing UI and templates:** insufficient for richer, multi-card interactive exercises.
- **Every exercise attempt updates FSRS:** conflates recognition, prompted production, and recall; can inflate knowledge estimates.
- **A hard limit of two audio files:** no benefit when notes can reference arbitrary media.
- **Downloadable JavaScript/Wasm plugins initially:** additional complexity and mobile distribution constraints; start with versioned declarative exercises.
- **Copying all Anki internals:** couples us to implementation details and unrelated features.

## Not decided yet

- Which Anki parser / Rust-core components can be integrated and their licensing implications.
- Concrete persistence schema, identifiers, sync conflicts, and offline-first implementation.
- AnkiWeb / two-way sync (not an initial requirement).
- Whether and under what conditions some non-flashcard exercises can count as scheduled reviews.
- Final exercise definition format and media conversion/storage strategy.
