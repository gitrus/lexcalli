# Data layering

Lexcalli is a language-learning application built around spaced repetition and active recall. Currently, the best and most well-established ecosystem is Anki. So Lexcalli builds on top of Anki's established data models, learning model, and ecosystem.
This document describes the current product and data boundaries rather than a database schema.

User-facing definitions are in [product concepts](product.md#user-facing-concepts), and product requirements are defined in [required capabilities](product.md#required-capabilities) and [product boundaries](product.md#product-boundaries). The sections below describe their data representation and ownership.

## Data layers

### Anki-compatible foundation

- **Notes / fields:** learning content and references to media.
- **Cards:** card data derived from notes, including references to the source notes and the study direction.
- **Decks / media:** familiar packaging and organization; images and multiple audio files (e.g., isolated pronunciation and sentence audio) are supported.
- **Scheduling:** Anki-compatible per-card scheduling state.

Anki compatibility is a domain and interchange boundary, **not a commitment to copy Anki's internal database schema or UI**.

### Lexcalli learning extensions

- **Topics and relationships:** group notes and connect words, collocations, and example contexts (for example, these can be covered by a tagging system).
- **Exercise definitions:** declarative configurations for exercise interactions and validation.
- **Exercise instances:** references to content and Anki cards, including their roles (target, contextual evidence, distractor).
- **Exercise attempts and sessions:** records associated with exercise instances; attempt details belong in the exercise review log.

### Review logs

There will be two separate review logs:

- **Card review log:** part of the Anki-compatible foundation; records per-card review events and ratings used for scheduling and FSRS.
- **Exercise review log:** part of the Lexcalli learning extensions; records exercise attempts, answers, correctness, hints, timing, and references to the cards involved.

The data layer stores both histories and references between related entries. The [learning engine](learning-engine.md#review-logs) defines when and how those links are created.

### Application and backend

- The data models should be offline-first.
- The data model should support synchronization (offloading and downloading).
- The data model should include content/media and be declarative.

## Not decided yet

- Concrete persistence schema, identifiers, sync conflicts, and offline-first implementation.
- AnkiWeb / two-way sync (not an initial requirement).
- Storage representation for exercise definitions, attempts, and links between the two review logs.
- Media conversion/storage strategy.
