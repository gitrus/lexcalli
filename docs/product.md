# Product

## Purpose

Lexcalli is a language-learning application built around spaced repetition and active recall. Lexcalli is for practicing vocabulary, collocations, and expressions through flashcards and varied interactive exercises. It combines established spaced-repetition principles with contextual language practice.

## Intended users

- Primarily individual language learners who want to work with their own vocabulary and imported material compatible with Anki's data format.
- People practicing not only word recognition but also listening, spelling, recall, and use in sentences.

Specific personas, supported languages, and audience priorities are not yet fixed. Greek vocabulary is an initial use case, not an architectural language restriction.

## User-facing concepts

Learning content, cards, topics, exercises, exercise attempts, and scheduled reviews are defined in the [glossary](glossary.md).

## Required capabilities

- Use Anki-compatible concepts and formats to benefit from existing tools and community knowledge.
- Import established Anki-compatible decks and their associated media; preserve a path to compatible export.
- Support words, collocations, expressions, and example sentences, with images and multiple audio recordings where useful.
- Organize related vocabulary into topics for practice, including exercises that deliberately contrast similar words.
- Support traditional flashcard reviews **and** interactive practice, including multiple choice, typing, audio-based questions, fill-in-the-blank, and sentence assembly.
- Let exercises combine content from multiple cards without implying that every referenced card has been learned.
- Track review history separately from broader exercise activity.
- Support extending exercise configurations/content from the backend without shipping a new client for every variation, within the client's supported components.
- Build an iOS application with SwiftUI; keep the core learning and content model independent of UI technology.

## Product boundaries

- Lexcalli is **not** a clone. Reuse the valuable model, formats, and common algorithms.
- Lexcalli is **not** limited to two media/audio recordings or one-card-only exercises.
- Lexcalli does **not** equate a correct exercise response (like a multiple-choice answer) with proven memory. We need a separate algorithm.
- Declarative exercise configurations are first-class citizens.
- Anki import/export and application data sync are part of the next steps.

## Open product questions

- First-release feature set and the priority/order of exercise types.
- Whether mixed practice is the default or users explicitly choose review/practice modes.
- Whether non-flashcard exercises should count as scheduled card reviews.
- Specific offline expectations and device/platform scope beyond iOS.
- Sources and rights for example audio and images; sharing or publishing content.
- What progress feedback users need besides Anki card scheduling.

See:
- [data layering](data-layering.md) for data ownership
- [learning use cases](learning-use-cases.md) for practice flows
