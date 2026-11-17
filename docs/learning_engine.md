# Learning engine

## Purpose

Lexcalli is a language-learning application built around spaced repetition and active recall.
The data layer consists of cards and scheduling compatible with Anki's data format.
Keep content, observable practice, and knowledge/scheduling distinct.

This document covers the rules behind practice. What the learner sees and does is described in [learning use cases](learning_usecases.md).

## Exercise handling

Exercise terms are defined in the [glossary](glossary.md#practice). The engine handles them through:

- **Exercise types:** declare the interaction, its rules, and required capabilities, not a particular learner's answer.
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

Flashcards record card reviews and affect scheduling. Writing, Pick-one, and Match pairs record separate exercise attempts; they temporarily do not affect FSRS. This keeps observable practice distinct from scheduling evidence until explicit exercise-to-card-review rules are defined (see [Open questions](#open-questions)).

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
- **Result.** Each pair is right or wrong; the target pair's result is kept apart from the companions'. There is no partial grade beyond the count of right pairs.
- **Evidence.** Recognition among a small set, weaker than Pick-one: after three right pairs the fourth is forced, so a correct target pair may come from elimination.
- **Event.** The exercise review event records the ordered left and right snapshots (text and note references), the target identity, and the confirmed pairing. It is keyed by the target card, like Pick-one.
- **Mixed.** Joins the uniform choice among eligible types, so it is drawn about as often as each of the other types a card qualifies for.

### Writing

- Always asks for the term, so it assesses the reverse card even when the queue picked the forward one: it shows the meaning, and the learner types the term. Terms can be phrases, for example *πώς σε λένε;*.
- Comparison shows differences; there is no automatic grading.
- Leading and trailing whitespace is ignored on both sides of the comparison; internal whitespace still matters. Equivalent Unicode characters match (including the Greek question mark and semicolon). Within the trimmed text, accent-only and case-only differences remain visible, since both can matter (*πώς* versus *πως*, German *Haus* versus *haus*). Unicode case folding also treats final/medial Greek sigma as a soft difference.
- The exercise review event retains the original, untrimmed typed text and prompt/expected-answer snapshots. Whitespace-only submissions are rejected.

## Multi-card behavior

One exercise may reference many cards; each reference has a role. Once exercises award FSRS credit, a referenced card's credit depends on its role and on the response, not just on being shown; that rule is still open (see [Open questions](#open-questions)).

## Validation and observations

- Each exercise type needs defined expected answers and validation behavior.
- Typing and sentence exercises need an explicit future policy for acceptable variants (inflections, punctuation, accents, spelling and alternative translations).
- Hints, revealed answers, and response modality can affect the strength of knowledge evidence.

## Review logs

Card and exercise history use [two separate review logs](data_layering.md#review-logs). Both logs are durable. Exercise types other than flashcards append only exercise events; flashcards in either mode append normal card reviews. Exercise events are excluded from FSRS projection and repair calculations. Future links between logs require an explicit scheduling policy; not every exercise attempt produces a card review.

## Relationship to FSRS

- Each card has its own Anki-compatible scheduling state. An explicit scheduled card review updates that state using FSRS.
- Card review events in the card review log are the authoritative scheduling history. Each card's scheduling state must stay consistent with them; how it is kept is defined in [data management](data_management.md#reviews).
- The logic for counting reviews for exercises should be part of the exercise type declaration. The rule must specify the assessed card(s), rating, and treatment of hints and retries.
- Scheduling uses FSRS-6 through the [swift-fsrs](https://github.com/open-spaced-repetition/swift-fsrs) package rather than our own implementation. The package is pinned to a commit on `main`, because its latest tag is FSRS-5, and the FSRS-6 weights are passed explicitly (domain `SchedulerDefaults`). Rating (1–4) and card state (0–3) values keep Anki's numbering; compatibility tests guard this.


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
- For Match pairs: whether companion pairs ever count as observations of their cards, and how a forced last pair should discount the target's result.

See:
- [product](product.md) for user-facing scope
- [learning use cases](learning_usecases.md) for practice flows
- [data layering](data_layering.md) for data ownership
