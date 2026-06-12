#!/usr/bin/env python3
"""Conform Kenney gap-filler assets per docs/art-pipeline.md §7-§8.

Slices 16x16 cells from the Kenney roguelike sheets (16px tiles, 1px
margins) and writes them as conformed, finally-named assets — then records
each one in assets/temp_assets.md so AssetRegistry flags it as temporary
gap-filler at startup. Integration only: this tool never authors art.

Usage:
    python3 tools/conform_kenney.py SHEET COL ROW OUT [options]

    SHEET    base | chars  (or a path to any 16px/1px-margin sheet)
    COL ROW  cell coordinates, zero-based from the top-left
    OUT      destination, either relative to assets/ (recorded in the
             temp manifest) or an absolute path (test slice, not recorded)

Options:
    --cells WxH   stitch a WxH block of cells, margins dropped (e.g. 2x2
                  for a 32x32 object)
    --scale N     integer upscale after stitching (whole-number only, §7)
    --note TEXT   note column for the temp_assets.md row
    --preview     also write an 8x copy to /tmp for eyeballing

Examples:
    python3 tools/conform_kenney.py base 5 0 tilesets/coastal/tile_coastal_grass_01.png
    python3 tools/conform_kenney.py base 30 12 sprites/objects/object_crate_whole.png --note "harbour crate"
"""

import argparse
import pathlib
import struct
import sys
import zlib

from make_placeholders import encode_png

ROOT = pathlib.Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"
TEMP_MANIFEST = ASSETS / "temp_assets.md"

CELL = 16
MARGIN = 1

SHEETS = {
    "base": (
        ROOT / "Roguelike Base Pack/Spritesheet/roguelikeSheet_transparent.png",
        "Kenney Roguelike Base Pack",
    ),
    "chars": (
        ROOT / "Roguelike Characters Pack/Spritesheet/roguelikeChar_transparent.png",
        "Kenney Roguelike Characters Pack",
    ),
}


def read_png(path: pathlib.Path):
    """Minimal PNG reader: 8-bit depth, colour types 0/2/3/4/6, no interlace."""
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"not a PNG: {path}")
    pos = 8
    chunks = {}
    idat = b""
    while pos < len(data):
        length = int.from_bytes(data[pos:pos + 4], "big")
        tag = data[pos + 4:pos + 8]
        payload = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if tag == b"IDAT":
            idat += payload
        else:
            chunks[tag] = payload
    width, height, depth, ctype, _, _, interlace = struct.unpack(
        ">IIBBBBB", chunks[b"IHDR"])
    if depth != 8 or interlace != 0:
        raise SystemExit(f"unsupported PNG flavour (depth {depth}, interlace {interlace})")
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    stride = width * channels
    raw = zlib.decompress(idat)

    rows = []
    previous = bytearray(stride)
    offset = 0
    for _ in range(height):
        ftype = raw[offset]
        offset += 1
        line = bytearray(raw[offset:offset + stride])
        offset += stride
        if ftype == 1:    # Sub
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 0xFF
        elif ftype == 2:  # Up
            for i in range(stride):
                line[i] = (line[i] + previous[i]) & 0xFF
        elif ftype == 3:  # Average
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((left + previous[i]) >> 1)) & 0xFF
        elif ftype == 4:  # Paeth
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                b = previous[i]
                c = previous[i - channels] if i >= channels else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 0xFF
        previous = line
        rows.append(bytes(line))

    palette = chunks.get(b"PLTE", b"")
    trans = chunks.get(b"tRNS", b"")
    pixels = []
    for y in range(height):
        line = rows[y]
        row = []
        for x in range(width):
            if ctype == 3:
                index = line[x]
                r, g, b = palette[index * 3:index * 3 + 3]
                a = trans[index] if index < len(trans) else 255
            elif ctype == 6:
                r, g, b, a = line[x * 4:x * 4 + 4]
            elif ctype == 2:
                r, g, b = line[x * 3:x * 3 + 3]
                a = 255
            elif ctype == 4:
                r = g = b = line[x * 2]
                a = line[x * 2 + 1]
            else:
                r = g = b = line[x]
                a = 255
            row.append((r, g, b, a))
        pixels.append(row)
    return pixels


def slice_cells(sheet_pixels, col: int, row: int, cells_w: int, cells_h: int):
    """Extract a block of cells, dropping the 1px margins between them."""
    out = [[(0, 0, 0, 0)] * (cells_w * CELL) for _ in range(cells_h * CELL)]
    for cy in range(cells_h):
        for cx in range(cells_w):
            sx = (col + cx) * (CELL + MARGIN)
            sy = (row + cy) * (CELL + MARGIN)
            if sy + CELL > len(sheet_pixels) or sx + CELL > len(sheet_pixels[0]):
                raise SystemExit(f"cell ({col + cx},{row + cy}) is outside the sheet")
            for y in range(CELL):
                for x in range(CELL):
                    out[cy * CELL + y][cx * CELL + x] = sheet_pixels[sy + y][sx + x]
    return out


def record_temp_asset(res_path: str, pack: str, note: str) -> None:
    """Insert or replace this asset's row in assets/temp_assets.md (§8)."""
    lines = TEMP_MANIFEST.read_text().split("\n")
    row = f"| {res_path} | {pack} | {note} |"
    lines = [l for l in lines if not l.strip().startswith(f"| {res_path} ")]
    separator = next(i for i, l in enumerate(lines) if l.strip().startswith("|---"))
    lines.insert(separator + 1, row)
    TEMP_MANIFEST.write_text("\n".join(lines))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("sheet")
    parser.add_argument("col", type=int)
    parser.add_argument("row", type=int)
    parser.add_argument("out")
    parser.add_argument("--cells", default="1x1")
    parser.add_argument("--scale", type=int, default=1)
    parser.add_argument("--note", default="")
    parser.add_argument("--preview", action="store_true")
    args = parser.parse_args()

    if args.sheet in SHEETS:
        sheet_path, pack_name = SHEETS[args.sheet]
    else:
        sheet_path, pack_name = pathlib.Path(args.sheet), args.sheet
    cells_w, cells_h = (int(n) for n in args.cells.lower().split("x"))

    pixels = slice_cells(read_png(sheet_path), args.col, args.row, cells_w, cells_h)
    data = encode_png(pixels, scale=args.scale)

    out = pathlib.Path(args.out)
    if not out.is_absolute():
        out = ASSETS / args.out
    out.parent.mkdir(parents=True, exist_ok=True)
    gitkeep = out.parent / ".gitkeep"
    if gitkeep.exists():
        gitkeep.unlink()
    out.write_bytes(data)
    print(f"wrote {out}")

    if ASSETS in out.parents:
        res_path = "res://assets/" + out.relative_to(ASSETS).as_posix()
        note = args.note or f"cell ({args.col},{args.row}) {args.cells}"
        record_temp_asset(res_path, pack_name, note)
        print(f"recorded in {TEMP_MANIFEST.relative_to(ROOT)}")

    if args.preview:
        preview = pathlib.Path("/tmp") / f"emberthread_conform_{out.name}"
        preview.write_bytes(encode_png(pixels, scale=8))
        print(f"wrote {preview}")


if __name__ == "__main__":
    main()
