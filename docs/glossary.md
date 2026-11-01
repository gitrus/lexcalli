# Glossary

Shared terms used across the docs. Other documents link here instead of redefining a term.
Storage mechanics (projector, checkpoint, outbox) are described where they are used, in [data management](data-management.md).
Terms marked *(planned)* have no implementation yet.

## Content

- **Learning content:** words, collocations, expressions, meanings, and example sentences, with supporting images and audio.
- **Note:** one item of learning content: a word, a collocation, or a phrase such as *πώς σε λένε;*. Its fields hold the term, its meaning, and supporting data. The app shows notes as *words*.
- **Note type** *(planned)*: defines a note's fields and the cards generated from it. Today every note has the same fixed fields.
- **Card:** a study prompt generated from a note in one direction (`CardDirection`): forward (term → meaning) or reverse (meaning → term).
- **Deck:** a group of notes; each note belongs to exactly one deck. It is the unit of import and export, and the pool that exercises draw distractors from.
- **Topic:** a group of related notes for practice, possibly spanning decks, for example *greetings* or a confusable pair. Likely stored as tags; not built yet.
- **Collection:** all of a learner's data. In the app, a `Library` gives views access to it (its stores and media).
- **Media:** images and audio referenced by notes.

## Practice

- **Practice session:** one period of practice, stored with its status, *open* or *ended*. It groups the card review events, and later the exercise review events, recorded during it.
- **Study queue:** the cards a practice session will show, built once when it opens, one card per note.
- **Exercise type** *(planned beyond flashcards)*: a kind of interaction: flashcard, choose-one, writing. Its rules (for example, three options with distractors from the same deck) are part of the type.
- **Exercise** *(planned)*: an exercise type applied to one or more cards when shown, for example a choose-one exercise on a reverse card. It isn't stored ahead of time; its expected answer is one of its fields.
- **Exercise attempt** *(planned)*: what the learner did with one exercise: answered, revealed the answer, skipped, or retried, including any hints used.
- **Scheduled review:** a card review that contributes to future scheduling. Not every exercise attempt is a scheduled review.

## Scheduling and history

- **Card review event:** the record of one scheduled review, in the card review log.
- **Exercise review event** *(planned)*: the record of one exercise attempt, in the exercise review log.
- **Card review log** and **exercise review log** *(planned)*: the two append-only logs; see [data layering](data-layering.md#review-logs).
- **Rating:** the learner's grade for a card review, 1–4 (Again, Hard, Good, Easy).
- **Card state:** new, learning, review, or relearning (0–3).
- **Scheduling state:** a card's FSRS memory state and due date. It must stay consistent with the card's review events.
- **Baseline:** a card's starting scheduling state, where projection and recalculation begin: a new card's state, or (planned) the state imported from Anki together with the imported events it already reflects.

## Identity and lifecycle

- **Idempotency key:** a client-generated UUID on every review event, so a retried write is recorded once.
- **Tombstone** *(planned)*: a marker left by deleted content, so export and sync can propagate the deletion.

## Anki mapping

Lexcalli keeps its own names and schema; Anki names appear only at the import/export boundary.

| Lexcalli | Anki | Notes |
| --- | --- | --- |
| Note | note (`guid`) | |
| Note type | notetype | the learner maps its fields (term, meaning, optional fields) and card directions on first import; remembered per note type |
| Card | card (note + template `ord`) | forward and reverse match *Basic (and reversed card)* |
| Deck | deck | |
| Topic | tag | if topics are stored as tags (open) |
| Collection | collection (`.colpkg`) | |
| Media | media file | stored by content hash, referenced by filename |
| Card review event | `revlog` entry | |
| Rating | `ease` | same numbering |
| Card state | card `type` | same numbering |
| Scheduling state | card FSRS data and due date | |
| Baseline | card state at import | |
| Tombstone | `grave` | |
| Idempotency key | — | derived from the `revlog` id on import |
| Exercise review event | — | Lexcalli only; what happens on export is open |
| Practice session | — | not exported |
