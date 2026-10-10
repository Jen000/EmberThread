# Build plan: saving, loading, title screen, pause screen and cutscene skip

> **Status: not started.** Work on the `feature/save-load-and-menus` branch.
> Tick the boxes as you go, and push whenever a step's check passes. I'll
> review each push.

You're building this one. I've written this plan; there are no stubs this
time, because most of the work is new files rather than holes in old ones.
Where a piece of Godot is easy to get wrong, the step shows the code.

**What you're making.**
- The game opens on a **title screen**: the title art and "Press any button".
- Any button leads to the **slot screen**: three save slots. Pick one with a
  save to continue it, or an empty one to start a new game.
- **Each slot is one player.** It holds their progress *and their settings*,
  so two people sharing a computer each keep their own text size and the rest.
- A **new game** is a brand new player: fresh progress, then the opening
  cutscene. Cutscenes can be skipped by **pressing E twice**.
- In the world, **Esc / Start** opens the **pause screen**: Resume, Save,
  Load, Settings, Quit to Title.
- The game **autosaves** at key moments, shown by a **save icon in the lower
  right corner**. **Quitting never saves.** Only autosave and the pause
  screen's Save write progress.

**Order matters.** Saving comes first and the screens come last, because a
screen is only buttons that call save and load. With saving built first,
every button you add later already works the moment you wire it. Each step
ends with something you can run. Don't move on until its check passes.

**Size.** Steps 1–6 are the save system (about a third of the work). Step 7
is optional. Steps 8–12 are the screens, step 13 the cutscene skip, step 14
the accessibility pass and step 15 tests and docs. A step is roughly one
sitting.

---

## Decisions

All of these are decided. They're here so the reasons stay with the plan.

**When does the game save?**
- **Autosave** at key moments: arriving in a region, finishing a
  conversation, discovering a place, and (once mending exists) completing a
  mend. A **save icon** shows in the lower right corner while it happens.
- **Save** on the pause screen, any time.
- **Quitting never saves**, whether to the title or to the desktop. Because
  of that, quitting asks first: "Quit to the title? Anything since your last
  save will be lost." The slot screen shows how long ago each slot was saved,
  so nobody is surprised.

**Three slots, and a slot is a player.** Each slot holds that player's
progress and their settings. Autosave and the pause screen's Save both
write to the slot you're playing.

**Settings belong to the slot.** Text size, text speed, reduced sensory and
interaction hints live with each slot, so two people on one computer each
get their own. They're kept in a small file beside the save,
`slot_N.settings.cfg`, rather than inside it. That way changing a setting is
remembered straight away, even though quitting doesn't save progress.
Settings aren't progress.

**Which settings do the title and slot screens use?** No slot is chosen yet
on those screens. They use the **last player's settings** (a copy kept in
`user://settings.cfg`), which is usually the right person. In case it isn't,
the slot screen has its own **Settings** button, so someone who needs bigger
text can make the slot screen readable before choosing. Choosing a slot
applies that slot's settings straight away.

**A new game is a new player.** It starts from fresh progress and takes its
settings from the slot screen as they are at that moment, so whatever the
player just set up carries in. Then the opening cutscene plays (a
placeholder for now), then the world.

**Skipping a cutscene takes two presses.** The first press of E (Y on a
controller) shows "Press E again to skip". The second press skips. Two
presses rather than a hold, because holding a button is hard for some
players. Neither press has a time limit.

**Format: JSON**, one file per slot in `user://saves/`. You can open it in a
text editor to see exactly what was saved, which matters a lot when
something loads wrong. Every file carries a `version` number so old saves
can be upgraded when the format changes (step 4).

---

## How the pieces fit

```
core/settings.gd        (exists)  the settings in use right now
core/game_state.gd      (new)     everything about THIS playthrough
core/save_manager.gd    (new)     GameState <-> user://saves/slot_N.json
                                  slot settings <-> user://saves/slot_N.settings.cfg
scenes/ui/save_icon     (new)     lower-right icon while saving
scenes/ui/pause_menu    (new)     Esc in the world
scenes/ui/slot_list     (new)     the three slots: pause Load and the slot screen
scenes/ui/settings_menu (new)     opened from the pause screen AND the slot screen
scenes/ui/title_screen  (new)     the new main scene: art + "press any button"
scenes/ui/slot_screen   (new)     choose a slot: continue or new game
scenes/ui/cutscene      (new)     plays a cutscene, handles the two-press skip
scenes/main/main.tscn   (exists)  the world; reads GameState when it starts
```

