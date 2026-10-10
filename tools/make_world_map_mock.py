#!/usr/bin/env python3
"""Render the stand-in world map at native resolution (480x270).

Writes assets/map/map_world.png: a pixel-art mock of the world layout
described in docs/map-layout.md, for the journal map until the artist's
map replaces it. Every pixel is placed on the native grid with a small
fixed palette: no anti-aliasing, no scaling.

It is stand-in art (tracked in assets/temp_assets.md), not final art.
To change the layout, edit the coordinates in the LAYOUT section below and
re-run. Everything is in native pixels, (0, 0) top-left.

Usage:
    python3 tools/make_world_map_mock.py            # write the map
    python3 tools/make_world_map_mock.py --preview  # also write a 4x preview
                                                    # to docs/images/
Needs Pillow and NumPy.
"""

import math
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from pixelfont import draw_text, text_width  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "map" / "map_world.png"
PREVIEW = ROOT / "docs" / "images" / "map_world_preview_4x.png"
W, H = 480, 270

# --- Palette ----------------------------------------------------------------
# Explorer's-map parchment, with each region's GDD palette for its terrain.
PARCH = (226, 210, 168)
PARCH_DOT = (208, 190, 146)
INK = (66, 48, 36)
INK_SOFT = (128, 100, 72)
SEA_SHALLOW = (128, 166, 178)
SEA = (98, 136, 158)
SEA_DEEP = (74, 106, 136)
WAVE = (164, 194, 202)
FOAM = (222, 232, 226)
SAND = (220, 196, 146)
ROAD = (150, 104, 62)
MARKER = (186, 52, 48)
WHITE = (246, 242, 230)

COAST_ROCK = (132, 146, 156)
COAST_ROCK_DARK = (96, 110, 124)
LANTERN = (250, 214, 110)
ROOF = (150, 82, 62)
WALL = (232, 222, 198)
WOOD = (120, 84, 56)

FOREST_FLOOR = (46, 88, 86)
FOREST_DARK = (24, 50, 54)
CANOPY = (54, 128, 116)
CANOPY_HI = (92, 162, 138)
STEM = (204, 190, 160)
GLOW_AMBER = (246, 186, 84)
GLOW_PURPLE = (176, 116, 210)
GLOW_BLUE = (120, 210, 236)

SNOW = (238, 240, 244)
SNOW_SHADE = (196, 204, 220)
ROCK = (150, 156, 178)
ROCK_DARK = (98, 104, 132)
MIDNIGHT = (44, 52, 88)
GOLD = (234, 182, 72)

RUIN_GROUND = (214, 172, 112)
STONE = (190, 160, 120)
STONE_DARK = (124, 98, 72)
OVERGROWN = (104, 140, 76)

# --- LAYOUT -----------------------------------------------------------------
# Coastline: the sea is everything west/south-west of this line, closed off
# along the bottom-left edge. Points run from the top edge down to the bottom.
COASTLINE = [
    (54, 0), (60, 24), (52, 52), (62, 82), (56, 108), (68, 136),
    (62, 160), (74, 184), (98, 204), (140, 218), (186, 236), (222, 270),
]

# Region terrain areas (polygons) and their label positions.
FOREST = [(66, 20), (148, 14), (172, 46), (168, 108), (128, 128),
          (74, 124), (64, 92), (60, 54)]
DARK_MAZE = [(74, 30), (110, 26), (118, 52), (96, 62), (72, 52)]
RUIN_RISE = [(352, 98), (418, 84), (450, 114), (444, 166), (394, 180),
             (354, 156)]

# Routes, as polylines.
ROAD_IN = [(352, 246), (318, 238), (282, 228), (246, 216), (204, 208),
           (182, 204)]
BOAT_ROUTE = [(92, 204), (60, 196), (42, 176), (40, 146), (46, 122),
              (58, 106)]
ROOT_PASSAGE = [(116, 72), (150, 92), (180, 106), (210, 116)]
PILGRIM_TRAIL = [(262, 40), (286, 52), (306, 68), (326, 82), (346, 98),
                 (362, 114)]

