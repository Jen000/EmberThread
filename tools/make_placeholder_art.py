#!/usr/bin/env python3
"""Generate Ember & Thread's placeholder pixel art (Python 3, stdlib only).

Each sprite is an ASCII pixel map — one character per pixel, mapped to an
RGBA colour in PALETTE. Edit the maps, rerun, and the PNGs under
assets/placeholder/ are rewritten:

    python3 tools/make_placeholder_art.py

Pass --preview to also write 8x upscaled copies to /tmp for eyeballing.
All of this art is temporary and will be replaced region by region.
"""

import pathlib
import struct
import sys
import zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent

PALETTE = {
    ".": None,                  # transparent
    "O": (46, 31, 26, 255),     # soft dark outline
    "C": (196, 106, 58, 255),   # cloak — warm ember terracotta
    "c": (148, 73, 42, 255),    # cloak shadow
    "S": (240, 200, 160, 255),  # skin
    "s": (209, 154, 111, 255),  # skin shadow
    "E": (46, 31, 26, 255),     # eyes
    "B": (122, 90, 58, 255),    # satchel leather
    "b": (90, 64, 40, 255),     # satchel flap / boots
}

# The mender, 16x24, facing the camera. Hooded cloak, satchel, little boots.
# In-game convention: the scene origin sits at the feet.
PLAYER = [
    "................",
    ".....OOOOOO.....",
    "....OCCCCCCO....",
    "...OCCCCCCCCO...",
    "...OCcCCCCcCO...",
    "...OCSSSSSSCO...",
    "...OCSESSESCO...",
    "...OCSSSSSSCO...",
    "...OCsSSSSsCO...",
    "....OCssssCO....",
    "...OCCCCCCCCO...",
    "..OCCCCCCCCCCO..",
    "..OCCCCCCCCCCO..",
    ".OCCCCCCCCCCCCO.",
    ".OCCCBBBBBBCCCO.",
    ".OCCCBbbbbBCCCO.",
    ".OcCCCCCCCCCCcO.",
    ".OcCCCCCCCCCCcO.",
    "..OcCCCCCCCCcO..",
    "..OccCCCCCCccO..",
    "...OccccccccO...",
    "....OOOOOOOO....",
    "....Obb..bbO....",
    ".....OO..OO.....",
]

SPRITES = {
    "player.png": PLAYER,
}


def _chunk(tag: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def encode_png(rows: list[str], scale: int = 1) -> bytes:
    width = len(rows[0]) * scale
    height = len(rows) * scale
    raw = bytearray()
    for row in rows:
        assert len(row) == len(rows[0]), f"ragged row: {row!r}"
        scanline = bytearray(b"\x00")  # filter type 0 (None)
        for char in row:
            pixel = PALETTE[char] or (0, 0, 0, 0)
            scanline.extend(bytes(pixel) * scale)
        raw.extend(scanline * scale)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + _chunk(b"IHDR", ihdr)
        + _chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + _chunk(b"IEND", b"")
    )


def main() -> None:
    out_dir = ROOT / "assets" / "placeholder"
    out_dir.mkdir(parents=True, exist_ok=True)
    preview = "--preview" in sys.argv
    for name, rows in SPRITES.items():
        path = out_dir / name
        path.write_bytes(encode_png(rows))
        print(f"wrote {path}")
        if preview:
            preview_path = pathlib.Path("/tmp") / f"emberthread_preview_{name}"
            preview_path.write_bytes(encode_png(rows, scale=8))
            print(f"wrote {preview_path}")


if __name__ == "__main__":
    main()
