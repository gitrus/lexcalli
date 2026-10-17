# Product

## Purpose

Lexcalli is an Anki-compatible language-learning application for practicing vocabulary, collocations, and expressions through flashcards and varied interactive exercises. It combines established spaced-repetition principles with contextual language practice.

## Intended users

- Primarily individual language learners who want to work with their own vocabulary and imported Anki material.
- People practicing not only word recognition but also listening, spelling, recall, and use in sentences.

Specific personas, supported languages, and audience priorities are not yet fixed. Greek vocabulary is an initial use case, not an architectural language restriction.

## Required capabilities

- Import established Anki decks and their associated media; preserve a path to compatible export.
- Support words, collocations, expressions, and example sentences, with images and multiple audio recordings where useful.
- Organize related or easily confused vocabulary into topics and practice them together.
- Support traditional flashcard reviews **and** interactive practice, including multiple choice, typing, audio-based questions, fill-in-the-blank, and sentence assembly.
- Let exercises combine content from multiple cards without implying that every referenced card has been learned.
- Track review history separately from broader exercise activity.
- Support extending exercise configurations/content from the backend without shipping a new client for every variation, within the client's supported components.
- Build an iOS application with SwiftUI; keep the core learning and content model independent of UI technology.

## Product boundaries

- Lexcalli is **not** a full Anki clone. Reuse the valuable model, formats, and algorithms; omit unrelated Anki features.
- Lexcalli is **not** limited to two audio recordings or one-card-only exercises.
- Lexcalli does **not** equate a correct multiple-choice answer with proven memory of every displayed word.
- Arbitrary downloadable executable exercise plugins (JavaScript/Wasm) are not an initial requirement; declarative configurations come first.
- AnkiWeb live synchronization is not an initial commitment; Anki import/export and application data sync are different concerns.

## Open product questions

- First-release feature set and the priority/order of exercise types.
- Whether mixed practice is the default or users explicitly choose review/practice modes.
- Specific offline expectations and device/platform scope beyond iOS.
- Sources and rights for example audio and images; sharing or publishing content.
- What progress feedback users need besides Anki card scheduling.

See [data layering](data-layering.md) for data ownership and [learning engine](learning-engine.md) for exercise/knowledge behavior.
