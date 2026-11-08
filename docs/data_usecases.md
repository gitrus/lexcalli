# Data use cases

What the learner sees of their library at first launch, after an app update, and during import and export. Terms are defined in the [glossary](glossary.md); how the data is stored and recovered is in [data management](data_management.md).

## First launch

- A new library starts with the bundled starter deck. It is added once per library, not again on later launches.

## Opening after an app update

- If the library can't be upgraded, the app opens nothing and says the decks were left unchanged, asking the learner to update the app or contact support. It never shows an empty library in their place ([migration rules](data_management.md#schema-evolution-and-recovery)).
- A library saved by a newer version of Lexcalli isn't opened; the app asks the learner to update.

## Importing an Anki deck (planned)

- The learner chooses whether to import scheduling history, as Anki 23.10+ allows. Without it, cards start as new.
- On a note type's first import, the learner maps its fields and card directions; the mapping is remembered per note type ([Anki mapping](glossary.md#anki-mapping)).
- A note that already exists under a different note type is skipped as a conflict, unless the learner chooses to merge note types.
- Import shows progress and can be cancelled.
- When it finishes, an import report lists notes as new, updated, duplicate, or conflicting, like Anki's.

The recovery protocol and matching rules behind these steps are in [import](data_management.md#import).

## Exporting (planned)

- The learner can export to an `.apkg`- or `.colpkg`-compatible file. Export is their own recovery path and portability guarantee, and it includes every saved card review ([backups and protection](data_management.md#backups-and-protection)).
