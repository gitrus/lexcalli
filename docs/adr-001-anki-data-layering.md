# ADR-001: Anki-based data layering

Status: Accepted (conceptual boundaries); implementation details pending
Date: 2026-10-17

## Context

Lexcalli combines Anki-style flashcard review with richer language exercises (recognition, typing, listening, sentence completion, and construction). We want to reuse established Anki concepts, parsers, formats, and scheduling algorithms rather than invent a competing flashcard standard. An exercise may involve multiple cards, and exercise success is not automatically evidence of mastery of every referenced card.

## Decision

Build on Anki's domain concepts and compatibility formats, omitting unrelated application features. Add Lexcalli-owned structures above that foundation, without changing the meaning of Anki's card scheduling and review log.

### Layer 1 — Anki-compatible learning core

- **Notes and fields** hold learning material; **cards** represent study prompts/directions generated from notes; **decks** organize cards.
- **Media** is referenced by note content and includes audio/images. Multiple recordings per note or item are allowed; do not impose a two-file limit.
- **Scheduling and review state** belong to individual cards. Preserve Anki/FSRS semantics and review events (e.g., `revlog`).
- Support import/export of common Anki deck packages (`.apkg`), including media. Whether scheduling history is included depends on the export/import workflow.
- Reuse existing parsers and scheduling implementations where practical, rather than copying Anki's internal database schema as a permanent public contract.

### Layer 2 — Lexcalli learning domain

- **Topics, collocations, vocabulary relations, and contextual examples** organize and relate learning content, referencing notes/cards rather than replacing them.
- **Exercise definitions** specify an interaction and its required content/capabilities (flashcard, multiple choice, typing, audio recognition, fill-in-the-blank, sentence assembly, etc.).
- **Exercise instances** can reference *multiple cards*, with explicit roles such as target, context, and distractor. Not every referenced card is being tested.
- **Exercise attempts and sessions** retain answers, correctness, timing, hints, and referenced cards as separate application history.
- An exercise attempt **does not automatically produce an Anki review**. Only an explicitly designated card review updates scheduling state and Anki-compatible review history. A future policy may map selected exercises to reviews, but it must specify which card was assessed and how an FSRS rating was obtained.

### Layer 3 — Application and delivery

- SwiftUI client renders reviews and interactive exercises, supports downloaded media and offline practice, and synchronizes changes.
- The backend may provide declarative, versioned exercise descriptions; the client executes supported native components.
- Downloadable arbitrary JavaScript/Wasm exercise plugins are **not part of the initial architecture**. Extensibility should first come from data/configuration, with capability negotiation and safe fallbacks.

## Ownership and data flow

```text
Anki-compatible notes/cards/decks/media
                 |
                 v
Lexcalli topics, relations, exercise definitions
                 |
                 v
Exercise instances -> attempts/sessions (Lexcalli history)
                 |
                 +-- explicit scheduled card review --> Anki card state + review log
```

The Anki-compatible core is authoritative for card scheduling; Lexcalli history is authoritative for richer exercise observations. The two histories are related but distinct. Preserve stable references between them and never infer mastery of distractor cards from a correct answer.

## Scope boundaries

- **In scope:** Anki-compatible data and import/export, FSRS-aligned reviews, richer exercises, multi-card references, and media.
- **Not committed:** AnkiWeb/two-way sync, binary/database compatibility with every Anki version, exposing Anki add-ons, or a specific embedded Anki Rust-core integration.
- **Excluded initially:** full replication of Anki's UI and unrelated legacy features.

## Consequences and follow-up

- Prefer compatibility adapters and clear ownership boundaries over forking Anki's entire application.
- Investigate Anki's Rust library API, format/version differences, FSRS implementation, licensing, and mobile integration before selecting concrete persistence or scheduling libraries.
- Define IDs, sync conflict behavior, schema versioning, and how designated exercise reviews map to scheduler ratings in later ADRs.
