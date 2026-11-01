# Learning engine

## Purpose

Lexcalli is a language-learning application built around spaced repetition and active recall.
The data layer consists of cards and scheduling compatible with Anki's data format.
Keep content, observable practice, and knowledge/scheduling distinct.

## Exercise handling

Exercise terms are defined in the [glossary](glossary.md#practice). The engine handles them through:

- **Exercise types:** declare the interaction, its rules, and required capabilities, not a particular learner's answer.
- **Exercises:** apply an exercise type to one or more cards when shown. References have roles such as target, context, and distractor.

## Exercise evidence

The [product requirements](product.md#required-capabilities) define the supported exercise types. The table below describes the evidence each interaction can provide.

| Type | Example evidence |
| --- | --- |
| Flashcard | Recall and self-rating |
| Choose-one | Recognize the target among distractors |
| Writing | Recall spelling/word form |
| Listen and type or choose | Listening recognition and/or transcription |
| Complete a sentence | Retrieve the appropriate form in context |
| Assemble words into a sentence | Construct a sentence from given pieces |

These are intended interaction types, not promises that each provides an equivalent measure of knowledge.

## First exercise types (draft)

Draft for the first builds; details may change once the exercises are tried.

Only flashcards are built; they affect scheduling. Choose-one and writing are planned: they will record exercise review events only, and how they affect scheduling is decided later (see [Open questions](#open-questions)). Nothing in this section beyond flashcards exists in code yet.

### Choose-one

- Works in both directions: a forward card shows the term and offers meanings; a reverse card shows the meaning and offers terms.
- Offers three options: the expected answer and two distractors from the same deck.
- Distractors match the expected answer's length or word count, so a phrase isn't offered next to single words. Two options with the same meaning never appear together.
- A deck needs at least three notes for this exercise.
- The exercise review event records the options shown and the learner's pick.

### Writing

- Uses the reverse card: shows the meaning, and the learner types the term. Terms can be phrases, for example *πώς σε λένε;*.
- After the attempt, shows the differences between the typed text and the expected answer, like Anki's type-in-the-answer. There is no automatic grading.
- Text is Unicode-normalized before comparison, so equivalent characters match (the Greek question mark `;` and the semicolon). Every difference is shown: accent-only and case-only differences in a lighter style than wrong letters, since both can matter (*πώς* versus *πως*, German *Haus* versus *haus*).
- The exercise review event records the typed text.

## Multi-card behavior

One exercise may reference many cards; each reference has a role. Correct and incorrect responses do not award the same FSRS credit; that credit should be calculated using additional logic.

## Validation and observations

- Each exercise type needs defined expected answers and validation behavior.
- Typing and sentence exercises need an explicit future policy for acceptable variants (inflections, punctuation, accents, spelling and alternative translations).
- Hints, revealed answers, and response modality can affect the strength of knowledge evidence.

## Review logs

Card and exercise history use [two separate review logs](data-layering.md#review-logs). Only the card review log exists today. When an exercise contributes to a card review, link the corresponding log entries according to the exercise type's review rules. Not every exercise attempt produces a card review.

## Relationship to FSRS

- Each card has its own Anki-compatible scheduling state. An explicit scheduled card review updates that state using FSRS.
- Card review events in the card review log are the authoritative scheduling history. Each card's scheduling state must stay consistent with them; how it is kept is defined in [data management](data-management.md#reviews).
- The logic for counting reviews for exercises should be part of the exercise type declaration. The rule must specify the assessed card(s), rating, and treatment of hints and retries.
- Scheduling uses FSRS-6 through the [swift-fsrs](https://github.com/open-spaced-repetition/swift-fsrs) package rather than our own implementation. The package is pinned to a commit on `main`, because its latest tag is FSRS-5, and the FSRS-6 weights are passed explicitly ([`SchedulerDefaults.swift`](../LexcalliKit/Sources/LexcalliCore/SchedulerDefaults.swift)). Rating (1–4) and card state (0–3) values keep Anki's numbering; compatibility tests guard this.


## Deliberately avoided

- **Exercise = card:** rules out exercises with multiple references and different interaction shapes.
- **A separate invented spaced-repetition algorithm:** loses the benefit of Anki/FSRS compatibility.

## Open questions

- How eligible non-flashcard exercises produce card reviews, including rating rules and the treatment of hints and retries.
- Word-level/skill-level knowledge estimation, if it becomes necessary.
- Exercise selection, difficulty adaptation, topic scheduling, distractor selection, and grading policies.
- Schema/protocol for configurable exercise types, validation ownership, and offline execution.
- Whether a retry is part of the same exercise attempt or a new one.
- How a multi-target exercise distributes observations across cards.

See [product](product.md) for user-facing scope and [data layering](data-layering.md) for data ownership.
