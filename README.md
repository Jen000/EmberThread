# Ember & Thread

A cozy top-down pixel-art adventure about mending broken magical objects,
recovering lost memories, and learning to understand someone who experiences
the world differently.

Built in Godot 4, by one person, as a gift. Cozy first, always.

## Running the game

1. Install [Godot 4.4 or newer](https://godotengine.org/download) (the
   standard build — no .NET needed).
2. In Godot's Project Manager, choose **Import** and select this folder's
   `project.godot`.
3. Press <kbd>F5</kbd> to run.

The first time the editor opens the project it generates `*.import` and
`*.uid` files next to assets and scripts — those should be committed.
(The `.godot/` cache folder is git-ignored.)

## Controls

| Action | Keyboard | Controller |
|---|---|---|
| Move | WASD / arrow keys | Left stick / D-pad |
| Interact *(reserved)* | E / Space / left click | A |
| Journal *(reserved)* | J / Tab | Y |
| Comfort pouch *(reserved)* | C | X |
| Pause *(reserved)* | Esc | Start |

Bindings use physical key positions, so WASD works on any keyboard layout.
*Reserved* actions are defined in the input map but nothing consumes them
yet — they exist so the control scheme is settled early. Remappable
controls are on the accessibility list and will arrive with the settings
menu.

## What's here so far

Step 1 of the build order: project setup. A placeholder test room
(rectangles standing in for Moss's workshop) with cozy-paced player
movement, collisions, and a smooth-follow camera.

## Project structure

```
assets/placeholder/   generated placeholder art
docs/design.md        the design bible — read it before building anything
scenes/main/          main scene + placeholder test room
scenes/player/        player scene + movement script
tools/                placeholder art generator
```

Convention: a feature's scene and its script live together in one folder.

## Pixel-art display settings (and why)

- Native/virtual resolution is **480x270** — exactly 4x at 1920x1080.
- Stretch mode is **`canvas_items`** with **integer** scaling and nearest
  filtering: the world stays on the chunky 480x270 pixel grid, while text
  and UI render at the real window resolution. That keeps the retro feel
  *and* leaves room for adjustable text size, which is a non-negotiable
  accessibility requirement.
- `snap_2d_transforms_to_pixel` keeps sprites aligned to the art grid.
- If a harder all-retro look is ever wanted (UI on the 480x270 grid too),
  switch `display/window/stretch/mode` to `"viewport"` — the trade-off is
  tiny, blocky text.

## Placeholder art

`tools/make_placeholder_art.py` (Python 3, stdlib only) generates the
placeholder sprites from ASCII pixel maps. Edit the maps and rerun:

```sh
python3 tools/make_placeholder_art.py
```

All of it is temporary and will be replaced with real art, region by region.