The one idea that keeps this simple: **GameState is the only thing that gets
saved as progress.** Systems never write files. They put what they need
remembered into GameState (a location discovered, an NPC visit counted, an
appearance chosen), and SaveManager turns GameState into a file and back.
When the journal or NPC arcs arrive later, "making them save" means "store
your data in GameState". Nothing else.

```
  world systems ──write──▶ GameState ◀──restore── SaveManager ◀── slot_1.json
       ▲                       │                       │
       └──────read on start────┘                       └──▶ slot_1.json
```

Settings follow the same shape on a smaller scale: `Settings` holds what's
in use, and SaveManager reads and writes the slot's settings file.

---

## Step 1: Settings can save to and load from a file

**Goal:** a warm-up with Godot's file API, on the smallest possible thing.

- [ ] In `core/settings.gd`, add `save_to(path: String)`: make a `ConfigFile`, `set_value("accessibility", "text_scale", text_scale)` for each of the four flags, then `save(path)`.
- [ ] Add `load_from(path: String) -> bool`: `load(path)`. If it returns anything but `OK` (no file yet), keep the current values and return `false`. Otherwise `get_value(section, key, default)` for each flag. Always pass the current value as the default, so a file from an older version with a missing key still works.
- [ ] Add `reset()`, which puts all four back to their defaults. A new player who has never touched the settings gets these.
- [ ] Add `const LAST_USED := "user://settings.cfg"`, and call `load_from(LAST_USED)` in `_ready()`. Settings is an autoload, so this runs before any scene, which is what makes the title screen use the last player's settings.

Taking a path, rather than one fixed file, is what makes per-slot settings
easy later: the same two functions read and write a slot's settings file.

Don't save on every `changed` signal: a slider dragged across the screen
would write the file sixty times a second. The settings screen saves once
when it closes (step 10).

**Check:** temporarily add `text_scale = 1.5; save_to(LAST_USED)` to
`_ready()`, run once, remove it, run again. The interaction hint should still
be big. Find the file through **Project → Open User Data Folder** and read it.

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
var playtime := 0.0                  ## seconds, for the slot screen
```

- [ ] Add `reset()`, which puts every field back to a fresh new game (except `slot`, which New Game sets).
- [ ] Count playtime in `_process(delta)`, but only while a playthrough is running (`slot != -1`) and the game isn't paused.
- [ ] **Move discovery here.** `Region.discovered` (in `scenes/regions/region.gd`) is session-only today. Make `_on_location_entered` read and write `GameState.discovered[region_id]` instead, and delete the region's own dictionary. Everything else about discovery stays the same.

Leave out NPC visit counts, the journal, comfort items and map reveal for
now. Those systems don't exist yet. When each is built, it adds its field
here plus one line in step 4's two functions.

**Check:** run the coastal smoke test
(`godot --headless --path . res://tests/coastal_town_smoke.tscn`). It still
passes, because discovery behaves exactly as before; it just lives elsewhere.

---

## Step 3: SaveManager, the slot files

**Goal:** know where each slot's files live, and what's in each slot.

- [ ] New file `core/save_manager.gd`, autoload `SaveManager`, after `GameState`.
- [ ] `const SLOT_COUNT := 3`, `const VERSION := 1`, and `var save_dir := "user://saves/"`. It's a `var` so the tests can point it at their own folder (step 15) and never touch your real saves.
- [ ] Two path helpers: `save_path(slot)` → `save_dir + "slot_%d.json"`, and `settings_path(slot)` → `save_dir + "slot_%d.settings.cfg"`.
- [ ] `slot_info(slot) -> Dictionary`: what the slot screen shows (region, playtime, when saved), or `{}` for an empty slot, or `{ "broken": true }` for a file that can't be read.
- [ ] `delete_slot(slot)`: removes **both** files. Deleting a slot removes that player completely, settings included.
- [ ] `save_settings(slot)`: makes sure the saves folder exists (`DirAccess.make_dir_recursive_absolute(save_dir)`), then `Settings.save_to(settings_path(slot))`. **Always save a slot's settings through this, never `Settings.save_to` directly.** On a fresh computer the folder doesn't exist yet, and `ConfigFile.save` fails silently without it, so the settings would quietly never be written.

**Check:** a temporary debug print of `slot_info(0)` says the slot is empty.

---

