# Ember & Thread — Art Pipeline (Placeholder Strategy & Gap-Filler Sourcing)

> **Core principle:** Art is a swappable layer, not a dependency. Build every system against placeholder or gap-filler assets that match the locked specification exactly. When the artist delivers, real assets replace the stand-ins as a 1:1 file swap — no code changes, no refactors, no renamed references. If swapping a correctly-named, correctly-sized file requires touching a single line of code, the pipeline is wrong.

All dimensions, frame counts, naming, and formats below are taken from the Art Brief (Part 8) and are authoritative. This document is self-contained — Fable does not need to parse the brief to find these numbers.

## 1. Locked specifications

**Native resolution:** 480×270 px, scaled 4× to 1920×1080. Design and build everything at native resolution.

**Sprite sizes**

| Asset | Size |
|---|---|
| Player / NPC overworld sprite | 16×32 |
| Pip | 8×10 |
| Ground tiles | 16×16 |
| Objects / items | 16×16 |
| Larger objects (mosaic, armour) | 32×32 |
| Dialogue portraits (all characters incl. player) | 64×64 |
| Journal page illustrations | 96×96 or larger |
| Map | 480×270 |
| UI elements | Flexible (build at intended display size) |

**Frame counts**

- Player: idle 2; walk down / up / left / right, 4 each.
- Pip (per colour state): idle-bob 3; distressed 3; leading 2; glow-pulse 3 (loops); iridescent shimmer colour-cycle 6–8.
- Key NPCs: idle 2 (subtle breathing/shift).

**File format**

- PNG only — never JPG or GIF.
- 32-bit RGBA, transparent background (never white or coloured).
- No anti-aliasing; hard, crisp pixel edges.
- Lossless, no compression.
- Godot import: set **Filter = Nearest** on every texture, or it renders blurry.

## 2. Non-negotiable rules

- Every stand-in matches the final asset's **size, frame count, frame layout, and modular layer structure** from §1. A stand-in is the right size and shape from day one; only its pixels are temporary.
- **No hardcoded asset paths anywhere in game logic.** All paths resolve through the asset registry (§4). Systems reference assets by logical key, never by file path.
- Stand-ins live at the **exact final path and filename** the real asset will occupy, so the artist's deliverable overwrites them in place.
- Every stand-in is trackable and removable (§6, §8) so none ever ships by accident.
- Folder structure and naming (§3) are locked before any asset enters the project and never reorganised to suit the real art — the real art conforms to them.

## 3. Folder structure & naming convention

Tree under `res://assets/` (fixed):

```
res://assets/
  sprites/
    player/        # modular layers: body, clothes, face, hair
    pip/
    npcs/          # one folder per NPC
    objects/
  tilesets/
    coastal/       # reference region — built first
    forest/
    mountain/
    ruins/
  ui/
    journal/
    pouch/
    dialogue/
  portraits/
  cutscenes/
  map/
  audio/
    sfx/
    music/
```

**Naming convention — from the Art Brief, authoritative.** Match it exactly; the artist's files will use it, so the stand-ins must too.

- Player layers (one spritesheet each, a 4×5 grid of 16×32 cells — see §5): `player_body.png`, `player_clothes.png`, `player_face.png`, `player_hair.png`; variants add a suffix (`player_hair_afro.png`, `player_clothes_winter.png`)
- Pip: `pip_idle_01.png`, `pip_distressed_01.png`, `pip_leading_01.png`, `pip_glow_01.png`
- NPCs: `npc_sable_sprite.png`, `npc_sable_portrait.png`
- Tiles: `tile_coastal_grass_01.png`, `tile_forest_ground_01.png`
- Objects: `object_lantern_broken.png`, `object_lantern_whole.png`
- Memories / journal: `memory_navigator_01.png`, `memory_navigator_02.png`

Animation frames take a zero-padded two-digit `_NN` suffix (`_01`, `_02`), exactly as the Pip examples show.

## 4. Asset registry

A single resource map (e.g. `res://core/asset_registry.gd`, or `.tres` resources) maps logical keys to paths and is the only thing that touches file paths:

```gdscript
# Systems do this:
var tex = AssetRegistry.get_sprite("pip_idle")
# Systems NEVER do this:
var tex = load("res://assets/sprites/pip/pip_idle_01.png")
```

This registry is the single seam between art and code. When art lands, the files change; the registry and every caller stay untouched.

## 5. Per-system stand-in specifications

Build the *structure* to spec; the pixels are throwaway.

**Player (16×32, modular):** Four layers, drawn back-to-front — **body, clothes, face, hair** — each delivered as ONE spritesheet (`player_<layer>.png`) laid out as a 4-column × 5-row grid of 16×32 cells: row 0 idle (2 frames used), rows 1–4 walk down/up/left/right (4 each). Every layer shares the same 16×32 footprint so they register when stacked. The engine slices the grid (`Player.SHEET_LAYOUT`); the palette-swap shader recolours skin (body), eye colour (face), hair colour (hair) and the outfit's recolour zones (clothes). Stand-ins are flat-colour blocks, one colour per layer. **Block placeholder only — never sourced from a pack** (Kenney has no equivalent that splits into these layers).

