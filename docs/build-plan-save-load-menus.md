# Build plan: saving, loading, pause screen and main menu

> **Status: not started.** Work on the `feature/save-load-and-menus` branch.
> Tick the boxes as you go, and push whenever a step's check passes. I'll
> review each push.

You're building this one. I've written this plan; there are no stubs this
time, because most of the work is new files rather than holes in old ones.
Where a piece of Godot is easy to get wrong, the step shows the code.

**What you're making.**
- The game starts on a **title screen**: Continue, New Game, Load, Settings, Quit.
- Pressing **Esc / Start** in the world opens a **pause screen**: Resume,
  Settings, Quit to Title.
- The game **autosaves** at the moments the design doc names, and the player
  can **rest at the inn** to save by choice.
- **Settings** (text size, text speed, reduced sensory, interaction hints)
  are remembered between sessions, separately from save files.

**Order matters.** Saving comes first and the menus come last, because a
menu is only buttons that call save and load. With saving built first, every
button you add later already works the moment you wire it. Each step ends
with something you can run. Don't move on until its check passes.

**Size.** Steps 1–5 are the save system (about a third of the work). Steps
6–10 are the screens. Step 11 is the accessibility pass, step 12 tests and
docs. A step is roughly one sitting.

---

## Decisions to make first

The first four I'd answer a particular way. The last two are yours.

**Where can you save?** The design doc says *autosave at key moments* and
*manual save at inn rest spots: the act of resting and saving*. So the pause
screen has **no Save button**. Saving by choice is something you do in the
world, at the inn, and that's a nice moment, not a menu chore. Autosave
covers everything else, so nobody loses progress for not finding an inn.

**How many slots, and what's in one?** **Three slots, one file each.**
Autosave and inn saves write to the *current* slot. That's how most cozy
games work, and it means a slot is simply "this playthrough". (The
alternative, a separate autosave beside each manual save, doubles the
load-screen UI for little gain.)

**What format?** **JSON**, one file per slot in `user://saves/`. You can open
it in a text editor to see exactly what was saved, which matters a lot when
something loads wrong. Every file carries a `version` number so old saves
can be upgraded when the format changes (step 3).

**Settings go in a separate file.** Text size is a setting of *the person*,
not of a playthrough, and it must apply on the title screen before any save
is loaded. Godot's `ConfigFile` in `user://settings.cfg` does this in a few
lines (step 1).

**Does "Quit to Title" save first?** Yours. I'd say **yes, quietly**. Losing
progress is a punishment, and the game promises no punishment. The catch: it
saves the player's exact spot rather than a "proper" checkpoint. That's fine
for a game with no fail states.

**What does New Game do before you can play?** Yours, and it's mostly a
later system. The design doc says name and pronouns are chosen before
anything else, then appearance. For now, New Game picks a slot and drops you
at the road into town. Step 10 leaves a clearly marked place for the
character creator to slot in.

---

## How the pieces fit

```
core/settings.gd        (exists)  accessibility flags        -> user://settings.cfg
core/game_state.gd      (new)     everything about THIS playthrough
core/save_manager.gd    (new)     GameState <-> user://saves/slot_N.json
scenes/ui/pause_menu    (new)     Esc in the world
scenes/ui/settings_menu (new)     one screen, opened from pause AND title
scenes/ui/title_screen  (new)     the new main scene
scenes/main/main.tscn   (exists)  the world; reads GameState when it starts
```

The one idea that keeps this simple: **GameState is the only thing that gets
saved.** Systems never write files. They put what they need remembered into
GameState (a location discovered, an NPC visit counted, an appearance
chosen), and SaveManager turns GameState into a file and back. When the
journal or NPC arcs arrive later, "making them save" means "store your data
in GameState". Nothing else.

```
  world systems ──write──▶ GameState ◀──restore── SaveManager ◀── slot_1.json
       ▲                       │                       │
       └──────read on start────┘                       └──▶ slot_1.json
```

---

## Step 1: Remember settings between sessions

**Goal:** a warm-up with Godot's file API, on the smallest possible thing.