## Step 4: SaveManager, saving and loading progress

**Goal:** save a slot, load it back.

- [ ] `to_dict() -> Dictionary` builds the save from GameState. `from_dict(data)` does the reverse.
- [ ] `save_game(slot) -> bool` and `load_game(slot) -> bool`.
- [ ] Loading a slot also loads its settings: `Settings.load_from(settings_path(slot))`, then `Settings.save_to(Settings.LAST_USED)`, so the next launch opens with this player's settings.

Four things to get right, because each one is a real bug in shipped games:

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

(`DirAccess.make_dir_recursive_absolute(save_dir)` first, since the folder
won't exist on first launch.)

**Never crash on a bad file.** `JSON.parse_string` returns `null` for
garbage. `load_game` returns `false`, and the slot screen shows that slot as
"This save couldn't be read" instead of hiding it, so the player isn't
confused about where their game went. Before overwriting a file you
couldn't read, copy it to `slot_N.broken.json` so it can be rescued.

**Parse first, then change GameState.** `load_game` reads and checks the
whole file before it touches GameState. If anything is wrong, it returns
`false` with GameState exactly as it was. That's what lets the pause
screen's Load fail without breaking the game you're playing (step 9).

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
test room does it): one sets `GameState.slot = 0` and calls `save_game(0)`,
the other calls `load_game(0)` and prints GameState. Walk into the tide
pools, save, quit, run again, load. The print shows `tide_pools` discovered.
Open the JSON in a text editor and read it.

---

## Step 5: Starting the world from GameState

**Goal:** after a load, you're standing where you saved.

Two files change: `core/save_manager.gd` (one signal) and
`scenes/main/main.gd` (three small additions). Nothing else.

### The idea

Two things have to happen, one on each side of the save:

- **When saving:** GameState has to know where the player is *right now*. The
  player is a node in the world; GameState is not. So just before a save,
  SaveManager announces "I'm about to save!" and main.gd, which knows where
  the player is, copies the position into GameState.
- **When the world starts:** main.gd already puts the player at the spawn
  point. It now checks GameState first: if there's a saved position, use
  that instead.

The announcement is a **signal**: a message a node sends out without knowing
who's listening. SaveManager sends it; main.gd listens.

### 1. In `core/save_manager.gd`: announce saves

- [ ] Near the top, under the `## Save slots...` comment, declare the signal:

```gdscript
## Sent just before a save is written, so the world can put its live
## state (like where the player is standing) into GameState first.
signal about_to_save
```

- [ ] Make it the **first line** inside `save_game`, before anything else:

```gdscript
func save_game(slot: int) -> bool:
	about_to_save.emit()
	DirAccess.make_dir_recursive_absolute(save_dir)
	# ...the rest stays the same
```

It has to come first so GameState is up to date before `to_dict()` reads it.

### 2. In `scenes/main/main.gd`: listen for it

- [ ] At the very top of `_ready()`, connect to the signal. "Connect" means "when this signal is sent, run this function":

```gdscript
func _ready() -> void:
	SaveManager.about_to_save.connect(_remember_position)
	# ...the rest of _ready stays the same
```

- [ ] Add the function it runs, at the bottom of the file:

```gdscript
## Just before a save, copy where the player is standing into GameState.
func _remember_position() -> void:
	GameState.player_position = _player.global_position
```

### 3. In `scenes/main/main.gd`: arrive at the saved position

- [ ] In `_arrive()`, find this line:

```gdscript
	_player.global_position = target.get_spawn_position()
```

and replace it with:

```gdscript
	if GameState.player_position != Vector2.ZERO:
		_player.global_position = GameState.player_position
	else:
		_player.global_position = target.get_spawn_position()
```

`Vector2.ZERO` is GameState's way of saying "no saved position" (a new game
starts with it), so a new game still begins on the road.

### 4. Debug keys to test it

- [ ] Add these at the bottom of `main.gd`. F2 saves, F3 loads. They only work in debug builds (when you run from the editor), so players never see them:

```gdscript
## Debug keys (debug builds only): F2 saves to slot 1, F3 loads it.
func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_F2:
		GameState.slot = 0
		print("saved: ", SaveManager.save_game(0))
	elif key.physical_keycode == KEY_F3:
		if SaveManager.load_game(0):
			get_tree().reload_current_scene()
```

`load_game` only fills GameState. `reload_current_scene()` restarts the world,
so `_arrive()` runs again and reads the loaded position. That's the same
thing the pause screen's Load will do in step 9.

