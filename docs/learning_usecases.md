# Learning use cases

How a learner practices in the app: screens, controls, and feedback. Terms are defined in the [glossary](glossary.md#practice); the rules behind each flow (queue, exercise selection, what is recorded) are in the [learning engine](learning_engine.md).

## Choosing a practice mode

- The app opens on Practice.
- Each deck shows its statistics above explicit **Flashcards** and **Mixed** buttons, in that order.
- Mixed stays visible but disabled, with an unlock hint, until the deck's first saved card review. Once unlocked, it stays unlocked after relaunch ([availability rule](learning_engine.md#practice-modes)).

## Answering

- **Flashcard:** the learner reveals the answer with **Show Answer**, then rates it (Again, Hard, Good, Easy).
- **Writing and Pick-one:** confirmation locks input before saving. Feedback appears only after the save is acknowledged and remains until **Continue** or **Finish**, including on the last prompt.
- **A failed save** shows **Try Again**. It never advances to the next item or reveals the answer.

## Pick-one

- The label derives from the configured option count (normally **Pick from 4**).
- Tapping an option only selects it; the learner can change the selection until **Check Answer**.
- Before confirmation, neither visible nor accessibility output identifies the correct option.
- After the save, the selected and correct answers are identified by words and symbols, not color alone.

## Writing

- **Check Answer** and the keyboard's **Done** action share one confirmation path. Autocorrection and automatic capitalization are disabled.
- The expected term and answer-side media stay hidden until a successful save.
- When the field opens, it prefers an installed keyboard matching the deck's term language and script; otherwise it keeps the current keyboard. The learner can still switch keyboards manually.
- At accessibility text sizes, **Check Answer** stays reachable.
- After confirmation, answer text appears on the left, with **Actual** and **Expected** labels on the right. Changed characters have red backgrounds in Actual and green backgrounds in Expected; case/accent changes are also italicized and other changes bold. What counts as a change follows the [comparison rules](learning_engine.md#writing).
- A tappable **ⓘ** opens the explanation; VoiceOver describes each changed span, including whitespace and punctuation.

## Repairing a card's schedule

- When a card's saved history can't be applied in order, the session says how many cards couldn't be scheduled from their history and offers **Recalculate**.
- Those cards stay out of every queue, including after relaunch, until Recalculate succeeds ([projection rules](data_management.md#reviews)).

## Session summary

- A Mixed summary counts completed exercises separately from flashcards reviewed.
- It explains that exercise-only work can leave notes due, since Writing and Pick-one don't affect scheduling yet ([relationship to FSRS](learning_engine.md#relationship-to-fsrs)).

## Open questions

- Undo policy for reviews.
- Whether out-of-order history should be recalculated automatically instead of through **Recalculate**.
