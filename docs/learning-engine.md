# Learning engine

## Purpose

Use Anki-compatible cards and scheduling as the established review foundation while supporting richer language-learning exercises. Keep content, observable practice, and knowledge/scheduling distinct.

## Concepts and relationships

- **Learning content:** Anki notes and fields hold words, collocations, meanings, and examples; media is attached or referenced. Topics and relationships are Lexcalli extensions.
- **Card:** An Anki card expresses one study prompt/direction from a note (for example recognition versus production), with its own review state.
- **Exercise definition:** describes the interaction and required capabilities, not a particular learner's answer.
- **Exercise instance:** concrete question built from one or more cards/content items. References have roles such as target, context, and distractor.
- **Exercise attempt/session:** captures interaction, answer, correctness and optional timing/hints, independently of Anki review events.
- **Review / scheduling:** explicit scheduled card review updates Anki-compatible per-card state and review history (FSRS-oriented). Not every exercise attempt is a review.

A card is a scheduling unit. A note/word is not automatically a single scalar unit of knowledge; separately tracked skill-level mastery is **not yet decided**.

## Required exercise capabilities

| Type | Example evidence |
| --- | --- |
| Flashcard | Recall and self-rating |
| Multiple choice | Recognize the target among distractors |
| Type a word or collocation | Recall spelling/word form |
| Listen and type or choose | Listening recognition and/or transcription |
| Complete a sentence | Retrieve the appropriate form in context |
| Assemble words into a sentence | Construct a sentence from given pieces |

These are intended interaction types, not promises that each provides an equivalent measure of knowledge.

## Multi-card behavior

One exercise may reference many cards; each reference has a role. A correct response concerning one target does **not** award credit to distractors or other cards shown for context. Some exercises may assess more than one target; the attribution policy must be explicit rather than inferred.

## Validation and observations

- Each exercise type needs defined expected answers and validation behavior.
- Store the observed answer and evaluation separately from review scheduling.
- Typing and sentence exercises need an explicit future policy for acceptable variants (inflections, punctuation, accents, spelling and alternative translations).
- Hints, revealed answers, and response modality can affect the strength of evidence; do not silently convert correctness into mastery.

## Relationship to FSRS

- Anki card review state and review history remain the authoritative scheduling data.
- Exercise attempts belong to Lexcalli history, even if an instance references Anki cards.
- Only an explicitly designated scheduled review should currently change FSRS state. If another exercise type is later permitted to count as a review, the rule must specify the assessed card(s), rating, and treatment of hints and retries.
- Keep review and exercise history linked where applicable, but avoid duplicate review events.

## Backend-driven extensibility

- The backend may return **versioned declarative** exercise definitions and content references.
- SwiftUI renders supported interaction primitives and validates/records answers according to an agreed contract.
- Media and exercises must be usable with the appropriate client capabilities; unsupported configurations need a defined fallback.
- No arbitrary downloaded JavaScript or Wasm execution initially: avoid a second mobile runtime and code-distribution complexity.

## Deliberately avoided

- **Exercise = Anki card:** rules out exercises with multiple references and different interaction shapes.
- **Every successful exercise updates knowledge:** overstates what recognition or hints demonstrate.
- **A separate invented spaced-repetition algorithm:** loses the benefit of Anki/FSRS compatibility.
- **Hardcoded exercise variants per release:** unnecessarily couples content authoring to client releases.

## Open questions

- Whether an exercise can ever update FSRS directly, and which kinds of evidence justify doing so.
- Word-level/skill-level knowledge estimation, if it becomes necessary.
- Exercise selection, difficulty adaptation, topic scheduling, distractor selection, and grading policies.
- Schema/protocol for exercise definitions, validation ownership, and offline execution.
- How a multi-target exercise distributes observations across cards.

See [product](product.md) for user-facing scope and [data layering](data-layering.md) for data ownership.