**Check:**
1. Run the game (F5 in the Godot editor).
2. Walk to the inn door. Press **F2**. The Output panel says `saved: true`.
3. Walk somewhere else, like the harbour. Press **F3**. You jump back to the inn door.
4. Close the game, run it again, press **F3**. You're at the inn door again: it came from the file.

**Left for later, on purpose:**
- *Appearance:* nothing chooses an appearance until the character creator exists, so there's nothing to restore yet.
- *Choosing the region from `GameState.region_id`:* there's only one region. Add it when the second region is built.

---

## Step 6: Autosave and the save icon

**Goal:** the game saves itself at key moments, and shows it.

- [ ] `SaveManager.autosave(reason: String)`: if a slot is active, `save_game(GameState.slot)`. The reason is only for the debug print ("autosave: dialogue finished"). It makes testing far easier.
- [ ] Hook the triggers that exist today:
  - **Arriving in a region:** end of `main._arrive()`, but not when arriving *from* a load (that would save the moment you loaded).
  - **Finishing a conversation:** `Dialogue.finished` (the signal already exists).
  - **A new place discovered:** `Region.location_discovered`.
  - **Completing a mend:** later, when `MendScreen` gets a `completed` signal. Leave a `# TODO(autosave)` comment there.
- [ ] Throttle it: skip an autosave if the last one was under ~10 seconds ago, so three triggers in a row don't write three files.
- [ ] **The save icon.** New scene `scenes/ui/save_icon.tscn`: a small icon anchored to the **lower right corner**, in `main.tscn` under `UI`. SaveManager emits `saving` and `saved`; the icon shows on the first and fades out about a second after the second.
  - Its art goes through `AssetRegistry` like everything else: a block placeholder now (`ui_save_icon.png`, 16×16, magenta-marked per the art pipeline), the artist's icon later with no code change.
  - The icon must read by **shape**, not colour alone.
  - Under `Settings.reduced_sensory` it doesn't spin or pulse. It appears, stays steady, then fades.
  - It's information only. Missing it costs nothing, so it never needs dismissing.
- [ ] The pause screen's Save (step 8) shows the same icon, so saving always looks the same.

**Check:** talk to the fisherman. The icon appears in the corner after the
conversation. Quit without saving and load the slot: the JSON's `saved_at`
is from after the conversation.

---

## Step 7 (optional): A save point at the inn

**Goal:** a save that happens as a moment in the world, alongside autosave
and the pause screen. Skip it if you'd rather not; nothing later depends on it.

- [ ] Add an `Interactable` at the inn door in `coastal_town.tscn` (`prompt_verb = "Rest"`), wired in `coastal_town.gd` like the harbour exit.
- [ ] On interact: `Dialogue.say("", ["You rest for a while by the fire."])`, `await Dialogue.finished`, `SaveManager.save_game(GameState.slot)`, then `Dialogue.say("", ["Your journey is saved."])`.
- [ ] If saving failed, say so plainly ("Your journey couldn't be saved.") rather than pretending.

**Check:** rest at the inn, quit, load. You're at the inn.

---

## Step 8: Pause screen, with Save

**Goal:** Esc / Start opens a menu that stops the world, and Save works from it.

- [ ] New scene `scenes/ui/pause_menu.tscn`: a `CanvasLayer` with a dimmed full-screen `ColorRect` behind a centred `VBoxContainer` holding five `Button`s: Resume, Save, Load, Settings, Quit to Title. Add it to `main.tscn` under `UI`, not as an autoload: there's nothing to pause outside the world.
- [ ] **process_mode.** The `CanvasLayer` is *Always*, so it can hear Esc while the world runs. Its menu panel is *When Paused*. The dialogue box README explains why that difference matters.
- [ ] Open on the `pause` action (already bound to Esc and Start): `get_tree().paused = true`, show, then `$Resume.grab_focus()`. **Without `grab_focus()` a controller or keyboard player can't press anything.**
- [ ] **Don't open over another paused screen.** If `get_tree().paused` is already true, the dialogue box, mend screen or a cutscene owns the pause, so ignore the key. That's one `if` line, and it saves a whole class of "I unpaused the world while the dialogue was still open" bugs.
- [ ] Esc / Start / the `ui_cancel` action (B on a controller) while open = Resume.
- [ ] **Save** calls `SaveManager.save_game(GameState.slot)`. The save icon shows, and a label inside the menu says "Saved." or "Couldn't save. Your last save is still safe." The label stays until the menu closes; don't make it a message that vanishes on a timer, because some players need time to read it.
- [ ] Disable Save when there's no slot (main.tscn run on its own).
- [ ] **Quit to Title** asks first: "Quit to the title? Anything since your last save will be lost.", with the focus starting on **No**. On yes: `get_tree().paused = false`, then `get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")`. It doesn't save. **Unpause before changing scene,** or the title screen arrives frozen.
- [ ] Leave Load and Settings disabled for now. Steps 9 and 10 wire them up.

