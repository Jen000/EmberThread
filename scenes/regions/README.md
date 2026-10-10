# Regions

A region is one explorable place: Coastal Town, Forest Village, Mountain
Shrine Town, Castle Ruins. Each is its own scene. `Main` loads one and puts
the player, Pip and the HUD alongside it.

Coastal Town is the reference region. Build the others by copying its
pattern.

## The pieces

```
scenes/regions/
  region.gd               base script for every region scene (bounds, spawn
                          points, edge walls, location discoveries)
  location_zone.gd        a named place, e.g. the Tide Pools
  block_building.gd       block stand-in for a building at its real footprint
  coastal/
    coastal_town.tscn     the layout
    coastal_town.gd       what the town does (harbour exit, later NPCs)
assets/tilesets/coastal/
  coastal_tileset.tres    the shared coastal tileset: terrains + collision
scenes/main/main.gd       loads `region_scene`, places the player at its spawn
```

## Inside a region scene

| Node | What goes on it |
|---|---|
| `Ground` | Base terrain: sea, sand, grass. Sea has collision |
| `Paths` | Paths and ground detail painted over the base |
| `Obstacles` | Walls, cliff faces, rocks. Stone has collision |
| `Objects` | Buildings, trees, NPCs, signs, interactables. Y-sorted, so the player walks behind them. Buildings are `BlockBuilding` stand-ins for now |
| `AbovePlayer` | Roofs, treetops, the lighthouse top: anything drawn over the player. No collision |
| `SpawnPoints/default` | Where the player arrives |
| `Locations` | One `LocationZone` per named place |

The region's root is y-sorted, and so is `Main`, so the player, Pip and
everything under `Objects` sort together by their feet. Tile layers sit
underneath (negative `z_index`), except `AbovePlayer`, which sits on top.

## Scale

Build at the character's scale, not the map's. The player is about 20×35
px, so as a rule of thumb:

| Thing | Size |
|---|---|
| Road | 3 tiles wide (48 px) |
| Side path | 2 tiles |
| Cottage | 72×64 px (about 4×4 tiles) |
| Inn | 144×88 px |
| Lighthouse | 40×104 px |
| Market stall | 32×28 px |
| Tree | 24×40 px |

The map mocks in `assets/map/` show **where** things are, not how big they
are. Never trace them 1:1, and never use them as ground.

The Coastal Town is 80×48 tiles (1280×768 px, a little under three screens
each way).

## Changing the town

The town is already painted as a first blockout, from the mock's layout at
character scale: sea and beach, grass, sandy paths and the market square,
the cliff with its stairs, and block buildings. Treat it as a starting
point and repaint freely.

1. Open `scenes/regions/coastal/coastal_town.tscn`.
2. To repaint ground, select a tile layer, open the **TileMap** panel →
   **Terrains** tab, pick terrain set 0 and a terrain, and paint in
   **Connect** mode. Godot picks the right edge and corner tiles.
3. To move a building, drag it in `Objects`. Its origin is the middle of its
   base. To resize one, change `size` in the Inspector. Collision follows.
4. Press F5 and walk it.

## BlockBuilding

A flat-colour block at a building's real footprint, with a magenta border
and a label so it can't pass for finished art. Only the lower half (by
default) collides: the roof overhangs, so you can walk right up to the
front wall and behind the roof.

| Property | Meaning |
|---|---|
| `size` | Width × height in pixels, standing on its base |
| `label` | Text drawn on the wall |
| `roof_colour`, `wall_colour` | Block colours |
| `solid_fraction` | How much of the height, from the base up, blocks movement |

When building art lands, replace the block with a `StaticBody2D` holding a
`Sprite2D` (texture through `AssetRegistry`) and the same collision.

## The coastal tileset

`assets/tilesets/coastal/coastal_tileset.tres` has one terrain set
(**Match Corners**) with seven terrains:

| Terrain | From sheet | Blocks movement |
|---|---|---|
| sea | `sand_and_sea.png` | yes |
| beach sand | `sand_and_sea.png` | no |
| pale sand | `stone_and_sand.png`, `sand_and_grass.png` | no |
| stone wall | `stone_and_sand.png` | yes |
| light grass | `sand_and_grass.png` | no |
| dirt | `dirt_and_grass.png` | no |
| dark grass | `dirt_and_grass.png` | no |

Each sheet blends between its own two terrains only: sea meets beach sand,
but beach sand doesn't meet grass. Collision covers only the blocking part
of each shoreline tile (to 4 px), so you can walk right up to the water.

Things to know about the stand-in sheets:
- They're corner-based (terrain lives at each tile's corners), so the tileset
  uses **Match Corners**, not Match Corners and Sides.
- Each sheet is missing the two diagonal tiles (sea in two opposite corners).
  Godot uses the closest match there; avoid painting checkerboards.
- **The sheets don't share colours.** The beach sand (tan) and pale sand
  (cream) are different sands, and the two grasses are different greens,
  so where different sheets meet there will be a hard seam. That's a
  stand-in problem. The artist's sheets should share one sand and one grass.
- The artist's sheets must keep the same layout (same tile in the same
  place). The terrain and collision setup is per tile position, so it then
  carries over with zero edits.

## How to add a named place

1. Add an `Area2D` under `Locations` and attach `location_zone.gd`.
2. Set `location_id` (e.g. `&"old_boat"`), `display_name`, and `size` (the
   rectangle it covers, centred on the node).

The region emits `location_discovered(location_id)` the first time the
player walks in. Nothing listens yet. The journal map (build step 7) will
reveal itself from these, and the save system will remember them.

## How to add a region

1. Duplicate `coastal/` as e.g. `forest/` and rename the scene and script.
2. In the new script, change what the region *does*. In the scene, set
   `region_id` and `bounds`, and point the tile layers at the region's
   tileset (`assets/tilesets/<region>/`).
3. Replace the spawn point and location zones.
4. To play it, set `region_scene` on the `Main` node in
   `scenes/main/main.tscn`.

Travel between regions doesn't exist yet. When it does, `Main` will swap
`region_scene` and pick the spawn point named after where you came from.

## Playing in the old test room

The test room (`scenes/main/test_room.tscn`) is still the playground for
Pip, interactions and the debug keys. Drag it into `region_scene` on the
`Main` node to play there. The smoke tests do exactly that.

## Testing

```
godot --headless --path . res://tests/coastal_town_smoke.tscn
```

Checks the spawn point, camera limits, edge walls, that the painted sea and
the buildings block the player, terrain painting, location discovery (once
only), and the harbour exit.
