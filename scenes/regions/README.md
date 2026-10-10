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
  mock_guide.gd           the map mock laid over the scene as a tracing guide
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
| `MockGuide` | The region's map mock at 3× (`assets/map/map_<region>.png`). In the editor it floats faintly over your tiles so you can trace it. In game it sits underneath everything, so unpainted ground still shows the mock |
| `Ground` | Base terrain: sea, sand, grass. Sea has collision |
| `Paths` | Paths and ground detail painted over the base |
| `Obstacles` | Walls, cliff faces, rocks. Stone has collision |
| `Objects` | Buildings, trees, NPCs, signs, interactables. Y-sorted, so the player walks behind them |
| `AbovePlayer` | Roofs, treetops, the lighthouse top: anything drawn over the player. No collision |
| `SpawnPoints/default` | Where the player arrives |
| `Locations` | One `LocationZone` per named place |

The region's root is y-sorted, and so is `Main`, so the player, Pip and
everything under `Objects` sort together by their feet. Tile layers sit
underneath (negative `z_index`), except `AbovePlayer`, which sits on top.

## How to paint the town

1. Open `scenes/regions/coastal/coastal_town.tscn`.
2. Select the `Ground` layer and open the **TileMap** panel → **Terrains**
   tab. Pick terrain set 0, then a terrain (sea, beach sand, ...). Paint with
   the **Connect** mode and Godot picks the right edge and corner tiles.
3. Trace the mock: sea where the mock is sea, beach sand along the shore,
   grass inland. Then do paths on `Paths` and cliffs on `Obstacles`.
4. Press F5 and walk it. Sea and stone already block movement.
5. When the whole region is painted, untick `show_in_game` on `MockGuide`
   (or delete the node).

The map is 1440×810 pixels (90 × ~51 tiles), the mock at 3×, which puts the
16×32 player at about the scale the mock's buildings were drawn at.

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
   `region_id` and `bounds`, point `MockGuide` at the region's mock and the
   tile layers at the region's tileset (`assets/tilesets/<region>/`).
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

Checks the spawn point, camera limits, edge walls, terrain painting with sea
collision, location discovery (once only), and the harbour exit.