**Check:** walk, press Esc. Everything stops, including Pip's bob and the
player's walk animation. Arrow keys move between buttons, Enter presses,
Esc resumes. Press Save, see the icon and "Saved.". Walk somewhere else,
Quit to Title, then load the slot: you're where you pressed Save, not where
you quit. Talk to the fisherman and press Esc mid-line: nothing happens.

---

## Step 9: Slot list, and Load from the pause screen

**Goal:** one reusable list of the three slots, used by the pause screen's
Load now and the slot screen later.

- [ ] New scene `scenes/ui/slot_list.tscn` (`process_mode` *Always*, because it opens over a paused game and over the unpaused slot screen). Three rows, one per slot, built from `SaveManager.slot_info()`: region name, playtime as hours and minutes, and how long ago it was saved. Empty slots say "Empty". Unreadable slots say "This save couldn't be read".
- [ ] It has two modes, set when it opens. **Load** disables empty slots. **Play** (for the slot screen) allows every slot, and labels empty ones "New Game". It emits `slot_chosen(slot)` or `cancelled`. It doesn't load anything itself, so it stays reusable.
- [ ] Focus goes to the current slot when opened from the pause screen, otherwise the most recently saved one. Back and `ui_cancel` close it and return focus to the button that opened it.
- [ ] **Load from the pause screen** opens it in load mode. Choosing a slot asks first: "Load Slot 2? Anything since your last save will be lost.", with the focus starting on **No**. On yes: `SaveManager.load_game(slot)`, `get_tree().paused = false`, then `get_tree().reload_current_scene()`. Main starts again from the freshly loaded GameState (step 5 already does the rest). Loading another player's slot this way also switches to their settings.
- [ ] If the load fails, stay in the game and say so in the slot list ("Slot 2 couldn't be read."). The current playthrough is untouched, because `load_game` only changes GameState after the file has parsed successfully (step 4).

**Check:** save in slot 1 at the inn door. Walk to the harbour, press Esc,
Load, slot 1, yes. You're back at the inn door. Do it again and pick No:
nothing changes. Write garbage into the slot's JSON, then try to load it:
the game keeps running and tells you.

---

## Step 10: Settings screen

**Goal:** one settings screen, opened from both the pause screen and the slot screen.

- [ ] New scene `scenes/ui/settings_menu.tscn` (`process_mode` *Always*, since it opens in both a paused game and an unpaused slot screen).
- [ ] One row per setting:
  - Text size: `HSlider`, 0.75–2.0, step 0.25
  - Text speed: `HSlider`, 0.5–5.0
  - Reduced sensory: `CheckButton`
  - Interaction hints: `CheckButton`

  Each control sets the `Settings` field directly, so text resizes live as the slider moves. That's the best possible preview.
- [ ] Each row has a short, plain description under it ("Softens flashing and pulsing, including Pip's glow."). People can't choose a setting they don't understand.
- [ ] A Back button, and `ui_cancel` = Back. On close, save the settings, then hide and give focus back to the button that opened it:
  - **In the world** (a slot is active): `SaveManager.save_settings(GameState.slot)`. This is remembered even though quitting doesn't save progress.
  - **Always** also `Settings.save_to(Settings.LAST_USED)`, so the title screen opens with these settings next time.
- [ ] The screen's own text uses `BASE_FONT_SIZE × Settings.text_scale`, like the dialogue box, so the settings screen is readable at the size the player needs.
- [ ] Leave a visible "Controls: coming soon" row. Remappable controls are required by the design doc and deserve their own plan; don't build them inside this one.
- [ ] Enable the pause screen's Settings button.

