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
| Pick-one | Recognize the target among distractors |
| Writing | Recall spelling/word form |
| Listen and type or choose | Listening recognition and/or transcription |
| Complete a sentence | Retrieve the appropriate form in context |
| Assemble words into a sentence | Construct a sentence from given pieces |

These are intended interaction types, not promises that each provides an equivalent measure of knowledge.

## First exercise types

Flashcards record card reviews and affect scheduling. Writing and Pick-one record separate exercise attempts; they temporarily do not affect FSRS. This keeps observable practice distinct from scheduling evidence until explicit exercise-to-card-review rules are defined (see [Open questions](#open-questions)).

Tapping a deck starts Flashcards. A separate Mixed entry becomes available after its first durably saved card review, independently of projection or session completion; this availability survives relaunch. Mixed uses the existing ordered due-note queue and freezes one uniformly selected eligible exercise per note.

Confirmation locks input before saving. Feedback appears only after acknowledgement and remains until Continue or Finish, including on the last prompt. A failed save keeps the original pending event and exposes Try Again; it never advances or reveals the answer. Mixed summaries distinguish completed exercises from flashcards reviewed and explain that exercise-only work can leave notes due.

### Pick-one

- Works in both directions: a forward card shows the term and offers meanings; a reverse card shows the meaning and offers terms.
- Uses a configurable option count, default four, including exactly one expected answer and same-deck distractors. Insufficient distinct candidates make the type ineligible; the count is never reduced.
- A replaceable ordered pipeline prefers matching word count, then similar length, relaxing to less-similar candidates when needed. Distinct normalized answer text is enforced independently of pipeline stages; this is not semantic synonym detection.
- The label derives from the configured count (normally **Pick from 4**). Tapping an option only selects it; the learner can change selection until **Check Answer**. Confirmation saves before revealing selected/correct answers, identified by words and symbols rather than color alone.
- The exercise review event records ordered option snapshots, note references, target identity, and the confirmed selection. Before confirmation, neither visible nor accessibility output identifies the correct option.

### Writing

- Uses the reverse card: shows the meaning, and the learner types the term. Terms can be phrases, for example *πώς σε λένε;*.
- **Check Answer** and the keyboard's **Done** action share one confirmation path. Autocorrection and automatic capitalization are disabled. The expected term and answer-side media are absent until a successful save.
- After confirmation, both original strings remain readable with case/accent changes italicized and other changes bold. VoiceOver gets a description of each changed span, including whitespace, with punctuation spoken. There is no automatic grading.
- Text is Unicode-normalized before comparison, so equivalent characters match (the Greek question mark `;` and the semicolon). Every difference is shown: accent-only and case-only differences in a lighter style than wrong letters, since both can matter (*πώς* versus *πως*, German *Haus* versus *haus*).
- The exercise review event retains the original, untrimmed typed text and prompt/expected-answer snapshots. Whitespace-only submissions are rejected. Unicode case folding also treats final/medial Greek sigma as a soft difference.

## Multi-card behavior

One exercise may reference many cards; each reference has a role. Correct and incorrect responses do not award the same FSRS credit; that credit should be calculated using additional logic.

## Validation and observations

- Each exercise type needs defined expected answers and validation behavior.
- Typing and sentence exercises need an explicit future policy for acceptable variants (inflections, punctuation, accents, spelling and alternative translations).
- Hints, revealed answers, and response modality can affect the strength of knowledge evidence.

## Review logs

Card and exercise history use [two separate review logs](data-layering.md#review-logs). Both logs are durable. The two new exercise types append only exercise events; flashcards in either mode append normal card reviews. Exercise events are excluded from FSRS projection and repair calculations. Future links between logs require an explicit scheduling policy; not every exercise attempt produces a card review.

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
