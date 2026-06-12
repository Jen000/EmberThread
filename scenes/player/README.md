# Player

The mender. `CharacterBody2D` (floating motion mode) with cozy-paced
movement — soft acceleration, gentle stop, exported feel values.

## Visual structure (art pipeline §5)

Modular 16×32 layers, drawn bottom-to-top: **Base → Outfit → Hair →
Accessory** (`AnimatedSprite2D` each, under `Visual`). Frames are resolved
through `AssetRegistry` keys — no paths, no textures embedded in the scene:

```
player_<layer>[_<variant>]_<anim>_<NN>.png      in assets/sprites/player/
e.g. player_base_idle_01.png, player_hair_short_walk_left_03.png
```

Animations per layer: `idle` (2 frames, facing down) and `walk_down/up/
left/right` (4 frames each). Standing while facing up/left/right rests on
frame 1 of that walk cycle (the locked spec has down-facing idles only).

## Customisation

`appearance` maps layer → variant (`hair: "short"` →
`player_hair_short_*`). The customisation screen calls:

```gdscript
player.set_appearance("hair", "afro")
```

**Adding a variant:** drop a full frame set named
`player_<layer>_<variant>_<anim>_<NN>.png` into `assets/sprites/player/` —
no code changes. Current stand-in variants: `hair_short`, `hair_afro`,
`outfit_default`, `accessory_default` (base has no variant suffix).

## Conventions

- Scene origin is at the feet (collision is a small box there); the
  `Visual` node lifts the 16×32 frames so the bottom row sits on the
  origin. Keeps top-down depth-sorting honest later.
- `facing` holds the last movement direction — interactions, Pip
  behaviour and animation all read it.