# Named locations: (x, y, label, label side). Side is where the label sits
# relative to the icon: "r", "l", "u" (above) or "d" (below).
LOCATIONS = {
    "coast": [
        (69, 152, "LIGHTHOUSE", "r"),
        (90, 142, "CLIFF LOOKOUT", "u"),
        (92, 202, "HARBOUR", "d"),
        (105, 189, "TIDE POOLS", "l"),
        (140, 180, "MARKET", "u"),
        (158, 196, "INN", "r"),
    ],
    "forest": [
        (150, 112, "FORAGERS CAMP", "d"),
        (126, 98, "SPORE MEADOW", "r"),
        (116, 72, "HOLLOW TREE", "r"),
        (94, 44, "DARK MAZE", "d"),
        (146, 30, "WATERFALL", "d"),
    ],
    "mountain": [
        (256, 18, "PEAK LOOKOUT", "r"),
        (236, 64, "SHRINE", "l"),
        (264, 70, "HOT SPRING", "r"),
        (238, 86, "LIBRARY", "l"),
        (232, 116, "MARKET & INN", "d"),
    ],
    "ruins": [
        (369, 120, "GATEHOUSE", "l"),
        (395, 131, "COURTYARD", "d"),
        (424, 114, "THRONE ROOM", "u"),
        (404, 100, "BATTLEMENTS", "u"),
        (427, 149, "LIBRARY", "d"),
        (375, 164, "TUNNELS", "l"),
    ],
}

REGION_TITLES = [
    (112, 236, "COASTAL TOWN"),
    (112, 8, "MUSHROOM FOREST"),
    (256, 142, "MOUNTAIN SHRINE"),
    (400, 186, "CASTLE RUINS"),
]

# Region entry/exit markers, matching the travel routes.
GATES = [(182, 204), (92, 204), (58, 106), (116, 72), (210, 116),
         (262, 40), (362, 114)]

MOSS_WORKSHOP = (352, 246)


# --- Drawing helpers -----------------------------------------------------------

class Canvas:
    def __init__(self):
        self.px = np.zeros((H, W, 3), dtype=np.uint8)
        self.px[:, :] = PARCH

    def put(self, x, y, colour):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < W and 0 <= y < H:
            self.px[y, x] = colour

    def get(self, x, y):
        return tuple(self.px[y, x])

    def rect(self, x, y, w, h, colour):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.put(xx, yy, colour)

    def fill_mask(self, mask, colour):
        self.px[mask] = colour

    def sprite(self, x, y, rows, colours):
        """Stamp a tiny sprite; rows of chars, '.' transparent."""
        for dy, row in enumerate(rows):
            for dx, ch in enumerate(row):
                if ch != ".":
                    self.put(x + dx, y + dy, colours[ch])

    def save(self, path):
        Image.fromarray(self.px, "RGB").convert("RGBA").save(path)


def polygon_mask(points):
    img = Image.new("1", (W, H), 0)
    ImageDraw.Draw(img).polygon(points, fill=1)  # mode "1" is never anti-aliased
    return np.array(img, dtype=bool)


def hash01(x, y, salt=0):
    """Deterministic per-pixel pseudo-random value in [0, 1)."""
    n = (x * 374761393 + y * 668265263 + salt * 2147483647) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return (n ^ (n >> 16)) / 2**32


def dilate(mask, steps=1):
    out = mask.copy()
    for _ in range(steps):
        grown = out.copy()
        grown[1:, :] |= out[:-1, :]
        grown[:-1, :] |= out[1:, :]
        grown[:, 1:] |= out[:, :-1]
        grown[:, :-1] |= out[:, 1:]
        out = grown
    return out


def walk(points, step=1.0):
    """Yield evenly spaced integer points along a polyline."""
    for (x1, y1), (x2, y2) in zip(points, points[1:]):
        n = max(1, int(math.hypot(x2 - x1, y2 - y1) / step))
        for i in range(n):
            t = i / n
            yield round(x1 + (x2 - x1) * t), round(y1 + (y2 - y1) * t)
    yield points[-1]


def path_line(c, points, colour, on=2, off=2, width=1):
    seen = []
    for p in walk(points):
        if not seen or seen[-1] != p:
            seen.append(p)
    for i, (x, y) in enumerate(seen):
        if i % (on + off) < on:
            c.put(x, y, colour)
            if width == 2:
                c.put(x + 1, y, colour)


# --- Layers ------------------------------------------------------------------