**Check:** from the pause screen, drag text size to 2.0. The menu text grows
as you drag. Back, Quit to Title (don't save), and load the slot again: the
text is still big. Load a different slot: its text is its own size.

---

## Step 11: Title screen

**Goal:** the game opens on the title art and waits for any button.

- [ ] New scene `scenes/ui/title_screen.tscn` (a `Control`): the title art filling the screen, and "Press any button" near the bottom. Nothing else.
- [ ] The title art goes through `AssetRegistry`: a 480×270 block placeholder now (`ui_title.png`, magenta-marked and labelled), the artist's art later with no code change.
- [ ] Make it the main scene: **Project Settings → Application → Run → Main Scene**.
- [ ] **Any button means any:** a key, a mouse click, or a controller button. In `_unhandled_input`, accept `InputEventKey`, `InputEventMouseButton` and `InputEventJoypadButton`, but only when `event.pressed` and not an echo. Ignore mouse movement and stick drift (`InputEventMouseMotion`, `InputEventJoypadMotion`), or the screen skips itself.
- [ ] Then `change_scene_to_file("res://scenes/ui/slot_screen.tscn")`.
- [ ] The prompt may breathe gently (slow fade in and out), but under `Settings.reduced_sensory` it's steady. It never blinks, and the screen never moves on by itself.

**Check:** run the game. The title shows and waits. Each of a key, a click
and a controller button moves on. Wiggling the mouse doesn't.

---

## Step 12: Slot screen and new game

**Goal:** choose a slot: continue a player, or start a new one.

- [ ] New scene `scenes/ui/slot_screen.tscn`: the step 9 slot list in **play** mode, plus Settings and Quit buttons.
- [ ] **A slot with a save:** `SaveManager.load_game(slot)`, then change scene to `main.tscn`. The player's settings apply as it loads.
- [ ] **An empty slot (New Game):** a brand new player.
  1. `GameState.reset()`, then `GameState.slot = chosen`.
  2. The new player's settings are the ones on screen right now: `SaveManager.save_settings(chosen)`.
  3. Leave the marked spot for the character creator:

     ```gdscript
     # TODO(character-creation): name & pronouns, then appearance, go here,
     # before the world loads (GDD: "chosen at game start, before anything else").
     ```

  4. Play the opening cutscene (step 13), then change scene to `main.tscn`. The first autosave (arriving in the region) creates the save file.
- [ ] **Starting over in a used slot:** each occupied slot also has **Start over**, with a confirmation that names it ("Erase Slot 2: Coastal Town, 1h 12m, and start a new game?"), focus on **No**. On yes: `delete_slot`, then New Game as above. A separate **Delete** (same confirmation, without starting) lets someone clear a slot they're done with.
- [ ] **Settings** opens the step 10 screen. With no slot chosen, it changes the slot screen's own settings (and `LAST_USED`), so a second player can make the screen readable before choosing.
- [ ] **Quit** is `get_tree().quit()`. It doesn't need a "you'll lose progress" question here, since nothing is being played.
- [ ] Focus starts on the most recently saved slot, or Slot 1 if there are none.

**Check:** run the game, press a button, choose empty Slot 2. You arrive in
the world (after the cutscene, once step 13 exists). Walk somewhere, wait
for an autosave, Quit to Title. Slot 2 now shows Coastal Town and a few
seconds of playtime. Choose it: you're back where it autosaved.

---

## Step 13: The opening cutscene and two-press skip

**Goal:** a cutscene component that any cutscene can use, with the skip
built in, and a placeholder opening for New Game.

- [ ] New scene `scenes/ui/cutscene.tscn` (a `CanvasLayer`, `process_mode` *Always*). For now a cutscene is a list of text cards over a plain background, which is enough to build and test the skip. The real opening (Moss, the road, finding Pip) and the memory cutscenes replace the cards later, and keep the skip.
- [ ] `play(cards: Array) -> void`, and a `finished` signal that fires whether the cutscene ended or was skipped. Callers just `await cutscene.finished`.
- [ ] Each card waits for the player to move on (Space / Enter / click, like dialogue), never for a timer. Cards that move on by themselves are a reading-speed problem.
- [ ] **The two-press skip**, on its own action (see below):
  1. First press: show "Press E again to skip" in a corner, using the key the action is actually bound to, not a typed "E" (the interaction hint already does this). The cutscene keeps playing.
  2. Second press: skip to the end and emit `finished`.

  **Use a key that isn't also "next card".** If Space advances cards and also counts as a skip press, a player reading quickly will skip by accident. Advance on `ui_accept` (Enter / click), and give skip its own binding: an action named `skip_cutscene` on E and the controller's Y. The two-press rule then catches the rest.
- [ ] The prompt stays until the cutscene ends. There's no time limit on the second press. Pressing Esc / B while the prompt shows hides it again (changed my mind).
- [ ] New Game plays a three-card placeholder, e.g. "On the road to the coast…" and so on, then loads the world.

**Check:** New Game. Press E once: the prompt appears and the cards carry
on. Press E again: you're in the world. New Game again, read through without
pressing E: the cards play to the end and the world loads.

---

## Step 14: Accessibility pass

Walk the whole flow (title → slot screen → new game → cutscene → pause →
save → load → settings → quit to title → continue) three times:

- [ ] **Mouse only.** Everything can be clicked; nothing needs a key. (Skipping with the mouse: add a small "Skip" button that appears with the prompt, which also needs two clicks.)
- [ ] **Keyboard only.** Focus starts somewhere on every screen, arrows move it, Enter presses, Esc goes back.
- [ ] **Controller only**, if you have one. Same as keyboard, with A and B.
- [ ] **Focus is visible.** The focused button must look different, and not by colour alone: add an outline or a "›" marker. This needs a `Theme` with a `focus` StyleBox; set it once and every screen can share it.
- [ ] **Text size 2.0.** Nothing overflows or clips at the biggest setting. Containers, not fixed positions, make this work.
- [ ] **Two players.** Slot 1 at text size 2.0, Slot 2 at 1.0. Switching between them changes the text each time, and the title screen opens at the size of whoever played last.
- [ ] **Nothing is timed.** No screen moves on by itself, the "Saved." label stays until you leave, the skip prompt has no time limit, and the save icon is information only.
- [ ] **Reduced sensory:** the save icon doesn't spin, the title prompt doesn't breathe, and menus don't slide in.

---

## Step 15: Tests and docs

- [ ] `tests/save_smoke.gd`: save → change GameState → load → fields match. Also a corrupt file (write garbage; `load_game` returns false; nothing crashes), the Vector2 round trip, and per-slot settings (slot 0 at 2.0, slot 1 at 1.0; loading each applies its own). **Set `SaveManager.save_dir` to a test folder first** so the tests never touch your real saves.
- [ ] `tests/menu_smoke.gd`: title → any button → slot screen focus → New Game → skip the cutscene with two presses → world → pause → save → move → load → the position came back.
- [ ] Add a SaveManager and GameState section to `core/README.md`: **"How to make a system save: add a field to GameState, add one line each to `to_dict` and `from_dict`."** That's the reusable recipe CLAUDE.md asks for.
- [ ] Add the title, slot, pause, settings and cutscene screens to `scenes/ui/README.md`, including **how to add a cutscene** (a list of cards today; real scenes later).
- [ ] Update the Controls table in the root `README.md`: Pause is no longer reserved, and Skip cutscene is new.
- [ ] Change this plan's status line to "built".

---

## Things that commonly go wrong

| Symptom | Usually |
|---|---|
| Esc does nothing in the world | The pause menu's `CanvasLayer` is *When Paused* instead of *Always*, so it can't hear the key while the world runs |
| Can't press any button with keyboard/controller | No `grab_focus()` when the screen opens |
| Title screen frozen after Quit to Title, or the world frozen after Load | Changed or reloaded the scene before `get_tree().paused = false` |
| Title screen skips itself | Mouse motion or stick drift counted as "any button"; only accept pressed buttons and keys |
| Cutscene skips when the player only meant to read on | Skip and "next card" share a key; give skip its own action |
| Loaded game puts you at the spawn, not where you saved | Position stored as a `Vector2` and came back as a string; store `[x, y]` |
| Discoveries don't survive a load | `region_id` key came back as `String` but is looked up as `StringName` (or the other way round) |
| A failed load leaves the game half-changed | `load_game` wrote into GameState before the file had finished parsing; parse first, then copy |
| One player's settings show up in another's slot | Settings saved only to `LAST_USED`, not to the slot's own settings file |
| A slot's settings are never remembered | Saved with `Settings.save_to` before the saves folder existed; use `SaveManager.save_settings` |
| Tests wipe your saves | The tests use the real `user://saves/`; set `save_dir` to a test folder |

## Where to ask for help

Push whenever a step's check passes, even mid-plan, and tell me which step.
If a check fails and you can't see why, push anyway and tell me what you
expected and what happened. That's faster than describing the code.
