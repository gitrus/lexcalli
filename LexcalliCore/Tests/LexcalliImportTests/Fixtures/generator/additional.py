"""CC0 regression packages derived from the official synthetic Anki exports."""

import struct
import zipfile

# Installed in the pinned fixture venv, not the application environment.
import zstandard  # pyright: ignore[reportMissingImports]


def generate(out):
    def modified(source, destination, replacements=None, remove=()):
        with zipfile.ZipFile(out / source) as archive:
            members = {
                name: archive.read(name)
                for name in archive.namelist()
                if name not in remove
            }
        members.update(replacements or {})
        with zipfile.ZipFile(
            out / destination, "w", compression=zipfile.ZIP_DEFLATED
        ) as archive:
            for name, data in members.items():
                archive.writestr(name, data)

    for name, manifest in [
        ("duplicate-json-key.apkg", b'{"0":"pixel.png","0":"tone.wav"}'),
        ("duplicate-media-name.apkg", b'{"0":"same.png","1":"same.png"}'),
        ("unsafe-media-name.apkg", b'{"0":"../escape"}'),
        ("missing-media.apkg", b'{"999":"missing.png"}'),
        ("malformed-json.apkg", b'{"0":{"nested":"object"}}'),
    ]:
        modified("legacy-new.apkg", name, {"media": manifest})
    modified("current-new.apkg", "unknown-version.apkg", {"meta": b"\x08\x04"})
    modified(
        "current-new.apkg",
        "bad-current-db.apkg",
        {"collection.anki21b": b"\x28\xb5\x2f\xfdinvalid"},
    )
    modified(
        "current-new.apkg",
        "bad-protobuf.apkg",
        {"media": zstandard.ZstdCompressor().compress(b"\x0a\xff")},
    )
    modified(
        "current-new.apkg",
        "bad-media-sha.apkg",
        {"0": zstandard.ZstdCompressor().compress(b"x" * 69)},
    )
    modified(
        "current-new.apkg", "prefer-current.apkg", {"collection.anki21": b"not SQLite"}
    )
    with zipfile.ZipFile(out / "legacy-new.apkg") as archive:
        database = archive.read("collection.anki21")
    modified(
        "legacy-new.apkg",
        "anki2-only.apkg",
        {"collection.anki2": database},
        remove=["collection.anki21"],
    )
    raw = bytearray((out / "legacy-new.apkg").read_bytes())
    footer = raw.rindex(b"PK\x05\x06")
    count = struct.unpack_from("<H", raw, footer + 10)[0]
    struct.pack_into("<HH", raw, footer + 8, count + 1, count + 1)
    (out / "wrong-directory-count.zip").write_bytes(raw)
    # Small ZIP64 footer around unchanged official exporter payloads.
    raw = bytearray((out / "legacy-new.apkg").read_bytes())
    footer = raw.rindex(b"PK\x05\x06")
    count = struct.unpack_from("<H", raw, footer + 10)[0]
    directory_size, directory_offset = struct.unpack_from("<II", raw, footer + 12)
    classic = bytearray(raw[footer:])
    struct.pack_into("<HHII", classic, 8, 0xFFFF, 0xFFFF, 0xFFFFFFFF, 0xFFFFFFFF)
    record = struct.pack(
        "<IQHHIIQQQQ",
        0x06064B50,
        44,
        45,
        45,
        0,
        0,
        count,
        count,
        directory_size,
        directory_offset,
    )
    locator = struct.pack("<IIQI", 0x07064B50, 0, footer, 1)
    (out / "small-zip64.apkg").write_bytes(raw[:footer] + record + locator + classic)
