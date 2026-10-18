# Product

## Purpose

Lexcalli is a language-learning application built around spaced repetition and active recall. Lexcalli is for practicing vocabulary, collocations, and expressions through flashcards and varied interactive exercises. It combines established spaced-repetition principles with contextual language practice.

## Intended users

- Primarily individual language learners who want to work with their own vocabulary and imported material compatible with Anki's data format.
- People practicing not only word recognition but also listening, spelling, recall, and use in sentences.

Specific personas, supported languages, and audience priorities are not yet fixed. Greek vocabulary is an initial use case, not an architectural language restriction.

## User-facing concepts

- **Learning content:** words, collocations, expressions, meanings, and example sentences, with supporting images and audio.
- **Card:** a study prompt based on learning content, such as recognizing a word or recalling it from its meaning.
- **Topic:** a group of related vocabulary for practice.
- **Exercise:** an interaction used to practice learning content. It may involve one or more cards and is not limited to a flashcard review.
- **Exercise attempt:** a learner's response to an exercise, including any hints used or answers revealed.
- **Scheduled review:** a card review that contributes to future review scheduling; not every exercise attempt is a scheduled review.

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

See [data layering](data-layering.md) for data ownership and [learning engine](learning-engine.md) for exercise/knowledge behavior.
