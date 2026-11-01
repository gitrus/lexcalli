"""CC0 fixtures via anki==26.9.3; see README for isolated regeneration."""

import hashlib
import importlib.metadata
import json
import math
import os
import shutil
import sqlite3
import stat
import struct
import wave
import zipfile
import zlib
from pathlib import Path

# Fixture-only dependencies live in the pinned venv.
import zstandard  # pyright: ignore[reportMissingImports]
from additional import generate
from anki.collection import Collection, DeckIdLimit  # pyright: ignore[reportMissingImports]
from anki.import_export_pb2 import ExportAnkiPackageOptions  # pyright: ignore[reportMissingImports]

GENERATOR = Path(__file__).resolve().parent
ROOT = Path(os.environ["LEXCALLI_FIXTURE_WORKDIR"]).resolve()
OUT = Path(os.environ["LEXCALLI_FIXTURE_OUTPUT"]).resolve()
OUT.mkdir(exist_ok=True)
source = ROOT / "generated-collection"
if source.exists():
    shutil.rmtree(source)
source.mkdir()
col = Collection(str(source / "collection.anki2"))
col.set_config("fsrs", True)
did = col.decks.id("Lexcalli Synthetic CC0")
model = col.models.by_name("Basic (and reversed card)")
assert model is not None and len(model["tmpls"]) == 2


def chunk(kind, data):
    return (
        struct.pack(">I", len(data))
        + kind
        + data
        + struct.pack(">I", zlib.crc32(kind + data))
    )


png = (
    b"\x89PNG\r\n\x1a\n"
    + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))
    + chunk(b"IDAT", zlib.compress(b"\0\0\xff\0"))
    + chunk(b"IEND", b"")
)
(source / "pixel.png").write_bytes(png)
with wave.open(str(source / "tone.wav"), "wb") as w:
    w.setparams((1, 2, 8000, 0, "NONE", "not compressed"))
    w.writeframes(
        b"".join(
            struct.pack("<h", int(2000 * math.sin(2 * math.pi * 440 * i / 8000)))
            for i in range(800)
        )
    )
col.media.add_file(str(source / "pixel.png"))
col.media.add_file(str(source / "tone.wav"))
for i, (front, back) in enumerate(
    [("άλφα", "alpha"), ("βήτα", "beta"), ("γεια σου", "hello"), ("νερό", "water")]
):
    note = col.new_note(model)
    note["Front"] = front + (
        '<br><img src="pixel.png"> [sound:tone.wav]' if i == 0 else ""
    )
    note["Back"] = back
    note.tags = ["lexcalli_spike_cc0"]
    col.add_note(note, did)
col.decks.select(did)
# Scheduler APIs produce genuine revlog and FSRS state.
ids = col.find_cards(f"did:{did}")
for cid in ids[:3]:
    card = col.get_card(cid)
    card.start_timer()
    col.sched.answerCard(card, 4)
