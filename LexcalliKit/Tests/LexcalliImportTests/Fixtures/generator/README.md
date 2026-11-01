# Archive fixtures

The four `current/legacy-{new,progress}.apkg` fixtures use official **anki 26.9.3** exports: four notes, eight cards, generated PNG/WAV, and three scheduler reviews in progress exports. `fixture-provenance.json` records options, counts, headers, and hashes. Python dependencies are fixture tools only.

**CC0-1.0:** synthetic content, media, adversarial fixtures, and generator code. No downloaded decks or third-party media. Dependencies retain their upstream licenses.

- Current: `collection.anki21b` (zstd, schema 18); protobuf manifest; individually zstd-compressed media.
- Legacy: `collection.anki21` (plain SQLite, schema 11); JSON manifest; raw media.
- Both contain a compatibility `collection.anki2`, not the real deck.
- Use read-only `immutable=1` only for complete, unchanged extracted snapshots, never live databases.

`additional.py` creates negative and compatibility cases. `anki2-only.apkg` renames the real legacy DB; it is not an ancient Anki export. `prefer-current.apkg` adds an invalid lower-priority DB.

Regenerate from the repository root; keep the venv and diagnostic databases outside test resources:

```sh
fixtures="$PWD/LexcalliKit/Tests/LexcalliImportTests/Fixtures"
work="$(mktemp -d /tmp/lexcalli-fixtures.XXXXXX)"
python3 -m venv "$work/.venv"
"$work/.venv/bin/python" -m pip install --index-url https://pypi.org/simple \
  -r "$fixtures/generator/python-requirements.lock"
LEXCALLI_FIXTURE_WORKDIR="$work" LEXCALLI_FIXTURE_OUTPUT="$fixtures" \
  "$work/.venv/bin/python" "$fixtures/generator/generate_fixtures.py"
swift test --package-path LexcalliKit --filter LexcalliImportTests
```

Regeneration overwrites fixtures and provenance. IDs/timestamps/hashes may change; semantic counts and formats must not. Never convenience-unzip the adversarial archives.
