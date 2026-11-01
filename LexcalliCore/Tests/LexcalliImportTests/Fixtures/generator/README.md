# Archive fixtures

The four `current/legacy-{new,progress}.apkg` packages were exported by official PyPI **anki 26.9.3**, with `with_media=True`, `legacy=False/True`, and `with_scheduling` / `with_deck_configs=False/True`. The synthetic Basic (and reversed card) deck has four notes, eight cards, generated PNG/WAV media, and three genuine Anki scheduler reviews in progress exports. `fixture-provenance.json` records exact members, options, semantic counts, headers, and hashes of the supplied originals. Generator dependencies are pinned in `python-requirements.lock`; they are development tools, not app dependencies.

**Rights:** the synthetic note text, generated image/audio, adversarial fixtures, and these generator scripts are dedicated to **CC0-1.0**. No downloaded user deck or third-party media is included. Anki and its dependencies retain their own upstream licenses.

Current packages contain authoritative `collection.anki21b` (zstd/SQLite schema 18), protobuf `meta`, and zstd-compressed protobuf `media`; numeric media members are individually zstd-compressed. Legacy packages contain authoritative `collection.anki21` (plain SQLite schema 11) and a JSON media map. Both include Anki's compatibility `collection.anki2`, which is not the real deck. Current snapshots retain WAL header flags: inspect only the complete unchanged extracted snapshot using read-only `immutable=1`, never a live database.

`additional.py` derives negative/compatibility regressions from the official exports: malformed/duplicate media maps, missing payloads, unsupported metadata, corrupt zstd/protobuf/media hashes, a directory-count mismatch, and a small ZIP64 footer. `anki2-only.apkg` renames the actual legacy DB to `collection.anki2`; it is a derived filename-fallback regression, **not** an independently exported ancient Anki version. `prefer-current.apkg` adds an invalid lower-priority DB to prove precedence.

Regenerate from the repository root, keeping the venv, source collection, and decoded diagnostic files outside test resources:

```sh
fixtures="$PWD/LexcalliCore/Tests/LexcalliImportTests/Fixtures"
work="$(mktemp -d /tmp/lexcalli-fixtures.XXXXXX)"
python3 -m venv "$work/.venv"
"$work/.venv/bin/python" -m pip install --index-url https://pypi.org/simple \
  -r "$fixtures/generator/python-requirements.lock"
LEXCALLI_FIXTURE_WORKDIR="$work" LEXCALLI_FIXTURE_OUTPUT="$fixtures" \
  "$work/.venv/bin/python" "$fixtures/generator/generate_fixtures.py"
swift test --package-path LexcalliCore --filter ArchiveTests
```

The generator overwrites these fixtures and their provenance file. Anki IDs/timestamps/hashes can change; semantic counts and formats must stay the same. No venv or generated source database belongs in this directory. Adversarial archives are test input only: never extract them with a convenience unzip command.
