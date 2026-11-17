# Learning use cases

How a learner practices in the app: screens, controls, and feedback. Terms are defined in the [glossary](glossary.md#practice); the rules behind each flow (queue, exercise selection, what is recorded) are in the [learning engine](learning_engine.md).

## Choosing a practice mode

- The app opens on Practice.
- Each deck shows its statistics above explicit **Flashcards** and **Mixed** buttons, in that order.
- Mixed stays visible but disabled, with an unlock hint, until the deck's first saved card review. Once unlocked, it stays unlocked after relaunch ([availability rule](learning_engine.md#practice-modes)).

## Answering

- **Flashcard:** the learner reveals the answer with **Show Answer**, then rates it (Again, Hard, Good, Easy).
- **Writing, Pick-one, and Match pairs:** confirmation locks input before saving. Feedback appears only after the save is acknowledged and remains until **Continue** or **Finish**, including on the last prompt.
- **A failed save** shows **Try Again**. It never advances to the next item or reveals the answer.

## Pick-one

- The label derives from the configured option count (normally **Pick from 4**).
- Tapping an option only selects it: a filled radio button and a tinted border mark it, and the learner can change it until **Check Answer**.
- Before confirmation, neither visible nor accessibility output identifies the correct option.
- After the save, options stay locked but not dimmed until **Continue**. A ✓ marks the correct option and a ✗ marks a wrong selection, without helper text. Their borders reuse Writing's mistake and correction highlights; VoiceOver still describes the selection and correctness, so color is never the only cue.
- Only after the save, an enabled compact speaker button appears beside the word being learned: to the right of the question for a forward card, or inside the correct option on its right for a reverse card, whether or not it was selected. It reads that word in the term language using a system voice. It stays hidden during a failed save and disappears on **Continue**.
- At accessibility text sizes, the list scrolls after the save so the word being learned and its speaker button are fully visible; **Continue** stays on screen below the list.

## Match pairs

The learner connects every item in one column with its partner in the other ([rules](learning_engine.md#match-pairs)). Confirmation, saving, **Try Again**, and **Continue** work as in Pick-one.

- The label derives from the configured pair count (normally **Match 4 pairs**).
- Two columns: the left holds the queued card's prompt side (terms for a forward card, meanings for a reverse card), the right holds the other side. Each column is shuffled on its own, so the queued word has no fixed row.
- **Pairing:**
  - Tapping an item selects it (filled indicator and tinted border). Tapping it again clears the selection; tapping another item in the same column moves it.
  - With an item selected, tapping an item in the other column makes a pair. Both items get the same number badge (1, 2, 3…) and the same tint, so color is never the only cue.
  - Tapping a paired item breaks its pair and selects it. Pairing an item that already has a partner replaces the old pair; the old partner becomes unpaired.
- **Check Answer** is enabled only when every item is paired. Before confirmation, neither visible nor accessibility output tells which pairs are right.
- **After the save**, the columns are replaced by a locked result list, one row per left item, in left-column order:
  - the left item and the chosen partner, marked ✓ or ✗ without helper text;
  - under a ✗ row, the correct partner, with the correction highlight; the wrong partner uses the mistake highlight, as in Writing and Pick-one;
  - a heading counts the result, for example **3 of 4 pairs correct**;
  - each term has a speaker button that reads it with a system voice in the term language, as Pick-one's speaker does; it disappears on **Continue**;
  - the check/cross icon and speaker are vertically centered within the bordered card, with equal padding above and below the text.
- **VoiceOver** reads each item with its state: *Selected*, *Pair 2, with Hund*, or *Not paired*. After the save it reads each row's correctness and the correct partner, and announces the count.
- **At accessibility text sizes**, the columns stack: the left column's section above the right one's, each with a heading (**Words** or **Meanings**). The screen scrolls and **Check Answer** stays reachable. After the save, the result list scrolls to the first wrong row, or to the heading if all are correct; **Continue** stays on screen below it.
- Pairing in progress is screen state, like typed text in Writing: it is lost if the app is terminated, and the reopened session draws a new exercise for that note.

## Writing

- **Check Answer** and the keyboard's **Done** action share one confirmation path. Autocorrection and automatic capitalization are disabled.
- The expected term and answer-side media stay hidden until a successful save.
- When the field opens, it prefers an installed keyboard matching the deck's term language and script; otherwise it keeps the current keyboard. The learner can still switch keyboards manually.
- At accessibility text sizes, **Check Answer** stays reachable.
- After confirmation, answer text appears on the left, with **Actual** and **Expected** labels on the right. Changed characters are highlighted as mistakes in Actual and as corrections in Expected; case/accent changes are also italicized and other changes bold. What counts as a change follows the [comparison rules](learning_engine.md#writing).
- A tappable **ⓘ** opens the explanation; VoiceOver describes each changed span, including whitespace and punctuation.

## Repairing a card's schedule

- When a card's saved history can't be applied in order, the session says how many cards couldn't be scheduled from their history and offers **Recalculate**.
- Those cards stay out of every queue, including after relaunch, until Recalculate succeeds ([projection rules](data_management.md#reviews)).

## Session summary

- A Mixed summary counts completed exercises separately from flashcards reviewed.
- It explains that exercise-only work can leave notes due, since exercises don't affect scheduling yet ([relationship to FSRS](learning_engine.md#relationship-to-fsrs)).

## Open questions

- Undo policy for reviews.
- Whether out-of-order history should be recalculated automatically instead of through **Recalculate**.
