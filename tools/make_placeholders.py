#!/usr/bin/env python3
"""Generate block placeholder stand-ins per docs/art-pipeline.md (Python 3, stdlib).

This tool produces *block placeholders only* (pipeline §5/§6): flat-colour
blocks with the magenta convention, at the exact final sizes, frame counts,
paths and filenames the artist's deliverables will overwrite 1:1. It never
authors art (§7) — sourced gap-filler (Kenney) is conformed by hand and
tracked in assets/temp_assets.md instead.

It also:
- establishes the locked folder tree under assets/ (§3), with .gitkeep in
  directories that have no files yet;
- rewrites assets/stand_ins.json mapping each generated file to a sha256
  of its bytes. AssetRegistry uses it in debug builds to list stand-ins
  still in use (§6): when real art overwrites a file, its hash no longer
  matches and it drops off the report automatically.

Usage:
    python3 tools/make_placeholders.py            # regenerate stand-ins
    python3 tools/make_placeholders.py --preview  # also write an 8x contact
                                                  # sheet to /tmp for eyeballing
"""

import hashlib
import json
import pathlib
import struct
import sys
import zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"

# Locked tree (§3). Directories with no generated files get a .gitkeep.
TREE = [
    "sprites/player",
    "sprites/pip",
    "sprites/npcs",
    "sprites/objects",
    "tilesets/coastal",
    "tilesets/forest",
    "tilesets/mountain",
    "tilesets/ruins",
    "ui/journal",
    "ui/pouch",
    "ui/dialogue",
    "portraits",
    "cutscenes",
    "map",
    "audio/sfx",
    "audio/music",
]

MAGENTA = (255, 0, 255, 255)
MAGENTA_DARK = (170, 0, 170, 255)
INK = (20, 20, 20, 255)
WHITE = (240, 240, 240, 255)

# One distinct flat colour per player layer (§5) so the stacked modular
# structure is visible and the palette-swap shader has real layers to hit.
LAYER_COLOURS = {
    "base": (138, 138, 160, 255),
    "outfit_default": (196, 122, 58, 255),
    "hair_short": (87, 160, 90, 255),
    "hair_afro": (60, 130, 64, 255),
    "accessory_default": (74, 196, 196, 255),
}

DIRECTIONS = ["down", "up", "left", "right"]

# Pip state -> frame count (§1). Shimmer range is 6-8; stand-ins use 6 and
# the registry tolerates however many frames the artist delivers.
PIP_STATES = {
    "idle": 3,
    "distressed": 3,
    "leading": 2,
    "glow": 3,
    "shimmer": 6,
}

SHIMMER_CYCLE = [
    (228, 80, 90, 255),
    (238, 190, 80, 255),
    (110, 200, 110, 255),
    (90, 200, 210, 255),
    (90, 110, 220, 255),
    (170, 90, 220, 255),
]


# --- tiny PNG canvas -------------------------------------------------------

def blank(width: int, height: int):
    return [[(0, 0, 0, 0)] * width for _ in range(height)]


def put(canvas, x: int, y: int, colour) -> None:
    if 0 <= y < len(canvas) and 0 <= x < len(canvas[0]):
        canvas[y][x] = colour


def rect(canvas, x0: int, y0: int, x1: int, y1: int, colour) -> None:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(canvas, x, y, colour)


def outline(canvas, colour) -> None:
    h = len(canvas)
    w = len(canvas[0])
    rect(canvas, 0, 0, w - 1, 0, colour)
    rect(canvas, 0, h - 1, w - 1, h - 1, colour)
    rect(canvas, 0, 0, 0, h - 1, colour)
    rect(canvas, w - 1, 0, w - 1, h - 1, colour)


def frame_pips(canvas, count: int, y: int = 2, colour=INK) -> None:
    """N small dots so frame NN is visually distinguishable in motion."""
    for i in range(count):
        put(canvas, 2 + i * 2, y, colour)


def _chunk(tag: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def encode_png(canvas, scale: int = 1) -> bytes:
    height = len(canvas) * scale
    width = len(canvas[0]) * scale
    raw = bytearray()
    for row in canvas:
        scanline = bytearray(b"\x00")
        for pixel in row:
            scanline.extend(bytes(pixel) * scale)
        raw.extend(scanline * scale)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + _chunk(b"IHDR", ihdr)
        + _chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + _chunk(b"IEND", b"")
    )


# --- player layer stand-ins (16x32, modular, §5) ---------------------------

