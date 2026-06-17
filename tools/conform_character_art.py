#!/usr/bin/env python3
"""Conform the project lead's stand-in character/Pip art into the asset tree.

The art under character/ and pip/ is AI-generated stand-in art on a large
padded canvas (72x72 / 60x60), organised by 8-way rotation plus 4-direction
walk cycles. This tool trims it to content and writes it into the locked
asset paths as *temporary gap-filler* (tracked in temp_assets.md), so the
game shows it while building. It is whole-sprite (not modular), so it feeds
the player's placeholder path, not the body/clothes/face/hair layers.

Run after the art changes:
    python3 tools/conform_character_art.py

Source folders stay .gdignore'd (raw source, like the Kenney packs).
"""

import pathlib

from conform_kenney import read_png, record_temp_asset
from make_placeholders import encode_png

ROOT = pathlib.Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"

CHAR_SRC = ROOT / "character/A_cozy_pixel_art_RPG"
PIP_SRC = ROOT / "pip/A_tiny_humanoid_fae_creature_for_a_cozy_pixel_art"
CHAR_PACK = "Stand-in art: A cozy pixel art RPG (mender)"
PIP_PACK = "Stand-in art: tiny humanoid fae (Pip)"

# Art direction -> in-game animation direction.
WALK_DIRS = {"down": "south", "up": "north", "left": "west", "right": "east"}
WALK_FRAMES = 6


def content_bounds(pixels):
    h = len(pixels)
    w = len(pixels[0])
    min_x, min_y, max_x, max_y = w, h, -1, -1
    for y in range(h):
        for x in range(w):
            if pixels[y][x][3] > 16:
                min_x = min(min_x, x)
                max_x = max(max_x, x)
                min_y = min(min_y, y)
                max_y = max(max_y, y)
    return min_x, min_y, max_x, max_y


def union_bounds(frames):
    boxes = [content_bounds(f) for f in frames]
    return (min(b[0] for b in boxes), min(b[1] for b in boxes),
            max(b[2] for b in boxes), max(b[3] for b in boxes))


def crop(pixels, box, pad=1):
    min_x, min_y, max_x, max_y = box
    min_x = max(min_x - pad, 0)
    min_y = max(min_y - pad, 0)
    max_x = min(max_x + pad, len(pixels[0]) - 1)
    max_y = min(max_y + pad, len(pixels) - 1)
    return [row[min_x:max_x + 1] for row in pixels[min_y:max_y + 1]]


def write(rel, pixels, pack, note):
    path = ASSETS / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    gitkeep = path.parent / ".gitkeep"
    if gitkeep.exists():
        gitkeep.unlink()
    path.write_bytes(encode_png(pixels))
    record_temp_asset("res://assets/" + rel, pack, note)
    print("wrote", rel)


def conform_character():
    # One shared crop box across every frame so the walk cycle doesn't jitter
    # and the four directions line up.
    frames = {}
    for anim_dir, art_dir in WALK_DIRS.items():
        frames[anim_dir] = [
            read_png(CHAR_SRC / "animations/Walking" / art_dir / ("frame_%03d.png" % i))
            for i in range(WALK_FRAMES)
        ]
    idle = read_png(CHAR_SRC / "rotations/south.png")
    flat = [f for fs in frames.values() for f in fs] + [idle]
    box = union_bounds(flat)

    write("sprites/player/player_placeholder_idle_00.png", crop(idle, box),
          CHAR_PACK, "front idle (trimmed)")
    for anim_dir, dir_frames in frames.items():
        for i, frame in enumerate(dir_frames):
            write("sprites/player/player_placeholder_walk_%s_%02d.png" % (anim_dir, i),
                  crop(frame, box), CHAR_PACK, "walk %s" % anim_dir)


def conform_pip():
    # Pip floats and faces the player; the front still is enough for a
    # placeholder. Emotion reads through the glow halo, not the body.
    south = read_png(PIP_SRC / "rotations/south.png")
    write("sprites/pip/pip_placeholder.png", crop(south, content_bounds(south)),
          PIP_PACK, "front still; glow halo carries emotion")


def main():
    conform_character()
    conform_pip()
    print("done — run the game; player + Pip use these until real art lands.")


if __name__ == "__main__":
    main()