def draw_sea(c):
    sea = polygon_mask(COASTLINE + [(0, 270), (0, 0)])
    land = ~sea
    c.fill_mask(sea, SEA_DEEP)
    c.fill_mask(sea & dilate(land, 14), SEA)
    c.fill_mask(sea & dilate(land, 5), SEA_SHALLOW)
    c.fill_mask(sea & dilate(land, 1), FOAM)
    c.fill_mask(land & dilate(sea, 2), SAND)
    # Wave marks out at sea: a little "~" every so often.
    for y in range(6, H - 4, 9):
        for x in range(4, W, 14):
            jx = x + int(hash01(x, y) * 8) + (y // 9 % 2) * 6
            if all(sea[y + dy, min(W - 1, jx + dx)] for dx in range(-2, 6) for dy in (-2, 0, 2)) \
                    and not dilate(land, 6)[y, jx]:
                c.put(jx, y, WAVE)
                c.put(jx + 1, y - 1, WAVE)
                c.put(jx + 2, y, WAVE)
                c.put(jx + 3, y - 1, WAVE)
    return sea


def draw_parchment_texture(c, sea):
    for y in range(H):
        for x in range(W):
            if not sea[y, x] and hash01(x, y, 7) < 0.035 and c.get(x, y) == PARCH:
                c.put(x, y, PARCH_DOT)


def draw_coast(c):
    # Rocky cliffs along the western shore of the town.
    cliffs = polygon_mask([(62, 136), (96, 138), (108, 152), (98, 170), (80, 176), (66, 166), (60, 150)])
    c.fill_mask(cliffs, COAST_ROCK)
    for y in range(H):
        for x in range(W):
            if cliffs[y, x] and hash01(x, y, 3) < 0.18:
                c.put(x, y, COAST_ROCK_DARK)
    # Lighthouse on the cliff edge, lit.
    # Lighthouse at the cliff tip, lit.
    c.sprite(66, 146, [
        "...y...",
        "..yLy..",
        "...d...",
        "..rrr..",
        "..www..",
        "..rrr..",
        "..www..",
        "..rrr..",
        ".ddddd.",
    ], {"y": LANTERN, "L": WHITE, "r": MARKER, "w": WALL, "d": INK})
    # Lantern beam out over the water toward the harbour.
    for i in range(2, 22, 3):
        c.put(66 - i // 2, 147 + i, LANTERN)
        c.put(66 - i // 2, 148 + i, LANTERN)
    # Cobbled town square around the market.
    square = polygon_mask([(124, 176), (166, 174), (176, 198), (132, 200)])
    for y in range(H):
        for x in range(W):
            if square[y, x] and (x + y) % 3 and hash01(x, y, 17) < 0.5:
                c.put(x, y, PARCH_DOT)
    # Pier and the old fishing boat.
    for x in range(86, 100):
        c.put(x, 202, WOOD)
        if x % 3 == 0:
            c.put(x, 203, WOOD)
    c.sprite(76, 200, ["...w...", "...ww..", "...w...", "bbbbbbb", ".bbbbb."], {"w": WHITE, "b": WOOD})
    # Cottages around the market and inn.
    house = ["..rr..", ".rrrr.", "rrrrrr", "wwwwww", "wwdwyw", "wwdwww"]
    for hx, hy in [(128, 186), (146, 189), (152, 174), (122, 174), (168, 184), (134, 196)]:
        c.sprite(hx, hy, house, {"r": ROOF, "w": WALL, "d": WOOD, "y": LANTERN})
    # The inn: bigger, with a lantern.
    c.sprite(154, 192, [
        "...rrr...",
        "..rrrrr..",
        ".rrrrrrr.",
        "rrrrrrrrr",
        "wwwwwwwww",
        "wywwdwwyw",
        "wwwwdwwww",
    ], {"r": ROOF, "w": WALL, "d": WOOD, "y": LANTERN})
    # Market stalls: striped awnings.
    for sx in (136, 142):
        c.sprite(sx, 180, ["rwrwr", "d...d"], {"r": MARKER, "w": WALL, "d": WOOD})
    # Tide pools: little rings of shallow water among the sand.
    for px, py in [(102, 186), (108, 189), (104, 192)]:
        c.sprite(px, py, [".s.", "sfs", ".s."], {"s": SEA_SHALLOW, "f": FOAM})


def mushroom_tree(c, x, y, rng):
    glow = [GLOW_AMBER, GLOW_PURPLE, GLOW_BLUE][int(rng * 3)]
    c.sprite(x - 2, y - 3, [
        ".hhh.",
        "hcccc",
        "ccgcc",
        "..s..",
        "..s..",
    ], {"h": CANOPY_HI, "c": CANOPY, "g": glow, "s": STEM})


def draw_forest(c):
    forest = polygon_mask(FOREST)
    maze = polygon_mask(DARK_MAZE)
    c.fill_mask(forest, FOREST_FLOOR)
    c.fill_mask(maze, FOREST_DARK)
    # Clearings so locations and labels stay readable.
    clear = np.zeros_like(forest)
    for x, y, label, side in LOCATIONS["forest"]:
        clear |= polygon_mask([(x - 7, y - 7), (x + 7, y - 7), (x + 7, y + 7), (x - 7, y + 7)])
    # The spore meadow is a wide open patch.
    meadow = polygon_mask([(116, 90), (142, 88), (146, 104), (120, 108)])
    c.fill_mask(meadow, CANOPY)
    for y in range(88, 108):
        for x in range(116, 147):
            if meadow[y, x] and hash01(x, y, 11) < 0.12:
                c.put(x, y, [GLOW_AMBER, GLOW_PURPLE][int(hash01(x, y, 12) * 2)])
    # Scatter mushroom trees on a jittered grid.
    for gy in range(18, 128, 7):
        for gx in range(60, 176, 7):
            x = gx + int(hash01(gx, gy, 1) * 5) - 2
            y = gy + int(hash01(gx, gy, 2) * 5) - 2
            if not (0 <= x < W and 0 <= y < H):
                continue
            if forest[y, x] and not clear[y, x] and not meadow[y, x] \
                    and forest[max(0, y - 4), x] and forest[min(H - 1, y + 3), x]:
                if maze[y, x] and hash01(x, y, 4) < 0.5:
                    # Inside the maze only Pip's light shows the way: dim stems.
                    c.sprite(x - 1, y - 1, ["ddd", ".s."], {"d": FOREST_FLOOR, "s": INK_SOFT})
                else:
                    mushroom_tree(c, x, y, hash01(x, y, 5))
    # Hollow tree: the village hub.
    c.sprite(110, 63, [
        "..hhhhh..",
        ".hcccccc.",
        "hccgccgcc",
        "ccccccccc",
        "...sss...",
        "...sws...",
        "..ssdss..",
    ], {"h": CANOPY_HI, "c": CANOPY, "g": GLOW_AMBER, "s": STEM, "w": LANTERN, "d": INK})
    # Mossy waterfall: a ribbon of water off a ledge into a pool.
    for y in range(22, 32):
        c.put(146, y, FOAM)
        c.put(147, y, SEA_SHALLOW)
    c.sprite(143, 32, [".sss.", "sfffs", ".sss."], {"s": SEA_SHALLOW, "f": FOAM})
    # Forager's camp: tent and fire.
    c.sprite(146, 106, ["..w...", ".www..", "wwwww.", "w.d.wy"], {"w": WALL, "d": INK, "y": GLOW_AMBER})


def mountain(c, peak_x, peak_y, half_w, base_y, snow_rows):
    for y in range(peak_y, base_y + 1):
        t = (y - peak_y) / max(1, base_y - peak_y)
        span = int(half_w * t)
        for x in range(peak_x - span, peak_x + span + 1):
            lit = x <= peak_x
            if y - peak_y < snow_rows + (2 if (x * 7 + y) % 5 == 0 else 0):
                colour = SNOW if lit else SNOW_SHADE
            else:
                colour = ROCK if lit else ROCK_DARK
            c.put(x, y, colour)
        c.put(peak_x - span, y, MIDNIGHT)
        c.put(peak_x + span, y, MIDNIGHT)


def draw_mountain(c):
    # Snowfield the town sits on.
    snowfield = polygon_mask([(200, 120), (220, 70), (252, 30), (300, 48),
                              (318, 104), (296, 134), (226, 136)])
    c.fill_mask(snowfield, SNOW)
    for y in range(H):
        for x in range(W):
            if snowfield[y, x] and hash01(x, y, 9) < 0.06:
                c.put(x, y, SNOW_SHADE)
    # Back ridge, then the main peak.
    mountain(c, 288, 26, 20, 58, 8)
    mountain(c, 216, 34, 16, 60, 7)
    mountain(c, 304, 44, 14, 66, 6)
    mountain(c, 256, 8, 26, 54, 12)
    # Winding stone steps between the levels.
    path_line(c, [(232, 112), (246, 104), (234, 96), (246, 88), (238, 80),
                  (250, 72), (240, 66), (254, 52), (256, 22)], STONE_DARK, on=1, off=1)
    # Shrine with a golden roof.
    c.sprite(230, 56, [
        "ggggggggg",
        ".ggggggg.",
        "..m...m..",
        "..mgggm..",
        "..m...m..",
        ".sssssss.",
    ], {"g": GOLD, "m": MARKER, "s": STONE_DARK})
    # Hot spring with steam, and the familiar stones beside it.
    c.sprite(259, 64, [".f.f..", "f.f...", ".ssss.", "sBBBBs", "sBBBBs", ".ssss."],
             {"f": WHITE, "s": ROCK_DARK, "B": GLOW_BLUE})
    # Temple library, sealed by the guild.
    c.sprite(234, 81, [".mmmmm.", "mmmmmmm", "mw.w.wm", "mwwXwwm", "mwwXwwm"],
             {"m": MIDNIGHT, "w": STONE, "X": MARKER})
    # Market and inn at the base.
    house = ["..gg..", ".gggg.", "gggggg", "wwwwww", "wydwyw", "wwdwww"]
    for hx, hy in [(218, 106), (226, 110), (236, 106), (244, 111)]:
        c.sprite(hx, hy, house, {"g": MIDNIGHT, "w": WALL, "d": WOOD, "y": LANTERN})


def draw_ruins(c):
    rise = polygon_mask(RUIN_RISE)
    c.fill_mask(rise, RUIN_GROUND)
    for y in range(H):
        for x in range(W):
            if rise[y, x]:
                r = hash01(x, y, 13)
                if r < 0.08:
                    c.put(x, y, OVERGROWN)
                elif r < 0.12:
                    c.put(x, y, STONE)
    # Curtain wall (2px, crenellated), broken in places.
    wall = [(372, 116), (432, 108), (444, 140), (436, 160), (382, 160), (372, 116)]
    for i, (x, y) in enumerate(walk(wall)):
        if 0.12 < hash01(i // 3, 0, 21):
            c.put(x, y + 1, STONE_DARK)
            c.put(x, y, STONE_DARK)
            c.put(x, y - 1, STONE)
            if i % 2:
                c.put(x, y - 2, STONE)
    # Towers; the south-east one has fallen.
    tower = ["s.s.s", "sssss", "sDsDs", "sssss", "ssDss", "sssss", "DDDDD"]
    for tx, ty in [(368, 108), (428, 100), (440, 132), (378, 152)]:
        c.sprite(tx, ty, tower, {"s": STONE, "D": STONE_DARK})
    c.sprite(432, 156, ["...s...", ".s.ss..", "sDssDss"], {"s": STONE, "D": STONE_DARK})
    # Keep / throne room, with Wren's lamp in the window.
    c.sprite(420, 110, [
        "s.s...s.s",
        "sss...sss",
        "sDs.s.sDs",
        "sssssssss",
        "sDsssssDs",
        "sssyyysss",
        "sssyyysss",
        "sssssssss",
        "ssssDssss",
        "DDDDDDDDD",
    ], {"s": STONE, "D": STONE_DARK, "y": LANTERN})
    # Courtyard garden.
    c.sprite(392, 128, [".g.g.g.", "ggggggg", "gg.y.gg", "g.yyy.g", "ggggggg"], {"g": OVERGROWN, "y": GLOW_AMBER})
    # Collapsed library: a heap of stone and pages.
    c.sprite(424, 146, ["...w...", "..sDw..", ".sDsDw.", "sDsDsDs"], {"s": STONE, "D": STONE_DARK, "w": WALL})
    # Tunnel mouth.
    c.sprite(372, 162, [".sssss.", "ssDDDss", "sDDDDDs", "sDDDDDs"], {"s": STONE_DARK, "D": INK})
    # Gatehouse arch.
    c.sprite(366, 116, ["s.s.s.s", "sssssss", "ssDDDss", "sDDDDDs", "sDD.DDs"], {"s": STONE, "D": STONE_DARK})
    # Battlement walkway.
    for x in range(396, 414):
        c.put(x, 104 - (x - 396) // 6, STONE_DARK if x % 2 else STONE)


def draw_countryside(c):
    """Hand-drawn hills, grass tufts and copses on the open land between regions."""
    def empty(x, y, r):
        for yy in range(y - r, y + r + 1):
            for xx in range(x - r, x + r + 1):
                if not (4 <= xx < W - 4 and 4 <= yy < H - 4):
                    return False
                if c.get(xx, yy) not in (PARCH, PARCH_DOT):
                    return False
        return True

    for gy in range(10, H - 8, 11):
        for gx in range(8, W - 8, 13):
            x = gx + int(hash01(gx, gy, 31) * 8) - 4
            y = gy + int(hash01(gx, gy, 32) * 6) - 3
            kind = hash01(gx, gy, 33)
            if kind < 0.16 and empty(x, y, 5):
                c.sprite(x - 3, y - 1, ["..iii..", ".i...i.", "i.....i"], {"i": INK_SOFT})
            elif kind < 0.34 and empty(x, y, 3):
                c.sprite(x - 1, y - 1, ["g.g", ".g."], {"g": OVERGROWN})
            elif kind < 0.44 and empty(x, y, 4):
                c.sprite(x - 2, y - 3, [".ccc.", "ccccc", "ccccc", ".cdc.", "..d.."],
                         {"c": OVERGROWN, "d": WOOD})


def draw_routes(c):
    path_line(c, ROAD_IN, ROAD, on=2, off=1)
    path_line(c, PILGRIM_TRAIL, ROAD, on=2, off=1)
    path_line(c, BOAT_ROUTE, FOAM, on=3, off=2)
    path_line(c, ROOT_PASSAGE, INK, on=1, off=2)
    # Moss's workshop, where the journey starts.
    x, y = MOSS_WORKSHOP
    c.sprite(x - 3, y - 6, ["..r..", ".rrr.", "rrrrr", "wwwww", "wwdww", "wwdww"],
             {"r": ROOF, "w": WALL, "d": WOOD})
    # Where Pip is found, curled in the ash on the road.
    c.sprite(256, 216, ["aaa", "aWa", "aaa"], {"a": INK_SOFT, "W": WHITE})


def draw_gates(c):
    for x, y in GATES:
        c.sprite(x - 2, y - 2, ["..m..", ".mWm.", "mWWWm", ".mWm.", "..m.."],
                 {"m": MARKER, "W": WHITE})


def label(c, x, y, text, side, colour=INK, outline=PARCH):
    tw = text_width(text)
    if side == "r":
        lx, ly = x + 6, y - 2
    elif side == "l":
        lx, ly = x - 6 - tw, y - 2
    elif side == "u":
        lx, ly = x - tw // 2, y - 10
    else:
        lx, ly = x - tw // 2, y + 6
    draw_text(c.put, lx, ly, text, colour, outline)


def draw_labels(c):
    styles = {
        "coast": (INK, PARCH),
        "forest": (WHITE, FOREST_DARK),
        "mountain": (MIDNIGHT, SNOW),
        "ruins": (INK, RUIN_GROUND),
    }
    for region, places in LOCATIONS.items():
        fg, bg = styles[region]
        for x, y, text, side in places:
            label(c, x, y, text, side, fg, bg)
    for x, y, text in REGION_TITLES:
        draw_text(c.put, x - text_width(text) // 2, y, text, MARKER, WHITE)
    label(c, MOSS_WORKSHOP[0], MOSS_WORKSHOP[1] - 3, "MOSS", "d", INK, PARCH)


def draw_compass(c):
    cx, cy = 456, 236
    c.sprite(cx - 4, cy - 8, [
        "....m....",
        "....m....",
        "...mWm...",
        "...mWm...",
        "mmmmimmmm",
        "...mim...",
        "...mim...",
        "....i....",
        "....i....",
    ], {"m": INK, "W": MARKER, "i": INK_SOFT})
    draw_text(c.put, cx - 1, cy - 15, "N", INK, PARCH)


def draw_frame(c):
    for x in range(W):
        for y in (0, 1, H - 2, H - 1):
            c.put(x, y, INK)
    for y in range(H):
        for x in (0, 1, W - 2, W - 1):
            c.put(x, y, INK)
    for x in range(3, W - 3):
        c.put(x, 3, INK_SOFT)
        c.put(x, H - 4, INK_SOFT)
    for y in range(3, H - 3):
        c.put(3, y, INK_SOFT)
        c.put(W - 4, y, INK_SOFT)


def build():
    c = Canvas()
    sea = draw_sea(c)
    draw_parchment_texture(c, sea)
    draw_coast(c)
    draw_forest(c)
    draw_mountain(c)
    draw_ruins(c)
    draw_routes(c)
    draw_countryside(c)
    draw_gates(c)
    draw_labels(c)
    draw_compass(c)
    draw_frame(c)
    return c


def main():
    c = build()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    c.save(OUT)
    print(f"wrote {OUT.relative_to(ROOT)}")
    if "--preview" in sys.argv:
        img = Image.open(OUT).resize((W * 4, H * 4), Image.NEAREST)
        PREVIEW.parent.mkdir(parents=True, exist_ok=True)
        img.save(PREVIEW)
        print(f"wrote {PREVIEW.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
