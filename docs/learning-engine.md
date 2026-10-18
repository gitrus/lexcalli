# Learning engine

## Purpose

Lexcalli is a language-learning application built around spaced repetition and active recall.
The data layer consists of cards and scheduling compatible with Anki's data format.
Keep content, observable practice, and knowledge/scheduling distinct.

## Exercise handling

The [user-facing concepts](product.md#user-facing-concepts) are defined in the product document. The engine handles them through:

- **Exercise definitions:** declare the interaction and required capabilities, not a particular learner's answer.
- **Exercise instances:** bind a concrete question to one or more cards/content items. References have roles such as target, context, and distractor.

## Exercise evidence

The [product requirements](product.md#required-capabilities) define the supported exercise types. The table below describes the evidence each interaction can provide.

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

One exercise may reference many cards; each reference has a role. Correct and incorrect responses do not award the same FSRS credit; that credit should be calculated using additional logic.

## Validation and observations

- Each exercise type needs defined expected answers and validation behavior.
- Typing and sentence exercises need an explicit future policy for acceptable variants (inflections, punctuation, accents, spelling and alternative translations).
- Hints, revealed answers, and response modality can affect the strength of knowledge evidence.

## Review logs

Card and exercise history use [two separate review logs](data-layering.md#review-logs). When an exercise contributes to a card review, link the corresponding log entries according to the exercise type's review rules. Not every exercise attempt produces a card review.

## Relationship to FSRS

- Each card has its own Anki-compatible scheduling state. An explicit scheduled card review updates that state using FSRS.
- Card review state and the card review log remain the authoritative scheduling data.
- The logic for counting reviews for exercises should be part of the exercise type declaration. The rule must specify the assessed card(s), rating, and treatment of hints and retries.


## Deliberately avoided

- **Exercise = card:** rules out exercises with multiple references and different interaction shapes.
- **A separate invented spaced-repetition algorithm:** loses the benefit of Anki/FSRS compatibility.

## Open questions

- How eligible non-flashcard exercises produce card reviews, including rating rules and the treatment of hints and retries.
- Word-level/skill-level knowledge estimation, if it becomes necessary.
- Exercise selection, difficulty adaptation, topic scheduling, distractor selection, and grading policies.
- Schema/protocol for exercise definitions, validation ownership, and offline execution.
- How a multi-target exercise distributes observations across cards.

See [product](product.md) for user-facing scope and [data layering](data-layering.md) for data ownership.