**Pip (8×10):** State machine and glow drive frame swaps. Stand-in is a small coloured shape with a glow node, with per-state frame sets at the right counts (idle-bob 3, distressed 3, leading 2, glow-pulse 3, shimmer 6–8) so real animation slots in state by state. Block placeholder only — 8×10 is bespoke.

**Tilesets (16×16):** Solid-colour tiles or sourced gap-filler tiles (§7) at 16×16, with collision, autotile/terrain rules, and region loading all configured against them. Coastal is the reference region — fully built before any other begins.

**NPCs (16×32):** Coloured rectangle at 16×32 with the NPC's name rendered on it (idle 2), so visit counters, dialogue triggers, and Pip reactions are testable. Block placeholder — keep distinct from the cast art.

**Portraits (64×64):** Plain labelled 64×64 frame per character so the dialogue UI lays out against real bounds.

**UI (journal, pouch, dialogue):** Plain frames at their intended display sizes with correct anchors/margins, so dynamic journal pages, the pouch grid, and dialogue text-fitting build against real bounds.

**Objects (16×16 / 32×32):** Sourced gap-filler (§7) or blocks at the correct size, with broken/whole variants where mending applies (`object_*_broken` / `object_*_whole`).

**Journal illustrations (96×96+), cutscene stills, map (480×270):** Single labelled placeholder per slot at the right size so cutscene timing, journal layout, and map navigation are real. Bespoke sizes — block/greybox only.

## 6. Placeholder visual convention

Pure block placeholders must be unmistakable so they can't ship silently:

- Dominant **magenta (#FF00FF)** fill or border.
- A baked-in text label where space allows (subject + `PLACEHOLDER`).
- A debug flag that lists every registered placeholder via a console warning at load.

Sourced gap-filler (§7) looks finished and can't rely on this — it's tracked separately in §8.

## 7. Gap-filler sourcing

Gap-filler makes the dev build feel real while the artist works. It's temporary and gets replaced.

- **Do not generate original art.** Don't draw or procedurally render bespoke sprites. Integrate and conform existing assets; don't author art. Time spent making art is time not spent on systems.
- **Approved source: Kenney only** (kenney.nl / Kenney Game Assets All-in-1). CC0 — no attribution, no commercial restriction, no redistribution limit — safe to commit, including to a public repo. The project lead places the download locally in the repo; do not fetch from the web.
- **No other pack without explicit written approval.** If anything outside Kenney comes up, or any licensing question arises, **stop and flag it** rather than committing it.
- **If Kenney has no suitable asset, fall back to a block placeholder (§6).** Do not substitute another pack and do not invent art.

**Where Kenney fits (and where it doesn't).** The locked tile/object sizes — 16×16 and 32×32 — are the sweet spot: many Kenney pixel packs are natively 16×16, so they integer-scale cleanly. Pick the Kenney pack whose native grid is 16×16 (or a clean multiple), and scale only by whole-number factors with nearest-neighbour — never fractional scaling, which blurs pixel art. **Do not source the player, Pip, NPCs, portraits, journal illustrations, or the map** — their sizes (16×32 modular, 8×10, 64×64, 96×96+, 480×270) and structures have no clean Kenney equivalent, so those stay block/greybox placeholders.

**Conform every sourced asset:** resize/rename to the §1 sizes and §3 naming, place it at its final path, and register it via §4 — no hardcoded paths.

## 8. Tracking temp assets

Sourced art looks finished, so it can ship by accident. Compensate:

- Maintain a `temp_assets.md` manifest: every sourced asset with its Kenney pack and source.
- Flag each sourced asset as temporary in the registry, so a debug check lists all gap-filler still in use alongside the §6 blocks.
- Kenney is CC0 and needs no attribution, so no `CREDITS` entry is required. Any future approved pack that requires attribution gets one.

## 9. Audio stubs

SFX is in-house and developed alongside the build: route all sound through a `SoundManager` / audio bus, triggered by logical key (`play_sfx("mend_complete")`), with temp or silent clips at the right paths. Real SFX swaps in 1:1, same as art.

Music comes later: stub a `MusicManager` with the same key-based interface and a silent or single temp loop, so the region/scene system already calls into it. Leave the slot; fill it when the composer delivers.

## 10. Release gates

**Art-readiness (per system).** A system is art-ready when dropping a correctly-named, correctly-sized file into its asset folder changes what appears in-game with **zero code edits**. Verify before calling any system done: swap one stand-in for a differently-coloured test file and confirm it appears with no other change. If it doesn't, the seam is leaking — fix it before moving on.

**Pre-ship (whole build).** Not shippable while any stand-in remains. Before release: every placeholder and gap-filler asset is replaced by final art, the temp manifest is empty, and no block placeholders remain. Release blocker, not a cleanup task.
