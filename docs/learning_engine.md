# Learning engine

## Purpose

Lexcalli is a language-learning application built around spaced repetition and active recall.
The data layer consists of cards and scheduling compatible with Anki's data format.
Keep content, observable practice, and knowledge/scheduling distinct.

This document covers the rules behind practice. What the learner sees and does is described in [learning use cases](learning_usecases.md).

**Target design.** Exercise grades and their FSRS effects below are agreed behaviour, not implemented yet.

## Exercise handling

Exercise terms are defined in the [glossary](glossary.md#practice). The engine handles them through:

- **Exercise types:** declare the interaction, its rules, required capabilities, and grading rule, not a particular learner's answer.
- **Exercises:** apply an exercise type to one or more cards when shown. References have roles such as target, context, and distractor.

## Exercise evidence

The [product requirements](product.md#required-capabilities) define the supported exercise types. The table below describes the evidence each interaction can provide.

| Type | Example evidence |
| --- | --- |
| Flashcard | Recall and self-rating |
| Pick-one | Recognize the target among distractors |
| Match pairs | Recognize the target pair among companion pairs; elimination makes it weaker than Pick-one |
| Writing | Recall spelling/word form |
| Listen and type or choose | Listening recognition and/or transcription |
| Complete a sentence | Retrieve the appropriate form in context |
| Assemble words into a sentence | Construct a sentence from given pieces |

These are intended interaction types, not promises that each provides an equivalent measure of knowledge.

## Practice modes

Both modes study the same ordered queue of due notes, one card per note, prepared when the session opens (see [data management](data_management.md#reviews)).

Each round includes at most 22 notes in either mode. Saved answers count toward that limit when the same open session is retried. Other due notes remain due for a later round.

- **Flashcards:** every item is a flashcard. Each answer is a card review and affects scheduling.
- **Mixed:** when the session opens, the engine freezes one exercise per note, chosen uniformly among the exercise types eligible for that card: flashcard, Writing, Pick-one, or Match pairs. A card with no other eligible type gets a flashcard. The frozen exercise stays the same for the item's whole presentation, including save retries. A session reopened after termination draws again for the notes not yet answered.

Mixed is available once the deck has at least one durably saved card review. Availability doesn't depend on projection or session completion, and it survives relaunch.

Flashcards record card reviews. Writing, Pick-one, and Match pairs record exercise attempts in their own log, never copies in the card review log. In the target design, Writing and Pick-one also carry a frozen grade that affects the target card's scheduling; Match pairs carries no grade and has no scheduling effect (see [Exercise grades](#exercise-grades-target-design)).

An exercise answer is saved before its result is revealed. A failed save keeps the original pending event, so a retry resends the same idempotency key and never records a second attempt.

## Exercise types

### Pick-one

- Works in both directions: a forward card shows the term and offers meanings; a reverse card shows the meaning and offers terms.
- Uses an option count set in code, default four, including exactly one expected answer and same-deck distractors. Insufficient distinct candidates make the type ineligible; the count is never reduced.
- A replaceable ordered pipeline prefers matching word count, then similar length, relaxing to less-similar candidates when needed. Distinct normalized answer text is enforced independently of pipeline stages; this is not semantic synonym detection.
- The exercise review event records ordered option snapshots, note references, target identity, and the confirmed selection.

### Match pairs

The first exercise that works with several cards at once. What the learner sees is in [learning use cases](learning_usecases.md#match-pairs).

- **References.** The queued card is the *target*. The other pairs come from *companion* notes in the same deck, chosen like Pick-one distractors (same pipeline, same direction). Companions are full items the learner works with, but they are not assessed: matching them records no card review and no credit, and it doesn't mean their notes have been learned.
- **Direction.** Follows the queued card: a forward card puts terms on the left and meanings on the right; a reverse card swaps them.
- **Pair count.** Set in code, default four, minimum two, including the target pair. A deck with too few valid candidates makes the type ineligible; the count is never reduced.
- **Validity.** Every pair has a non-blank prompt and answer. Using Pick-one's normalization, all left texts are distinct and all right texts are distinct, so every item has exactly one correct partner. Each pair's left and right items come from the same note.
- **Response.** A complete one-to-one pairing of left items to right items, each identified by its note. A pairing that leaves an item out or uses an item twice is rejected before saving.
- **Result.** Each pair is right or wrong; the target pair's result is kept apart from the companions'. The count of right pairs is feedback, not a scheduling grade. Match pairs gives no rating, including for the target.
- **Evidence.** Recognition among a small set, weaker than Pick-one: after three right pairs the fourth is forced, so a correct target pair may come from elimination.
- **Event.** The exercise review event records the ordered left and right snapshots (text and note references), the target identity, and the confirmed pairing. It is keyed by the target card, like Pick-one.
- **Mixed.** Joins the uniform choice among eligible types, so it is drawn about as often as each of the other types a card qualifies for.

### Writing

- Always asks for the term, so it assesses the reverse card even when the queue picked the forward one: it shows the meaning, and the learner types the term. Terms can be phrases, for example *πώς σε λένε;*.
- Comparison shows differences independently of the [exercise grade](#exercise-grades-target-design).
- Leading and trailing whitespace is ignored on both sides of the comparison; internal whitespace still matters. Equivalent Unicode characters match (including the Greek question mark and semicolon). Within the trimmed text, accent-only and case-only differences remain visible, since both can matter (*πώς* versus *πως*, German *Haus* versus *haus*). Unicode case folding also treats final/medial Greek sigma as a soft difference.
- The exercise review event retains the original, untrimmed typed text and prompt/expected-answer snapshots. Whitespace-only submissions are rejected.

### Exercise grades (target design)

Each exercise type declares its grading rule. The grade is computed once when the answer is recorded and frozen in the exercise event. It can be Again, Hard, or Good, never Easy. Replay uses the stored grade; changing a grading rule does not re-grade history.

| Exercise | Good | Hard | Again |
| --- | --- | --- | --- |
| Writing | Matches the expected answer after normalization | Equal after stripping accents too, or a small typo: edit distance ≤ max(1, ⌊length/5⌋) on the accent-stripped normalized text | Anything else |
| Pick-one | Correct option selected | — | Wrong option selected |
| Match pairs | — | — | — |

- **Writing normalization:** trim leading and trailing whitespace, collapse internal whitespace, compare case-insensitively, and ignore trailing `! . ? ; ,`. Test for Good before stripping accents or allowing typos for Hard. This grading rule is separate from the visible comparison, which still shows differences.
- **Alternatives:** `/` alternatives in expected Writing answers, such as `Καλώς ήρθες/ήρθατε`, are out of scope and remain Again. Supporting them is a follow-up.
- **Empty input:** whitespace-only Writing submissions are rejected before recording, not graded.
- **No rating:** Match pairs stays in the exercise log only and produces no scheduling observation. Events recorded before schema v3 also remain ungraded, with no backfill.
- **UI and export:** showing or overriding a grade, and exporting exercise grades to Anki, are separate work; this design does not add them.

## Multi-card behavior

Only the target card identified by the exercise is rated, never a distractor or companion. Writing rates the reverse card it assesses, even when the queue selected the forward card. Pick-one rates its target in the shown direction. Match pairs rates no card, including its target.

## Validation and observations

- Each exercise type needs defined expected answers and validation behavior.
- Writing uses the [agreed grading rule](#exercise-grades-target-design). Acceptable variants for future typing and sentence exercises still need an explicit policy.
- Hints, revealed answers, and response modality can affect the strength of knowledge evidence.

## Review logs

Card and exercise history use [two separate review logs](data_layering.md#review-logs). The card log contains flashcard ratings and imported Anki history. An exercise attempt stays in the exercise log, with its optional frozen grade; it never creates a card review event. A save retry resends the same event, idempotency key, and grade, not a second attempt. The same key with a different grade is a conflict.

The projector takes scheduling observations from card events and graded exercise events. Match pairs and other ungraded events contribute neither scheduling observations nor repair counts. Recording waits only for the event insert; projection still happens at session end or Recalculate, as described in [data management](data_management.md#reviews).

## Relationship to FSRS

- Each card has its own Anki-compatible scheduling state, derived from its baseline and one ordered stream of scheduling observations from both logs.
- A scheduling observation carries the card, rating, and `ReviewPosition`: answer time in whole milliseconds, then the event's UUID idempotency key. This order applies across both logs, not separately within each one.
- Projection is a deterministic fold. The same baseline and events give the same state on every device, regardless of arrival order. Projecting from a checkpoint must equal a full rebuild; earlier arrivals are handled through the existing out-of-order repair flow, not appended after newer observations.
- The exercise type owns the grading rule, but the recorded event owns the historical grade. Replay never recomputes it. Events recorded before v3 remain ungraded and never acquire scheduling credit retroactively.
- Scheduling uses FSRS-6 through the [swift-fsrs](https://github.com/open-spaced-repetition/swift-fsrs) package rather than our own implementation. The package is pinned to a commit on `main`, because its latest tag is FSRS-5, and the FSRS-6 weights are passed explicitly (domain `SchedulerDefaults`). Rating (1–4) and card state (0–3) values keep Anki's numbering; compatibility tests guard this.


## Deliberately avoided

- **Exercise = card:** rules out exercises with multiple references and different interaction shapes.
- **A separate invented spaced-repetition algorithm:** loses the benefit of Anki/FSRS compatibility.

## Open questions

- Supporting `/` alternatives in expected Writing answers.
- Whether and how a learner can override a grade. An override must be a new event, never an edit to the original.
- Word-level/skill-level knowledge estimation, if it becomes necessary.
- Exercise selection, difficulty adaptation, topic scheduling, and distractor selection.
- Schema/protocol for configurable exercise types, validation ownership, and offline execution.

See:
- [product](product.md) for user-facing scope
- [learning use cases](learning_usecases.md) for practice flows
- [data layering](data_layering.md) for data ownership
