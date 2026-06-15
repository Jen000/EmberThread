# Player

The mender. `CharacterBody2D` (floating motion mode) with cozy-paced
movement — soft acceleration, gentle stop, exported feel values.

## Visual structure (art pipeline §5)

Four modular layers, drawn back-to-front: **Body → Clothes → Face → Hair**
(`AnimatedSprite2D` each, under `Visual`). Each layer is ONE spritesheet,
resolved through an `AssetRegistry` key — no paths or textures in the scene:

```
player_<layer>[_<variant>].png      in assets/sprites/player/
e.g. player_body.png, player_hair.png, player_hair_afro.png
```

**Sheet layout** (`Player.SHEET_LAYOUT`) — a 4-column × 5-row grid of
16×32 cells, sliced into frames at load:

```
row 0  idle        cells 0–1 (2 frames, facing down)
row 1  walk_down   cells 0–3
row 2  walk_up     cells 0–3
row 3  walk_left   cells 0–3
row 4  walk_right  cells 0–3
```

All four layers share the same 16×32 footprint so they register when
stacked. Standing while facing up/left/right rests on frame 0 of that walk
row (the locked spec has down-facing idles only). A layer whose sheet is
missing simply draws nothing.

## Customisation

`appearance` maps layer → variant (`""` = the base sheet `player_<layer>.png`;
a variant resolves to `player_<layer>_<variant>.png`):

```gdscript
player.set_appearance("hair", "afro")    # -> player_hair_afro.png
```

The palette-swap shader (later) recolours skin on **body**, eye colour on
**face**, hair colour on **hair**, and the outfit's recolour zones on
**clothes**. **Adding a variant:** drop a correctly-named sheet into
`assets/sprites/player/` — no code changes.

## Conventions

- Scene origin is at the feet (collision is a small box there); the
  `Visual` node lifts the 16×32 frames so the bottom row sits on the
  origin. Keeps top-down depth-sorting honest later.
- `facing` holds the last movement direction — interactions, Pip
  behaviour and animation all read it.