- [ ] In `core/settings.gd`, add `const PATH := "user://settings.cfg"`.
- [ ] Add `save_settings()`: make a `ConfigFile`, `set_value("accessibility", "text_scale", text_scale)` for each of the four flags, then `save(PATH)`.
- [ ] Add `load_settings()`: `load(PATH)`. If it returns anything but `OK` (first launch: there's no file yet), keep the defaults and return. Otherwise `get_value(section, key, default)` for each flag. Always pass the current value as the default, so a file from an older version with a missing key still works.
- [ ] Call `load_settings()` from `_ready()`. Settings is an autoload, so this runs before any scene.

Don't save on every `changed` signal: a slider dragged across the screen
would write the file sixty times a second. The settings screen saves once
when it closes (step 8).

**Check:** temporarily add `text_scale = 1.5; save_settings()` to `_ready()`,
run once, remove it, run again. The interaction hint should still be big.
Find the file through **Project → Open User Data Folder** and read it.

---

## Step 2: GameState, the thing that gets saved

**Goal:** one autoload that holds everything about the current playthrough.

- [ ] New file `core/game_state.gd`, `extends Node`, registered as the autoload `GameState` (Project Settings → Globals), **after** `Settings` and `AssetRegistry`.
- [ ] Give it the data a save holds today:

```gdscript
var slot := -1                       ## which save slot this playthrough uses
var region_id: StringName = &"coastal"
var player_position := Vector2.ZERO  ## ZERO = "use the region's spawn point"
var discovered: Dictionary = {}      ## region_id -> { location_id: true }
var appearance: Dictionary = {}      ## the player's chosen look
var playtime := 0.0                  ## seconds, for the slot list
```

- [ ] Add `reset()`, which puts every field back to a fresh new game. New Game calls it.
- [ ] Count playtime in `_process(delta)`, but only while a playthrough is running (`slot != -1`) and the game isn't paused.
- [ ] **Move discovery here.** `Region.discovered` (in `scenes/regions/region.gd`) is session-only today. Make `_on_location_entered` read and write `GameState.discovered[region_id]` instead, and delete the region's own dictionary. Everything else about discovery stays the same.

Leave out NPC visit counts, the journal, comfort items and map reveal for
now. Those systems don't exist yet. When each is built, it adds its field
here plus one line in step 3's two functions.

**Check:** run the coastal smoke test
(`godot --headless --path . res://tests/coastal_town_smoke.tscn`). It still
passes, because discovery behaves exactly as before; it just lives elsewhere.

---

## Step 3: SaveManager, GameState to file and back

**Goal:** save a slot, load it back, and list what's in each slot.

- [ ] New file `core/save_manager.gd`, autoload `SaveManager`, after `GameState`.
- [ ] `const SLOT_COUNT := 3`, `const SAVE_DIR := "user://saves/"`, `const VERSION := 1`.
- [ ] `to_dict() -> Dictionary` builds the save from GameState. `from_dict(data)` does the reverse.
- [ ] `save_game(slot) -> bool` and `load_game(slot) -> bool`.
- [ ] `slot_info(slot) -> Dictionary`: what the load screen shows (region, playtime, when saved), or `{}` for an empty slot. Read only the small header, not the whole world.
- [ ] `has_any_save() -> bool` and `most_recent_slot() -> int`, for Continue.
- [ ] `delete_slot(slot)`.

Three things to get right, because each one is a real bug in shipped games:

**JSON only stores text, numbers, lists and dictionaries.** A `Vector2`
becomes the string `"(12, 40)"` and won't come back. Store positions as
`[x, y]` and rebuild with `Vector2(a[0], a[1])`. `StringName` keys come back
as plain `String`s, so convert them with `StringName(key)` on the way in.
Numbers come back as floats; wrap counts in `int()`.

**Write to a temporary file, then rename it over the real one.** If the game
crashes or the power goes out mid-write, you're left with the old save
rather than half a file:

```gdscript
var tmp := path + ".tmp"
var file := FileAccess.open(tmp, FileAccess.WRITE)
if file == null:
	push_warning("SaveManager: can't write %s (%s)" % [tmp, FileAccess.get_open_error()])
	return false
file.store_string(JSON.stringify(data, "\t"))
file.close()
DirAccess.rename_absolute(tmp, path)  # replaces the old save in one step
```

(`DirAccess.make_dir_recursive_absolute(SAVE_DIR)` first, since the folder
won't exist on first launch.)

**Never crash on a bad file.** `JSON.parse_string` returns `null` for
garbage. `load_game` returns `false`, and the load screen shows that slot as
"This save couldn't be read" instead of hiding it, so the player isn't
confused about where their game went. Before overwriting a file you
couldn't read, copy it to `slot_N.broken.json` so it can be rescued.

The file looks like this. `version` and `saved_at` go in every save:

```json
{
	"version": 1,
	"saved_at": 1791654675,
	"playtime": 1834.5,
	"region_id": "coastal",
	"player_position": [1180, 368],
	"discovered": { "coastal": { "tide_pools": true, "inn": true } },
	"appearance": {}
}
```

When the format changes later, bump `VERSION` and add a `_migrate(data)`
step that upgrades old files: "if version is 1, add the journal field,
set version to 2". Old saves keep working.

**Check:** add two temporary debug keys (debug builds only, the same way the
test room does it): one calls `SaveManager.save_game(0)`, the other
`load_game(0)` and prints GameState. Walk into the tide pools, save, quit,
run again, load. The print shows `tide_pools` discovered. Open the JSON in a
text editor and read it.

---

## Step 4: Starting the world from GameState

**Goal:** after a load, you're standing where you saved.

- [ ] In `scenes/main/main.gd`, `_arrive()` currently always uses the spawn point. Make it use `GameState.player_position` when that isn't `Vector2.ZERO`.
- [ ] Apply `GameState.appearance` to the player (`set_appearance` per layer) when it isn't empty.
- [ ] Choose the region from `GameState.region_id`. With one region, a small dictionary `{ &"coastal": preload(...) }` in main.gd is plenty. Don't build a region registry until there's a second region.
- [ ] Before saving, something has to copy the player's live position into GameState. Give SaveManager a signal `about_to_save`. Main connects to it and writes `GameState.player_position = _player.global_position`. Saving then never reaches into the scene tree itself.

**Check:** save at the inn door, quit, run, load. You appear at the inn door,
not the road. Walk around and save again; the JSON's position changes.

---

## Step 5: Autosave

**Goal:** the game saves itself at the moments the design doc lists.

- [ ] `SaveManager.autosave(reason: String)`: if a slot is active, `save_game(GameState.slot)`. The reason is only for the debug print ("autosave: dialogue finished"). It makes testing far easier.
- [ ] Hook the triggers that exist today:
  - **Arriving in a region:** end of `main._arrive()`.
  - **Finishing a conversation:** `Dialogue.finished` (the signal already exists).
  - **A new place discovered:** `Region.location_discovered`. It isn't on the design doc's list, but discovery is progress, and the trigger is free.
  - **Completing a mend:** later, when `MendScreen` gets a `completed` signal. Leave a `# TODO(autosave)` comment there.
- [ ] Throttle it: skip an autosave if the last one was under ~10 seconds ago, so three triggers in a row don't write three files.
- [ ] **A saving indicator.** A small "Saving…" label in a screen corner for about a second. It must be text, not just an icon, and it must not flash or spin under `Settings.reduced_sensory`: show it steadily, then fade.

**Check:** talk to the fisherman, then quit without saving. Load the slot.
The JSON's `saved_at` is from after the conversation.

---

## Step 6: Resting at the inn

**Goal:** the manual save, done as a moment in the world.

- [ ] Add an `Interactable` at the inn door in `coastal_town.tscn` (`prompt_verb = "Rest"`), wired in `coastal_town.gd` like the harbour exit.
- [ ] On interact: `Dialogue.say("", ["You rest for a while by the fire."])`, `await Dialogue.finished`, `SaveManager.save_game(GameState.slot)`, then `Dialogue.say("", ["Your journey is saved."])`.
- [ ] If saving failed, say so plainly ("Your journey couldn't be saved.") rather than pretending.

**Check:** rest at the inn, quit, load. You're at the inn.

---

## Step 7: Pause screen

**Goal:** Esc / Start opens a menu that stops the world.

- [ ] New scene `scenes/ui/pause_menu.tscn`: a `CanvasLayer` with a dimmed full-screen `ColorRect` behind a centred `VBoxContainer` holding three `Button`s: Resume, Settings, Quit to Title. Add it to `main.tscn` under `UI`, not as an autoload: there is nothing to pause on the title screen.
- [ ] **process_mode.** The `CanvasLayer` is *Always*, so it can hear Esc while the world runs. Its menu panel is *When Paused*. The dialogue box README explains why that difference matters.
- [ ] Open on the `pause` action (already bound to Esc and Start): `get_tree().paused = true`, show, then `$Resume.grab_focus()`. **Without `grab_focus()` a controller or keyboard player can't press anything.**
- [ ] **Don't open over another paused screen.** If `get_tree().paused` is already true, the dialogue box or mend screen owns the pause, so ignore the key. That's one `if` line, and it saves a whole class of "I unpaused the world while the dialogue was still open" bugs.
- [ ] Esc / Start / the `ui_cancel` action (B on a controller) while open = Resume.
- [ ] Quit to Title: autosave (if you chose yes above), `get_tree().paused = false`, then `get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")`. **Unpause before changing scene,** or the title screen arrives frozen.
- [ ] Settings opens the step 8 screen on top. Until step 8 exists, leave the button disabled.

**Check:** walk, press Esc. Everything stops, including Pip's bob and the
player's walk animation. Arrow keys move between buttons, Enter presses,
Esc resumes. Talk to the fisherman and press Esc mid-line: nothing happens.

---

## Step 8: Settings screen

**Goal:** one settings screen, opened from both the pause screen and the title screen.

- [ ] New scene `scenes/ui/settings_menu.tscn` (`process_mode` *Always*, since it opens in both a paused game and an unpaused title screen).
- [ ] One row per setting:
  - Text size: `HSlider`, 0.75–2.0, step 0.25
  - Text speed: `HSlider`, 0.5–5.0
  - Reduced sensory: `CheckButton`
  - Interaction hints: `CheckButton`
  
  Each control sets the `Settings` field directly, so text resizes live as the slider moves. That is the best possible preview.
- [ ] Each row has a short, plain description under it ("Softens flashing and pulsing, including Pip's glow."). People can't choose a setting they don't understand.
- [ ] A Back button, and `ui_cancel` = Back. On close: `Settings.save_settings()`, hide, and give focus back to the button that opened it.
- [ ] The screen's own text uses `BASE_FONT_SIZE × Settings.text_scale`, like the dialogue box, so the settings screen is readable at the size the player needs.
- [ ] Leave a visible "Controls: coming soon" row. Remappable controls are required by the design doc and deserve their own plan; don't build them inside this one.

**Check:** from the pause screen, drag text size to 2.0. The menu text grows
as you drag. Back, quit the game, run again: the title screen text is
already big.

---

## Step 9: Title screen

**Goal:** the game starts on a menu instead of in the world.

- [ ] New scene `scenes/ui/title_screen.tscn` (a `Control`): the game's name, plus Continue, New Game, Load, Settings, Quit.
- [ ] Make it the main scene: **Project Settings → Application → Run → Main Scene**.
- [ ] **Continue** is visible only if `SaveManager.has_any_save()`. It loads `most_recent_slot()` and changes scene to `main.tscn`. When it's visible, it gets focus first, because that's what returning players want.
- [ ] **Load** opens a slot list: three rows showing region name, playtime as hours and minutes, and how long ago it was saved. Empty slots say "Empty". Unreadable slots say so.
- [ ] **Delete** on a slot row needs a confirmation that names the slot ("Delete Slot 2: Coastal Town, 1h 12m?"), with the focus starting on **No**.
- [ ] **Quit** is `get_tree().quit()`. Hide it on platforms where quitting isn't a thing; on Steam desktop it stays.
- [ ] Title-screen art is a placeholder for now: flat background, text logo.

**The smoke tests load `main.tscn` directly,** not the main scene, so
changing the main scene doesn't break them. Running main.tscn on its own (F6
in the editor) needs to keep working for quick testing too: if GameState has
no slot, main.gd should act like a fresh new game without saving.

**Check:** run the game. The title shows. With no saves, Continue is hidden
and New Game has focus. The whole screen works with the mouse alone, and
with the keyboard alone.

---

## Step 10: New game

**Goal:** starting a fresh playthrough in a chosen slot.

- [ ] New Game opens the same slot list as Load, in "choose a slot" mode. Choosing an occupied slot asks before overwriting it.
- [ ] Then `GameState.reset()`, `GameState.slot = chosen`, and change scene to `main.tscn`. The first autosave (arriving in the region) creates the file.
- [ ] Leave the marked spot for the character creator:

```gdscript
# TODO(character-creation): name & pronouns, then appearance, go here,
# before the world loads (GDD: "chosen at game start, before anything else").
```

**Check:** New Game into slot 2, walk somewhere, quit to title. The Load
list shows slot 2 with a playtime of a few seconds. Continue puts you back.

---

## Step 11: Accessibility pass

Walk the whole flow (title → new game → pause → settings → quit → continue)
three times:

- [ ] **Mouse only.** Every button can be clicked; nothing needs a key.
- [ ] **Keyboard only.** Focus starts somewhere on every screen, arrows move it, Enter presses, Esc goes back.
- [ ] **Controller only**, if you have one. Same as keyboard, with A and B.
- [ ] **Focus is visible.** The focused button must look different, and not by colour alone: add an outline or a "›" marker. This needs a `Theme` with a `focus` StyleBox; set it once on the title screen and the pause and settings screens can share it.
- [ ] **Text size 2.0.** Nothing overflows or clips at the biggest setting. Containers, not fixed positions, make this work.
- [ ] **Nothing is timed.** No menu closes itself, and the saving indicator is information only. Missing it costs nothing.
- [ ] **Reduced sensory:** the saving indicator doesn't pulse, and menus don't slide in.

---

## Step 12: Tests and docs

- [ ] `tests/save_smoke.gd`: save → change GameState → load → fields match. It should also cover a corrupt file (write garbage, `load_game` returns false, nothing crashes) and the Vector2 round trip. **Point it at a test-only folder** (give SaveManager a `save_dir` you can override) so running the tests never touches your real saves.
- [ ] `tests/menu_smoke.gd`: open the title screen, check focus is on New Game, press it through to the world, open pause, resume.
- [ ] Add a SaveManager and GameState section to `core/README.md`: **"How to make a system save: add a field to GameState, add one line each to `to_dict` and `from_dict`."** That's the reusable recipe CLAUDE.md asks for.
- [ ] Add the pause, settings and title screens to `scenes/ui/README.md`.
- [ ] Update the Controls table in the root `README.md` (Pause is no longer reserved).
- [ ] Change this plan's status line to "built".

---

## Things that commonly go wrong

| Symptom | Usually |
|---|---|
| Esc does nothing in the world | The pause menu's `CanvasLayer` is *When Paused* instead of *Always*, so it can't hear the key while the world runs |
| Can't press any button with keyboard/controller | No `grab_focus()` when the screen opens |
| Title screen frozen after Quit to Title | Changed scene before `get_tree().paused = false` |
| Loaded game puts you at the spawn, not where you saved | Position stored as a `Vector2` and came back as a string; store `[x, y]` |
| Discoveries don't survive a load | `region_id` key came back as `String` but is looked up as `StringName` (or the other way round) |
| Tests wipe your saves | The tests use the real `user://saves/`; give them their own folder |

## Where to ask for help

Push whenever a step's check passes, even mid-plan, and tell me which step.
If a check fails and you can't see why, push anyway and tell me what you
expected and what happened. That's faster than describing the code.