print(
    "source",
    col.db.scalar("select count(*) from notes"),
    col.db.scalar("select count(*) from cards"),
    col.db.scalar("select count(*) from revlog"),
)
print("memory", col.db.all("select id, data from cards where data != ''"))
report = {
    "anki": importlib.metadata.version("anki"),
    "zstandard": importlib.metadata.version("zstandard"),
    "rights": (
        "Synthetic note text, generated PNG/WAV and fixture-generator code "
        "dedicated to CC0-1.0; Anki itself remains under its upstream license."
    ),
    "fixtures": {},
}
for legacy in [False, True]:
    for progress in [False, True]:
        name = (
            ("legacy" if legacy else "current")
            + ("-progress" if progress else "-new")
            + ".apkg"
        )
        options = ExportAnkiPackageOptions(
            with_scheduling=progress,
            with_deck_configs=progress,
            with_media=True,
            legacy=legacy,
        )
        col.export_anki_package(
            out_path=str(OUT / name), options=options, limit=DeckIdLimit(deck_id=did)
        )
        with zipfile.ZipFile(OUT / name) as z:
            names = z.namelist()
            database = next(
                n
                for n in ["collection.anki21b", "collection.anki21", "collection.anki2"]
                if n in names
            )
            raw = z.read(database)
            decoded = (
                zstandard.ZstdDecompressor().stream_reader(raw).read()
                if raw.startswith(b"\x28\xb5\x2f\xfd")
                else raw
            )
            db = ROOT / (name + ".sqlite")
            db.write_bytes(decoded)
            conn = sqlite3.connect(db)
            counts = {
                "notes": conn.execute("select count(*) from notes").fetchone()[0],
                "cards": conn.execute("select count(*) from cards").fetchone()[0],
                "revlog": conn.execute("select count(*) from revlog").fetchone()[0],
            }
            counts["fsrs_cards"] = conn.execute(
                "select count(*) from cards "
                "where data like '%\"s\"%' and data like '%\"d\"%'"
            ).fetchone()[0]
            counts["schema_version"] = conn.execute("select ver from col").fetchone()[0]
            conn.close()
            assert counts["notes"] == 4 and counts["cards"] == 8
            assert counts["revlog"] == (3 if progress else 0), counts
            if progress:
                assert counts["fsrs_cards"] >= 3, counts
            if not legacy:
                assert (
                    database == "collection.anki21b" and raw[:4] == b"\x28\xb5\x2f\xfd"
                )
            manifest = z.read("media")
            if not legacy:
                manifest = zstandard.ZstdDecompressor().stream_reader(manifest).read()
            else:
                assert set(json.loads(manifest).values()) == {"pixel.png", "tone.wav"}
            (ROOT / (name + ".media-decoded")).write_bytes(manifest)
            report["fixtures"][name] = {
                "export_options": str(options),
                "entries": names,
                "database_entry": database,
                "raw_db_magic": raw[:16].hex(),
                "decoded_db_magic": decoded[:16].hex(),
                "media_decoded_hex": manifest.hex(),
                **counts,
                "sha256": hashlib.sha256((OUT / name).read_bytes()).hexdigest(),
            }
col.close()


def make(name, entries):
    with zipfile.ZipFile(OUT / name, "w", compression=zipfile.ZIP_DEFLATED) as z:
        for entry, data in entries:
            z.writestr(entry, data)


for name, path in [
    ("traversal.zip", "../x"),
    ("absolute.zip", "/abs"),
    ("backslash.zip", "a\\x"),
    ("dot.zip", ".."),
]:
    make(name, [(path, b"bad")])
link = zipfile.ZipInfo("link")
link.create_system = 3
link.external_attr = (stat.S_IFLNK | 0o777) << 16
make("symlink.zip", [(link, b"/tmp/escape")])
make("duplicate.zip", [("same", b"first"), ("same", b"second")])
make("bomb-actual.zip", [("bomb", b"\0" * (8 * 1024 * 1024))])
# Forged sizes must fail runtime accounting, not just header checks.
raw = bytearray((OUT / "bomb-actual.zip").read_bytes())
struct.pack_into("<I", raw, 22, 1)
central = raw.index(b"PK\x01\x02")
struct.pack_into("<I", raw, central + 24, 1)
(OUT / "bomb-forged-small.zip").write_bytes(raw)
make("bomb-declared.zip", [("bomb", b"x")])
raw = bytearray((OUT / "bomb-declared.zip").read_bytes())
struct.pack_into("<I", raw, 22, 0x7FFFFFFF)
central = raw.index(b"PK\x01\x02")
struct.pack_into("<I", raw, central + 24, 0x7FFFFFFF)
(OUT / "bomb-declared.zip").write_bytes(raw)
(OUT / "truncated.zip").write_bytes((OUT / "current-progress.apkg").read_bytes()[:100])
(OUT / "corrupt.zst").write_bytes(b"\x28\xb5\x2f\xfdgarbage")
(OUT / "bomb.zst").write_bytes(
    zstandard.ZstdCompressor().compress(b"\0" * (8 * 1024 * 1024))
)
(OUT / "valid.zst").write_bytes(zstandard.ZstdCompressor().compress(b"hello zstd"))
(OUT / "truncated.zst").write_bytes((OUT / "valid.zst").read_bytes()[:-2])
# Window limits must fail independently of output limits.
params = zstandard.ZstdCompressionParameters.from_level(1, window_log=24)
(OUT / "window-too-large.zst").write_bytes(
    zstandard.ZstdCompressor(compression_params=params).compress(
        b"x" * (16 * 1024 * 1024)
    )
)
(GENERATOR / "fixture-provenance.json").write_text(
    json.dumps(report, indent=2, ensure_ascii=False)
)
print(json.dumps(report, indent=2, ensure_ascii=False))
generate(OUT)
print("FIXTURE_GENERATION_FINISHED")
