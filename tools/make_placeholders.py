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

# Player layers, draw order back->front, one distinct flat colour each so
# the stacked structure is visible and the palette-swap shader has real
# zones to hit. Each layer is ONE spritesheet (player_<layer>.png): a grid
# of 16x32 cells the engine slices, and the layout the artist draws to.
PLAYER_LAYERS = ["body", "clothes", "face", "hair"]
PLAYER_LAYER_COLOURS = {
    "body": (214, 168, 120, 255),    # skin
    "clothes": (196, 122, 58, 255),  # outfit
    "face": (40, 32, 32, 255),       # eyes / features
    "hair": (96, 150, 96, 255),      # hair
}

# anim -> frame count, one row each. Matches Player.SHEET_LAYOUT row order.
PLAYER_SHEET = [
    ("idle", 2),
    ("walk_down", 4),
    ("walk_up", 4),
    ("walk_left", 4),
    ("walk_right", 4),
]
PLAYER_COLS = 4
FRAME_W, FRAME_H = 16, 32

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


# --- player layer stand-ins (16x32 cells, one sheet per layer, §5) ----------
# Shared body regions so the four layers register when stacked: head, torso,
# legs, feet. The artist draws every layer on this same 16x32 footprint.

def player_cell(layer: str, anim: str, index: int):
    """One 16x32 cell of a layer sheet."""
    cell = blank(FRAME_W, FRAME_H)
    colour = PLAYER_LAYER_COLOURS[layer]
    facing = anim.split("_")[1] if anim.startswith("walk_") else "down"

    if layer == "body":
        rect(cell, 4, 2, 11, 11, colour)     # head
        rect(cell, 3, 12, 12, 23, colour)    # torso
        rect(cell, 4, 24, 11, 29, colour)    # legs
        rect(cell, 4, 30, 11, 31, INK)       # feet
        outline(cell, MAGENTA)               # placeholder marker (whole cell)
        frame_pips(cell, index + 1, y=1)     # frame counter
    elif layer == "clothes":
        rect(cell, 3, 13, 12, 24, colour)    # tunic over the torso
        rect(cell, 4, 13, 5, 23, MAGENTA)    # satchel strap + marker
    elif layer == "face":
        if facing != "up":                   # facing away hides the face
            dx = {"down": 0, "left": -1, "right": 1}[facing]
            put(cell, 6 + dx, 7, colour)     # eyes
            put(cell, 9 + dx, 7, colour)
            put(cell, 7 + dx, 5, MAGENTA)    # marker
    elif layer == "hair":
        rect(cell, 3, 1, 12, 6, colour)      # crown / fringe
        rect(cell, 3, 1, 12, 1, MAGENTA)     # marker
    return cell


def player_sheet(layer: str):
    """A full layer sheet: PLAYER_COLS x len(PLAYER_SHEET) grid of cells."""
    sheet = blank(PLAYER_COLS * FRAME_W, len(PLAYER_SHEET) * FRAME_H)
    for row, (anim, count) in enumerate(PLAYER_SHEET):
        for index in range(count):
            cell = player_cell(layer, anim, index)
            for y, line in enumerate(cell):
                for x, pixel in enumerate(line):
                    if pixel[3] != 0:
                        sheet[row * FRAME_H + y][index * FRAME_W + x] = pixel
    return sheet


def player_files():
    return {
        "sprites/player/player_%s.png" % layer: player_sheet(layer)
        for layer in PLAYER_LAYERS
    }


# --- Pip stand-ins (8x10, per movement/glow state, §5) ----------------------
# Colour states are engine tints/shaders over these neutral-state frames.
# Pip's whole identity is colour, and a magenta FILL would multiply the
# emotion tint away (magenta has no green channel). So the fill is a light
# neutral that takes the tint cleanly, wrapped in a thick magenta BORDER —
# still unmistakably a placeholder (§6 allows magenta fill *or* border),
# still in the audit, but the colour language is actually testable.
NEUTRAL = (205, 205, 210, 255)

def pip_frame(state: str, index: int):
    canvas = blank(8, 10)
    if state == "shimmer":
        rect(canvas, 0, 0, 7, 9, SHIMMER_CYCLE[index])
        outline(canvas, MAGENTA)
    else:
        rect(canvas, 0, 0, 7, 9, MAGENTA)       # border
        rect(canvas, 1, 1, 6, 8, NEUTRAL)       # tintable body

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
    """8x contact sheet: stacked player idle frame + pip states. /tmp only."""
    stacked = blank(16, 32)
    for layer in PLAYER_LAYERS:
        sheet = files["sprites/player/player_%s.png" % layer]
        for y in range(FRAME_H):           # idle frame 0 is the top-left cell
            for x in range(FRAME_W):
                pixel = sheet[y][x]
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