def player_frame(variant: str, anim: str, index: int):
    """One 16x32 frame for one layer. `anim` is "idle" or "walk_<dir>"."""
    canvas = blank(16, 32)
    kind = variant.split("_")[0]
    colour = LAYER_COLOURS[variant]
    breath = 1 if (anim == "idle" and index == 1) else 0

    if kind == "base":
        rect(canvas, 0, 0, 15, 31, colour)
        outline(canvas, MAGENTA)
        frame_pips(canvas, index + 1)
    elif kind == "outfit":
        rect(canvas, 0, 14, 15, 27, colour)
        rect(canvas, 0, 14, 1, 15, MAGENTA)
        if anim.startswith("walk_"):
            direction = anim.split("_")[1]
            gait = [0, 1, 0, -1][index]
            if direction == "down":
                rect(canvas, 6 + gait, 26, 8 + gait, 27, INK)
            elif direction == "up":
                rect(canvas, 6 + gait, 14, 8 + gait, 15, INK)
            elif direction == "left":
                rect(canvas, 0, 19 + gait, 1, 21 + gait, INK)
            else:
                rect(canvas, 14, 19 + gait, 15, 21 + gait, INK)
    elif kind == "hair":
        if variant == "hair_short":
            rect(canvas, 3, 0 + breath, 12, 7 + breath, colour)
            rect(canvas, 3, 0 + breath, 4, 0 + breath, MAGENTA)
        else:  # hair_afro — visibly different silhouette
            rect(canvas, 2, 0 + breath, 13, 9 + breath, colour)
            rect(canvas, 2, 0 + breath, 3, 0 + breath, MAGENTA)
    elif kind == "accessory":
        rect(canvas, 2, 18, 6, 22, colour)
        put(canvas, 2, 18, MAGENTA)
    return canvas


def player_files():
    files = {}
    for variant in LAYER_COLOURS:
        anims = [("idle", 2)] + [("walk_%s" % d, 4) for d in DIRECTIONS]
        for anim, count in anims:
            for i in range(count):
                name = "player_%s_%s_%02d.png" % (variant, anim, i + 1)
                files["sprites/player/" + name] = player_frame(variant, anim, i)
    return files


# --- Pip stand-ins (8x10, per movement/glow state, §5) ----------------------
# Colour states are engine tints/shaders over these neutral-state frames;
# only the shimmer is itself a colour cycle, so only it cycles here.

def pip_frame(state: str, index: int):
    canvas = blank(8, 10)
    fill = SHIMMER_CYCLE[index] if state == "shimmer" else MAGENTA
    rect(canvas, 0, 0, 7, 9, fill)
    outline(canvas, MAGENTA_DARK if state != "shimmer" else MAGENTA)

    if state == "idle":  # gentle bob — marker drifts vertically
        bob = [4, 3, 5][index]
        rect(canvas, 3, bob, 4, bob + 1, WHITE)
    elif state == "distressed":  # jagged scatter
        for x, y in [[(2, 3), (5, 6)], [(5, 2), (2, 7)], [(3, 5), (6, 3)]][index]:
            put(canvas, x, y, INK)
    elif state == "leading":  # pulls ahead — marker pushes to the edge
        x = [4, 6][index]
        rect(canvas, x, 4, min(x + 1, 7), 5, WHITE)
    elif state == "glow":  # pulse — bright core grows and settles
        core = (255, 140, 255, 255)
        if index == 1:
            rect(canvas, 2, 3, 5, 6, core)
        else:
            rect(canvas, 3, 4, 4, 5, core)

    for i in range(index + 1):
        put(canvas, 1 + i, 8, INK)
    return canvas


def pip_files():
    files = {}
    for state, count in PIP_STATES.items():
        for i in range(count):
            name = "pip_%s_%02d.png" % (state, i + 1)
            files["sprites/pip/" + name] = pip_frame(state, i)
    return files


# --- output ----------------------------------------------------------------

def ensure_tree() -> None:
    for rel in TREE:
        directory = ASSETS / rel
        directory.mkdir(parents=True, exist_ok=True)
        if not any(p.name != ".gitkeep" for p in directory.iterdir()):
            (directory / ".gitkeep").touch()


def write_preview(files) -> None:
    """8x contact sheet: stacked player frame + pip states. /tmp only."""
    stacked = blank(16, 32)
    for layer in ["base", "outfit_default", "hair_short", "accessory_default"]:
        frame = files["sprites/player/player_%s_walk_down_01.png" % layer]
        for y, row in enumerate(frame):
            for x, pixel in enumerate(row):
                if pixel[3] != 0:
                    stacked[y][x] = pixel
    sheet = blank(16 + 2 + len(PIP_STATES) * 10, 32)
    for y, row in enumerate(stacked):
        for x, pixel in enumerate(row):
            sheet[y][x] = pixel
    for column, state in enumerate(PIP_STATES):
        frame = files["sprites/pip/pip_%s_01.png" % state]
        for y, row in enumerate(frame):
            for x, pixel in enumerate(row):
                sheet[y + 11][18 + column * 10 + x] = pixel
    path = pathlib.Path("/tmp/emberthread_standins.png")
    path.write_bytes(encode_png(sheet, scale=8))
    print("wrote %s" % path)


def main() -> None:
    ensure_tree()
    files = {}
    files.update(player_files())
    files.update(pip_files())

    manifest = {}
    for rel, canvas in sorted(files.items()):
        data = encode_png(canvas)
        path = ASSETS / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        gitkeep = path.parent / ".gitkeep"
        if gitkeep.exists():
            gitkeep.unlink()
        manifest["res://assets/" + rel] = hashlib.sha256(data).hexdigest()

    manifest_path = ASSETS / "stand_ins.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print("wrote %d stand-in files + %s" % (len(files), manifest_path))

    if "--preview" in sys.argv:
        write_preview(files)


if __name__ == "__main__":
    main()
