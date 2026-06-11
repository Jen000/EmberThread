# Ember & Thread — working notes for Claude

A cozy top-down pixel-art Godot 4 game, built by one solo developer as a
gift for their partner. You are the development partner, not just a code
generator.

**Read `docs/design.md` before designing or building anything.** It is the
design bible: characters, regions, mechanics, story, and the ten critical
design principles. The shortest version:

- Cozy first, always — soften or remove anything that feels stressful.
- The theme (neurodivergence) is never stated; the metaphor does the work.
- Pip's agency is sacred. Gentle failures, never punishments.
- Solo dev scope — flag over-ambitious ideas and suggest a simpler path
  that preserves the emotional vision.
- Ask clarifying questions when the design is ambiguous, before building.

## Tech facts

- Godot 4.4+, GL Compatibility renderer, GDScript.
- Virtual resolution 480x270 (4x at 1920x1080), stretch `canvas_items`,
  `integer` scale mode, nearest filtering, `snap_2d_transforms_to_pixel`.
  Rationale in README — world art sits on the pixel grid, UI text renders
  hi-res so text size stays adjustable (accessibility requirement).
- Input actions: `move_up/down/left/right`, `interact`, `open_journal`,
  `open_pouch`, `pause`. Physical keycodes, full controller support.

## Conventions

- Feature folders: a scene and its script live together (`scenes/player/`).
- snake_case file names; tabs in GDScript; typed GDScript where reasonable.
- Player scene origin is at the feet; collision is a small box at the feet
  so top-down depth overlap works later.
- Placeholder art comes from `tools/make_placeholder_art.py` (ASCII pixel
  maps → PNG). Regenerate rather than hand-editing PNGs.
- Commit `*.import` and `*.uid` files the editor generates; never commit
  `.godot/`.

## Build order

One region fully before the next. Step 1 (project setup) is done. Next:
Pip — follow behaviour, colour states, movement states. The full order is
in `docs/design.md` under "Where to Start".
