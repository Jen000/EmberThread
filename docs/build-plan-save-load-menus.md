# Build plan: saving, loading, title screen, pause screen and cutscene skip

> **Status: in progress.** Steps 1–6 and 8 built; step 7 skipped; steps 9–15
> next. Work on the `feature/save-load-and-menus` branch.
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

**Goal:** the game saves itself at key moments, and a small icon in the lower
right corner shows when it does.

Three parts: an `autosave` function in SaveManager, three places in main.gd
that call it, and a small scene for the icon. The icon's placeholder art is
already in the project: `assets/ui/ui_save_icon.png` (an arrow dropping into
a tray, with the magenta placeholder border).

### The idea

`save_game` already does the saving. `autosave` is a small wrapper around it
that says *no* in one situation: **no playthrough is running**
(`GameState.slot` is `-1`, like when you run `main.tscn` on its own), so
there's nowhere to save to.

Two autosaves close together (finishing a conversation, then stepping into
a new place) both save. That's on purpose: a save is a tiny file and takes
about a millisecond, and since quitting doesn't save, skipping one could
lose progress.

The icon doesn't need to know about autosave at all. It listens to the
`about_to_save` signal you added in step 5, so it shows for *every* save:
autosave, the pause screen's Save, and the inn later.

### 1. In `core/save_manager.gd`: the autosave function

- [ ] Add this at the bottom:

```gdscript
## Save automatically, if a playthrough is running.
## `reason` only goes in the Output panel, for testing.
func autosave(reason: String) -> void:
	if GameState.slot == -1:
		return
	print("autosave: ", reason)
	save_game(GameState.slot)
```

### 2. In `scenes/main/main.gd`: call it at three moments

**Finishing a conversation.** The dialogue box already sends a `finished`
signal when a conversation closes. Listen to it:

- [ ] In `_ready()`, just above the line `if region is Region:`, add:

```gdscript
	Dialogue.finished.connect(_on_dialogue_finished)
```

**Discovering a place.** The region sends `location_discovered`.

- [ ] Inside that same `if region is Region:` block, *above* the `_arrive(...)` line, add:

```gdscript
		(region as Region).location_discovered.connect(_on_location_discovered)
```

(Two tabs at the start, because it's inside the `if`.)

**Arriving in a region.** Only when arriving fresh at the spawn point, not
after a load (saving the instant you load would be pointless).

- [ ] In `_arrive()`, in the `else:` branch you wrote in step 5, add the autosave line under the spawn line:

```gdscript
	else:
		_player.global_position = target.get_spawn_position()
		SaveManager.autosave("arrived in a region")
```

- [ ] Then add the two functions the signals run, at the bottom of main.gd:

```gdscript
func _on_dialogue_finished() -> void:
	SaveManager.autosave("conversation finished")


func _on_location_discovered(_location_id: StringName) -> void:
	SaveManager.autosave("new place discovered")
```

The `_` at the start of `_location_id` tells Godot "I know this function is
given a value I'm not using". Without it, you'd get a yellow warning.

**Completing a mend** autosaves too, but mending isn't built yet. Open
`scenes/ui/mend_screen.gd` and leave a note at the top so it isn't forgotten:

```gdscript
# TODO(autosave): when a mend completes, call SaveManager.autosave("mend completed")
```

### 3. The save icon scene

This is built in the Godot editor, not typed. In order:

- [ ] **Scene → New Scene.** In the Scene panel, choose **Other Node** and pick **CanvasLayer**. Rename it `SaveIcon` (double-click the name).
  *A CanvasLayer draws on top of the world and doesn't move with the camera. It's how anything stays fixed to a screen corner.*
- [ ] With `SaveIcon` selected, in the **Inspector**:
  - **Layer** → `10` (above the world and the other screen text).
  - **Process → Mode** → `Always` (so the icon still fades out while the game is paused, for example after the pause screen's Save).
- [ ] Right-click `SaveIcon` → **Add Child Node** → **TextureRect**. Rename it `Icon`.
- [ ] With `Icon` selected:
  - In the toolbar above the 2D view, open the **anchor menu** (the green cross-shaped icon) and choose **Bottom Right**.
  - In the Inspector, under **Layout → Transform**, set **Size** to `16 × 16` and **Position** to `458 × 248`. That's 6 pixels in from the right and bottom of the 480×270 screen.
  - Leave **Texture** empty. The script fills it in through the asset registry, so the artist's icon replaces the placeholder later with no code change.
- [ ] Save the scene as `scenes/ui/save_icon.tscn`.
- [ ] Right-click `SaveIcon` → **Attach Script**. Save it as `scenes/ui/save_icon.gd`, and replace what's in it with:

```gdscript
extends CanvasLayer
## The save icon: appears in the lower right corner whenever the game saves,
## then fades away. Information only — nothing to press or dismiss.

## How long the icon stays fully visible, in seconds.
const SHOW_TIME := 1.0
## How long it takes to fade out, in seconds.
const FADE_TIME := 0.5

@onready var _icon: TextureRect = $Icon
var _tween: Tween


func _ready() -> void:
	_icon.texture = AssetRegistry.get_sprite("ui_save_icon")
	_icon.hide()
	SaveManager.about_to_save.connect(_show_icon)


func _show_icon() -> void:
	if _tween != null:
		_tween.kill()  # a second save while the icon is up starts it over
	_icon.modulate.a = 1.0
	_icon.show()
	_tween = create_tween()
	_tween.tween_interval(SHOW_TIME)
	if not Settings.reduced_sensory:
		_tween.tween_property(_icon, "modulate:a", 0.0, FADE_TIME)
	_tween.tween_callback(_icon.hide)
```

A **tween** is a small timeline you build in code: "wait 1 second, then fade
out over half a second, then hide". `modulate.a` is the icon's see-through
amount (1 = solid, 0 = invisible). Under reduced sensory mode there's no
fade: the icon just appears, waits, and goes.

- [ ] Put the icon in the world: open `scenes/main/main.tscn`, then drag `save_icon.tscn` from the FileSystem panel onto the **Main** node in the Scene panel. Save.

**Check:**
1. Run `main.tscn` with F5. Nothing saves on its own yet, because there's no slot (that comes with the slot screen). Press **F2** (your step 5 debug save): the icon appears in the lower right corner, then fades.
2. Walk into the tide pools. The Output panel shows `autosave: new place discovered` and the icon appears.
3. Talk to the fisherman and finish the conversation. The Output panel shows `autosave: conversation finished`.
4. Close the game without saving, run it, press **F3**. You're where the last autosave happened.
5. Turn on reduced sensory (temporarily set `reduced_sensory := true` in settings.gd), press F2: the icon appears and disappears without fading. Set it back afterwards.

---

## Step 7 (optional, skipped): A save point at the inn

*Not building this one for now. Steps 8 onward don't depend on it.*

**Goal:** a save that happens as a moment in the world, alongside autosave
and the pause screen. Skip it if you'd rather not; nothing later depends on it.

- [ ] Add an `Interactable` at the inn door in `coastal_town.tscn` (`prompt_verb = "Rest"`), wired in `coastal_town.gd` like the harbour exit.
- [ ] On interact: `Dialogue.say("", ["You rest for a while by the fire."])`, `await Dialogue.finished`, `SaveManager.save_game(GameState.slot)`, then `Dialogue.say("", ["Your journey is saved."])`.
- [ ] If saving failed, say so plainly ("Your journey couldn't be saved.") rather than pretending.

**Check:** rest at the inn, quit, load. You're at the inn.

---

## Step 8: Pause screen, with Save

**Goal:** Esc / Start opens a menu that stops the world, and its Save button
works. Load and Settings are there but greyed out until steps 9 and 10.

One new scene, built in the editor, plus its script.

### The idea

- **Stopping the world** is one line: `get_tree().paused = true`. Every node
  stops, unless it's told to keep running. The pause screen itself is told
  to keep running (Process Mode **Always**), so it can still hear keys and
  its buttons still work.
- **The pause screen shouldn't open on top of the dialogue box or the
  mending screen.** Those already pause the world. So Esc only opens the
  pause screen if the world *isn't* already paused.
- **Keyboard and controller players need a starting point.** When the menu
  opens, `grab_focus()` puts the highlight on Resume. Without it, nothing is
  selected and the arrow keys do nothing.
- **Quit to Title asks first,** with the highlight already on "No, keep
  playing", because quitting doesn't save.
- **Mouse, keyboard and controller all work, and share one highlight.**
  Buttons handle clicks on their own. Arrow keys / D-pad move the highlight
  and Enter / Space / A press it. Pointing the mouse at a button moves the
  highlight there too, so there's never one button outlined for the keyboard
  and a different one lit up under the mouse.
- **Greyed-out buttons are skipped.** Godot greys a disabled button out but
  still lets the arrow keys land on it, which feels broken. So a small helper
  disables a button *and* takes it out of keyboard navigation.

### 1. Build the scene

Here's the tree you're making. Indentation means "is a child of":

```
PauseMenu        CanvasLayer
└─ Menu          Control
   ├─ Dim        ColorRect
   └─ Center     CenterContainer
      └─ Panel   PanelContainer
         └─ Box  VBoxContainer
            ├─ Heading       Label            "Paused"
            ├─ Buttons       VBoxContainer    %
            │  ├─ Resume     Button           %  "Resume"
            │  ├─ Save       Button           %  "Save"
            │  ├─ Load       Button           %  "Load"
            │  ├─ Settings   Button           %  "Settings"
            │  └─ Quit       Button           %  "Quit to Title"
            ├─ ConfirmQuit   VBoxContainer    %  (hidden)
            │  ├─ Question   Label               "Quit to the title? Anything since your last save will be lost."
            │  ├─ QuitYes    Button           %  "Yes, quit"
            │  └─ QuitNo     Button           %  "No, keep playing"
            └─ Message       Label            %  (empty)
```

**`%` means "unique name".** It lets the script find a node by name alone
(`%Save`) instead of its full path (`$Menu/Center/Panel/Box/Buttons/Save`),
so you can rearrange the tree later without breaking the script. To set it:
right-click the node → **Access as Unique Name**. A `%` appears next to it.

Step by step:

- [ ] **Scene → New Scene → Other Node → CanvasLayer.** Rename it `PauseMenu`. In the Inspector:
  - **Layer** → `5` (above the world and the controls hint, below the save icon's `10`, so the icon still shows when you press Save).
  - **Process → Mode** → `Always`.
- [ ] Add a child **Control**, renamed `Menu`. With it selected, open the **anchor menu** (green cross in the toolbar) and choose **Full Rect**, so it covers the whole screen.
- [ ] Under `Menu`, add a **ColorRect** named `Dim`. Anchor menu → **Full Rect**. In the Inspector, set **Color** to black, with its alpha (the A slider) about halfway. It darkens the world behind the menu.
- [ ] Under `Menu`, add a **CenterContainer** named `Center`. Anchor menu → **Full Rect**. Anything inside it sits in the middle of the screen.
- [ ] Under `Center`, add a **PanelContainer** named `Panel`. This draws the menu's background box.
- [ ] Under `Panel`, add a **VBoxContainer** named `Box`. A VBoxContainer stacks its children top to bottom, so you never position buttons by hand.
- [ ] Under `Box`, add the rest from the tree above, in order. For each one:
  - **Labels:** type the text in the Inspector's **Text**, and set **Horizontal Alignment** to Center.
  - **Buttons:** type the text in **Text**.
  - Mark every node with `%` in the tree as **Access as Unique Name**.
- [ ] Select `ConfirmQuit` and click the **eye icon** next to it in the Scene panel, so it starts hidden.
- [ ] Select `Question` and set **Autowrap Mode** → `Word (Smart)`, and **Custom Minimum Size** → **x** `220`. Without a width, a wrapping label squashes to nothing.
- [ ] Save as `scenes/ui/pause_menu.tscn`.

### 2. The script

- [ ] Right-click `PauseMenu` → **Attach Script**, save as `scenes/ui/pause_menu.gd`, and replace its contents with:

```gdscript
extends CanvasLayer
## The pause screen: Esc / Start in the world. Stops the world while open.
## Resume, Save, Load, Settings, Quit to Title. Load and Settings are
## switched on by later steps.

@onready var _menu: Control = $Menu


func _ready() -> void:
	_menu.hide()
	%Resume.pressed.connect(close)
	%Save.pressed.connect(_on_save_pressed)
	%Quit.pressed.connect(_on_quit_pressed)
	%QuitYes.pressed.connect(_on_quit_confirmed)
	%QuitNo.pressed.connect(_show_buttons)
	_set_enabled(%Load, false)      # step 9 switches this on
	_set_enabled(%Settings, false)  # step 10 switches this on
	# Mouse and keyboard share one highlight: pointing at a button moves the
	# keyboard focus there too, so there's never a second, confusing one.
	for button in [%Resume, %Save, %Load, %Settings, %Quit, %QuitYes, %QuitNo]:
		button.mouse_entered.connect(_focus_if_enabled.bind(button))


func _unhandled_input(event: InputEvent) -> void:
	if _menu.visible:
		# Esc / Start / B while open: step back (confirm -> menu -> game).
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			if %ConfirmQuit.visible:
				_show_buttons()
			else:
				close()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") and not get_tree().paused:
		# Only when nothing else (dialogue, mending) has already paused.
		open()
		get_viewport().set_input_as_handled()


func open() -> void:
	get_tree().paused = true
	_set_enabled(%Save, GameState.slot != -1)  # nowhere to save without a slot
	%Message.text = ""
	_menu.show()
	_show_buttons()
	%Resume.grab_focus()


func close() -> void:
	_menu.hide()
	get_tree().paused = false


func _show_buttons() -> void:
	%ConfirmQuit.hide()
	%Buttons.show()
	%Quit.grab_focus()


func _on_save_pressed() -> void:
	if SaveManager.save_game(GameState.slot):
		%Message.text = "Saved."
	else:
		%Message.text = "Couldn't save. Your last save is still safe."


func _on_quit_pressed() -> void:
	%Buttons.hide()
	%ConfirmQuit.show()
	%QuitNo.grab_focus()  # the safe answer is the one already selected


func _on_quit_confirmed() -> void:
	get_tree().paused = false
	# TODO(step 11): go to the title screen instead of closing the game:
	# get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
	get_tree().quit()


## Grey a button out AND take it out of keyboard/controller navigation.
## (Godot still lets arrow keys land on a disabled button otherwise.)
func _set_enabled(button: Button, enabled: bool) -> void:
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


func _focus_if_enabled(button: Button) -> void:
	if not button.disabled:
		button.grab_focus()
```

What the less obvious lines do:
- **`%Resume.pressed.connect(close)`**: every Button sends a `pressed` signal when clicked or activated with Enter / A. This says "when Resume is pressed, run `close`".
- **`_unhandled_input`** runs for every key or button press that nothing else has used. `is_action_pressed("pause")` asks "is this the pause key?" (Esc / Start, set up in Project Settings → Input Map). `ui_cancel` is Godot's built-in "back" action: Esc, and B on a controller.
- **`set_input_as_handled()`** means "I've dealt with this key press". Without it, the same Esc that closes the menu could reopen it, or reach something else.
- **`mouse_entered.connect(_focus_if_enabled.bind(button))`**: `mouse_entered` is sent when the pointer moves onto a button. `.bind(button)` attaches *which* button it was, so one function can handle all seven.
- **`focus_mode`** decides whether a control can hold the keyboard highlight. `FOCUS_NONE` takes a button out of arrow-key navigation; `FOCUS_ALL` puts it back.
- **`_set_enabled` and `_focus_if_enabled` move into a shared helper in step 9,** since every menu needs them.
- **Quit doesn't go to the title yet.** The title screen is step 11. Until then "Yes, quit" closes the game, so you can still test the confirmation. Step 11 swaps the line.

### 3. Put it in the world

- [ ] Open `scenes/main/main.tscn` and drag `pause_menu.tscn` from the FileSystem panel onto the **Main** node. Save.

**Check:**
1. Run with F5 and press **F2** once, so there's a slot (otherwise Save is greyed out, correctly).
2. Press **Esc**. The world darkens and stops, including Pip's bob, and **Resume** is highlighted.
3. Use the **arrow keys** to move between buttons. Load and Settings are greyed out, and the highlight jumps straight over them (Resume → Save → Quit to Title).
4. Move the **mouse** over Quit to Title: the highlight moves there. Press **Enter**: Quit to Title is the one that's pressed. Then press **Esc** to back out.
5. **Click** Save. "Saved." appears under the buttons, and the save icon shows in the corner.
6. Press **Esc**. The menu closes and the world moves again.
7. Talk to the fisherman, and press **Esc** in the middle of his line. Nothing happens. Finish the conversation.
8. Press **Esc**, choose **Quit to Title** with the keyboard. The question appears with **No, keep playing** highlighted. Press **Esc**: you're back at the buttons. Choose Quit again, then **Yes, quit**: the game closes.
9. Run again, press **F3**: you're where you pressed Save in check 5.
10. One more pass with **only the mouse**: open with Esc, then click Save, click Quit to Title, click No, click Resume.

---

## Step 9: Slot list, and Load from the pause screen

**Goal:** one reusable list of the three slots. The pause screen's Load uses
it now, and the slot screen (step 12) uses the same list later.

Three parts: a small shared helper first, then the slot list scene, then
plugging it into the pause screen.

### The idea

- **One list, two jobs.** The pause screen wants "pick a save to load". The
  slot screen wants "pick a save to continue, or an empty slot for a new
  game". That's the same list with small differences, so it's one scene
  with a **mode**: `"load"` greys out empty slots, `"play"` labels them
  "New Game" and adds a Delete button to used ones.
- **The list doesn't load anything.** It only says *which* slot was picked,
  by sending a `slot_chosen(slot)` signal, or `cancelled` if the player
  backed out. Whoever opened the list decides what happens next. That's
  what makes it reusable.
- **The rows are made by code, not in the editor.** There are always
  three, and their text depends on what's on disk, so the script builds
  them each time the list opens.
- **Ask before anything that loses progress.** Loading throws away
  everything since the last save, so the pause screen asks first, with
  the highlight already on **No**.
- **If a load fails, nothing changes.** Your step 4 `load_game` only touches
  GameState once the file has been read successfully. So a broken file just
  shows a message, and the game carries on.

### 1. A shared helper for every menu

Every menu from here on needs the same two tricks your pause menu already
does: greying a button out *and* skipping it with the arrow keys, and
making the mouse move the highlight. Rather than copy them into every
script, they go in one small file.

There's also a fix in here. Your step 8 version uses `mouse_entered`, which
also fires when a screen **appears underneath a mouse that isn't moving**.
On a menu that opens where the cursor happens to be resting, that steals
the highlight from where the code put it. The version below only reacts to
the mouse actually moving.

- [ ] In the FileSystem panel, right-click `scenes/ui` → **Create New → Script...**. Name it `menu_util.gd`, **Inherits** `RefCounted`. Replace its contents with:

```gdscript
class_name MenuUtil
extends RefCounted
## Small helpers every menu shares, so mouse, keyboard and controller behave
## the same on every screen. Use them as MenuUtil.set_enabled(...), etc.


## Grey a button out AND take it out of keyboard/controller navigation.
## (Godot still lets arrow keys land on a disabled button otherwise.)
static func set_enabled(button: BaseButton, enabled: bool) -> void:
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


## Moving the mouse over a control moves the keyboard highlight to it, so
## mouse and keyboard always share one highlight. Only real mouse movement
## counts: a screen opening under a resting cursor doesn't steal it.
static func hover_moves_focus(control: Control) -> void:
	control.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseMotion \
				and control.focus_mode != Control.FOCUS_NONE \
				and not control.has_focus():
			control.grab_focus())
```

What's new here:
- **`class_name MenuUtil`** gives the script a global name, so any other script can write `MenuUtil.set_enabled(...)` without loading it first. (This is different from an autoload: nothing is added to the game, it's just a named toolbox.)
- **`static func`** means "call it on the name, not on an object". There's no MenuUtil node anywhere.
- **`extends RefCounted`**: the lightest thing a script can be. It isn't a node, so it never appears in a scene.
- **`gui_input`** is a signal every Control sends for each input event that lands on it. `func(event): ...` is a function written in place (a "lambda"), so each control gets its own little listener.
- **The `\` at the end of a line** means "this line carries on below". It's only for readability.

Now switch your pause menu over to it:

- [ ] In `pause_menu.gd`, in `_ready`, replace the `_set_enabled(...)` lines and the `for button in ...: button.mouse_entered.connect(...)` loop with:

```gdscript
	MenuUtil.set_enabled(%Load, false)      # switched on below, in this step
	MenuUtil.set_enabled(%Settings, false)  # step 10 switches this on
	for button in [%Resume, %Save, %Load, %Settings, %Quit, %QuitYes, %QuitNo]:
		MenuUtil.hover_moves_focus(button)
```

- [ ] In `open()`, change `_set_enabled(%Save, ...)` to `MenuUtil.set_enabled(%Save, ...)`.
- [ ] Delete the `_set_enabled` and `_focus_if_enabled` functions at the bottom. They live in MenuUtil now.

Two small things I noticed checking your step 8, worth fixing while you're in `pause_menu.tscn`:
- [ ] `Question`'s **Custom Minimum Size → x** is `22`, not `220`, so the question wraps very narrowly. Set it to `220`.
- [ ] The last button's text is "Quit". Make it **"Quit to Title"**. Step 12 adds a separate "Quit game" button on the slot screen, and the two should be easy to tell apart.

**Check:** run, press F2, then Esc. Everything works exactly as in step 8.
Now leave the mouse still over where a button will appear, close the menu
with Esc and open it again: Resume is highlighted, not the button under the
mouse.

### 2. Build the slot list scene

```
SlotList         PanelContainer
└─ Box           VBoxContainer
   ├─ Heading    Label            "Choose a slot"
   ├─ Rows       VBoxContainer    %  (empty: the script fills it)
   ├─ Confirm    VBoxContainer    %  (hidden)
   │  ├─ Question Label           %  (empty)
   │  ├─ Yes     Button           %  "Yes"
   │  └─ No      Button           %  "No"
   ├─ Back       Button           %  "Back"
   └─ Message    Label            %  (empty)
```

- [ ] **Scene → New Scene → Other Node → PanelContainer.** Rename it `SlotList`. (No Process Mode change needed: it sits *inside* the pause menu, which is already Always, and it inherits that.)
- [ ] Add the children from the tree above. Mark every `%` node **Access as Unique Name** (right-click → Access as Unique Name).
- [ ] `Heading` and `Message`: **Horizontal Alignment** → Center.
- [ ] `Question`: **Horizontal Alignment** → Center, **Autowrap Mode** → `Word (Smart)`, **Custom Minimum Size → x** → `220`.
- [ ] Hide `Confirm` with its eye icon.
- [ ] Save as `scenes/ui/slot_list.tscn`.

### 3. The slot list script

- [ ] Right-click `SlotList` → **Attach Script**, save as `scenes/ui/slot_list.gd`, and replace its contents with:

```gdscript
extends PanelContainer
## The three save slots as a list. Used by the pause screen's Load and by
## the slot screen. It only reports which slot was chosen; whoever opened it
## decides what to do (load it, start a new game in it...).
##
## Two modes:
##   "load"  empty slots can't be chosen (pause screen's Load)
##   "play"  empty slots say "New Game", and each used slot has Delete
##           (slot screen)

## A slot was chosen (and confirmed, if a question was set).
signal slot_chosen(slot: int)
## The player backed out without choosing.
signal cancelled

## How region ids are shown to the player.
const REGION_NAMES := {"coastal": "Coastal Town"}

var _mode := "load"
## Asked before `slot_chosen` is sent. Empty = don't ask. "%d" = slot number.
var _question := ""
## What Yes does right now: choose a slot, or delete one.
var _pending_action := ""
var _pending_slot := -1


func _ready() -> void:
	hide()
	%Back.pressed.connect(_on_back)
	%Yes.pressed.connect(_on_yes)
	%No.pressed.connect(_show_rows)
	for button in [%Back, %Yes, %No]:
		MenuUtil.hover_moves_focus(button)


## Show the list. `focus_slot` is the slot to highlight first (-1 = the most
## recently saved one). `question` is asked before choosing, e.g.
## "Load Slot %d? Anything since your last save will be lost."
func open(mode: String, focus_slot: int = -1, question: String = "") -> void:
	_mode = mode
	_question = question
	_pending_slot = -1
	%Message.text = ""
	show()
	_build_rows()
	_show_rows()
	_focus_slot(focus_slot if focus_slot != -1 else _most_recent_slot())


## Show a line of text under the list, e.g. "Slot 2 couldn't be read."
func show_message(text: String) -> void:
	%Message.text = text


func close() -> void:
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		# Mark the key as used FIRST: going back may leave this screen.
		get_viewport().set_input_as_handled()
		if %Confirm.visible:
			_show_rows()
		else:
			_on_back()


# --- the rows ------------------------------------------------------------------

## One row per slot: the slot button, plus Delete in play mode.
func _build_rows() -> void:
	for child in %Rows.get_children():
		child.queue_free()
	for slot in SaveManager.SLOT_COUNT:
		var info := SaveManager.slot_info(slot)
		var row := HBoxContainer.new()
		var button := Button.new()
		button.name = "Slot%d" % slot
		button.text = _describe(slot, info)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var usable := not info.is_empty() and not info.has("broken")
		MenuUtil.set_enabled(button, usable or (_mode == "play" and info.is_empty()))
		button.pressed.connect(_on_slot_pressed.bind(slot))
		MenuUtil.hover_moves_focus(button)
		row.add_child(button)
		if _mode == "play" and not info.is_empty():
			var delete := Button.new()
			delete.text = "Delete"
			delete.pressed.connect(_on_delete_pressed.bind(slot))
			MenuUtil.hover_moves_focus(delete)
			row.add_child(delete)
		%Rows.add_child(row)


## "Slot 1 — Coastal Town · 1h 12m · 3 h ago", "Slot 2 — Empty", ...
func _describe(slot: int, info: Dictionary) -> String:
	var label := "Slot %d — " % (slot + 1)
	if info.is_empty():
		return label + ("New Game" if _mode == "play" else "Empty")
	if info.has("broken"):
		return label + "This save couldn't be read"
	var region: String = REGION_NAMES.get(info["region_id"], info["region_id"])
	return label + "%s · %s · %s" % [region, _playtime_text(info["playtime"]), _ago_text(info["saved_at"])]


func _playtime_text(seconds: float) -> String:
	var minutes := int(seconds) / 60
	if minutes < 60:
		return "%dm" % minutes
	return "%dh %dm" % [minutes / 60, minutes % 60]


func _ago_text(saved_at: float) -> String:
	var seconds := int(Time.get_unix_time_from_system() - saved_at)
	if seconds < 60:
		return "just now"
	if seconds < 3600:
		return "%d min ago" % (seconds / 60)
	if seconds < 86400:
		return "%d h ago" % (seconds / 3600)
	return "%d days ago" % (seconds / 86400)


func _most_recent_slot() -> int:
	var best := 0
	var best_time := -1.0
	for slot in SaveManager.SLOT_COUNT:
		var info := SaveManager.slot_info(slot)
		if info.has("saved_at") and info["saved_at"] > best_time:
			best = slot
			best_time = info["saved_at"]
	return best


func _focus_slot(slot: int) -> void:
	var button := %Rows.get_child(slot).get_child(0) as Button
	if button.disabled:
		%Back.grab_focus()
	else:
		button.grab_focus()


# --- choosing, deleting, confirming ---------------------------------------------

func _on_slot_pressed(slot: int) -> void:
	if _question == "":
		slot_chosen.emit(slot)
		return
	_ask("choose", slot, _question % (slot + 1))


func _on_delete_pressed(slot: int) -> void:
	_ask("delete", slot, "Delete Slot %d? This can't be undone." % (slot + 1))


func _ask(action: String, slot: int, question: String) -> void:
	_pending_action = action
	_pending_slot = slot
	%Question.text = question
	%Rows.hide()
	%Back.hide()
	%Confirm.show()
	%No.grab_focus()  # the safe answer is the one already selected


func _on_yes() -> void:
	var slot := _pending_slot
	if _pending_action == "delete":
		SaveManager.delete_slot(slot)
		_build_rows()
		_show_rows()
		_focus_slot(slot)
	else:
		_show_rows()
		slot_chosen.emit(slot)


func _show_rows() -> void:
	%Confirm.hide()
	%Rows.show()
	%Back.show()
	if _pending_slot != -1 and _pending_slot < %Rows.get_child_count():
		_focus_slot(_pending_slot)


func _on_back() -> void:
	close()
	cancelled.emit()
```

What the less obvious lines do:
- **`signal slot_chosen(slot: int)`** declares a signal of your own. `slot_chosen.emit(2)` sends it, and anything that connected to it runs, receiving `2`. Same idea as a Button's `pressed`, but you decide when it fires.
- **`Button.new()` / `row.add_child(button)`**: making nodes in code. It's what you'd do in the editor, written down.
- **`slot + 1`**: slots are numbered 0, 1, 2 inside the game (that's how the files are named), but people count from 1. Only the text adds 1.
- **`_question % (slot + 1)`**: `%` on a String fills in the `%d`. So `"Load Slot %d?" % 2` is `"Load Slot 2?"`.
- **`queue_free()`** removes a node safely at the end of the frame. The old rows go before the new ones are built.
- **`set_input_as_handled()` comes first** in `_unhandled_input`. When Back leaves the screen entirely (the slot screen does this in step 12), the node is no longer in a viewport afterwards, and calling it last gives an error.
- **`REGION_NAMES`** turns `coastal` into "Coastal Town". Add a line when each new region is built.

### 4. Put it in the pause screen

- [ ] Open `pause_menu.tscn`. Right-click `Panel` → **Access as Unique Name**, so the script can hide the whole button panel while the list shows.
- [ ] Drag `slot_list.tscn` from the FileSystem onto **`Center`** (not into Panel: it replaces Panel on screen while it's open). Right-click the new `SlotList` → **Access as Unique Name**.
- [ ] In `pause_menu.gd`, add to `_ready`:

```gdscript
	%Load.pressed.connect(_on_load_pressed)
	%SlotList.slot_chosen.connect(_on_slot_chosen)
	%SlotList.cancelled.connect(_on_slot_list_closed)
```

- [ ] Remove the `MenuUtil.set_enabled(%Load, false)` line. Load is on now.
- [ ] In `open()`, add these two lines just after `get_tree().paused = true`, so the menu always opens on its buttons even if it was closed while the list was showing:

```gdscript
	%Panel.show()
	%SlotList.close()
```

- [ ] Add these functions at the bottom:

```gdscript
## Load: show the slot list in place of the buttons.
func _on_load_pressed() -> void:
	%Panel.hide()
	%SlotList.open("load", GameState.slot,
			"Load Slot %d? Anything since your last save will be lost.")


## A slot was chosen and confirmed. Load it and restart the world from it.
func _on_slot_chosen(slot: int) -> void:
	if SaveManager.load_game(slot):
		get_tree().paused = false
		get_tree().reload_current_scene()
	else:
		%SlotList.show_message("Slot %d couldn't be read." % (slot + 1))


## Back from the slot list: the buttons return, with Load highlighted.
func _on_slot_list_closed() -> void:
	%Panel.show()
	%Load.grab_focus()
```

- **`reload_current_scene()`** throws the world away and builds it again. Because step 5 made the world start from GameState, and `load_game` just filled GameState, the rebuilt world is the loaded one. Loading a different player's slot also switches to their settings (step 4 did that too).
- **Unpause before reloading.** Otherwise the fresh world starts paused and nothing moves.

**Check:**
1. Run, press **F2** (saves to slot 1). Walk somewhere else.
2. **Esc → Load.** The list shows "Slot 1 — Coastal Town · 0m · just now", with that row highlighted. Slots 2 and 3 say "Empty", are greyed out, and the arrow keys skip them.
3. Press **Enter**. The question appears, with **No** highlighted. Press **Enter** on No: back at the list, nothing changed.
4. Choose slot 1 again, then **Yes**. The world reloads and you're back where you pressed F2. It isn't paused.
5. Esc → Load, then **Esc**: back at the pause buttons with Load highlighted. Esc again: back in the game.
6. Same again with **only the mouse**: click Load, click slot 1, click No, click Back, click Resume.
7. **A broken save.** Close the game. In Godot, **Project → Open User Data Folder**, open `saves/slot_0.json` in a text editor, type some nonsense at the start, and save it. Run the game again, but **don't** press F2 (it would overwrite the broken file). Esc → Load. Slot 1 says "This save couldn't be read" and is greyed out. Press F2 afterwards to fix it.

---

## Step 10: Settings screen

**Goal:** one settings screen, opened from the pause screen now and from the
slot screen in step 12. Menu text grows with the Text size setting.

### The idea

- **Every control changes the setting the moment you touch it.** Drag Text
  size and the text grows as you drag. That's the best preview there is,
  and there's no "Apply" button to forget.
- **Saving happens once, when the screen closes.** Into the current
  player's slot (so each player keeps their own), and into `LAST_USED` (so
  the title screen opens with these settings next time). This saves even
  though quitting doesn't save progress: settings aren't progress.
- **Every setting gets a plain description under it.** People can't choose
  a setting they don't understand.
- **One theme for all menus.** Godot lets a project have one *Theme*: a
  resource that says how every button, label and panel looks by default.
  Its font size is the size of all menu text. So when Text size changes,
  `Settings` changes that one number, and every menu everywhere resizes
  live. No menu has to do anything itself.
- **The list scrolls** at big text sizes, so the screen never runs off the
  edge.

### 1. A project theme, so menu text follows Text size

- [ ] In the FileSystem, right-click `scenes/ui` → **Create New → Resource...**, search for **Theme**, and save it as `scenes/ui/menu_theme.tres`.
- [ ] Double-click it. In the Inspector, set **Default Font Size** → `10`. (A bottom panel opens for editing the theme; you can ignore it.)
- [ ] **Project → Project Settings → GUI → Theme → Custom**: pick `menu_theme.tres`. Every Control in the game now uses it.

Your menus get smaller at this point: Godot's default was 16, which is huge
at 480×270. 10 is the size at Text size 1.0.

- [ ] In `core/settings.gd`, add the constant near the top, below `LAST_USED`:

```gdscript
## Menu text size at text_scale 1.0. Every menu uses the project theme
## (Project Settings → GUI → Theme), so changing it here resizes them all.
const MENU_FONT_SIZE := 10
```

- [ ] Add two lines to the end of `_ready`, and the new function after it:

```gdscript
func _ready() -> void:
	load_from(LAST_USED)
	changed.connect(_apply_menu_text_size)
	_apply_menu_text_size()


## Make all menu text follow the text size setting, live.
func _apply_menu_text_size() -> void:
	var theme := ThemeDB.get_project_theme()
	if theme != null:
		theme.default_font_size = roundi(MENU_FONT_SIZE * text_scale)
```

- **`changed.connect(...)`**: `Settings` already sends `changed` whenever any setting is set (that's what the `set(value):` blocks do). Now one of the things listening is "resize the menus".
- **`ThemeDB.get_project_theme()`** is the theme you just picked in Project Settings.
- **`roundi`** rounds to a whole number. Font sizes can't be 12.5.

**Check:** run. The pause menu text is smaller than before, and still readable.

### 2. Build the settings scene

```
SettingsMenu          PanelContainer
└─ Box                VBoxContainer
   ├─ Heading         Label          "Settings"
   ├─ Scroll          ScrollContainer
   │  └─ Rows         VBoxContainer
   │     ├─ TextSizeLabel       Label        %  "Text size"
   │     ├─ TextSize            HSlider      %
   │     ├─ TextSizeHelp        Label           "How big all the words in the game are."
   │     ├─ TextSpeedLabel      Label        %  "Text speed"
   │     ├─ TextSpeed           HSlider      %
   │     ├─ TextSpeedHelp       Label           "How quickly conversation text appears. Higher is faster."
   │     ├─ ReducedSensory      CheckButton  %  "Reduced sensory"
   │     ├─ ReducedSensoryHelp  Label           "Softens flashing and pulsing, including Pip's glow."
   │     ├─ Hints               CheckButton  %  "Interaction hints"
   │     ├─ HintsHelp           Label           "Shows a label like "[E] Talk" over things you can use."
   │     └─ Controls            Label           "Controls: coming soon"
   └─ Back            Button         %  "Back"
```

- [ ] **Scene → New Scene → Other Node → PanelContainer**, renamed `SettingsMenu`.
- [ ] Add the children from the tree. Mark the `%` ones **Access as Unique Name**. `Heading`: Horizontal Alignment → Center.
- [ ] `Scroll`:
  - **Custom Minimum Size** → x `280`, y `170`. A ScrollContainer has no size of its own, so without this it's zero tall.
  - **Follow Focus** → on. When the arrow keys move down to a row that's off screen, it scrolls there.
  - **Horizontal Scroll Mode** → `Disabled`. Text should wrap, never scroll sideways.
- [ ] `Rows`: **Layout → Container Sizing → Horizontal** → **Expand** ticked, so the rows use the full width.
- [ ] `TextSize`: **Min Value** `0.75`, **Max Value** `2`, **Step** `0.25`, **Value** `1`.
- [ ] `TextSpeed`: **Min Value** `0.5`, **Max Value** `5`, **Step** `0.5`, **Value** `1`.
- [ ] Every `...Help` label: **Autowrap Mode** → `Word (Smart)`.
- [ ] Save as `scenes/ui/settings_menu.tscn`.

**Remappable controls** are required by the design doc, and deserve their own
plan, so for now the screen just says they're coming. Don't build them here.

### 3. The settings script

- [ ] Attach a script to `SettingsMenu`, saved as `scenes/ui/settings_menu.gd`:

```gdscript
extends PanelContainer
## The settings screen. Opened from the pause screen and the slot screen.
## Every control changes the setting straight away (text resizes as you drag),
## and the settings are saved once, when the screen closes.

## The screen was closed with Back / Esc.
signal closed


func _ready() -> void:
	hide()
	%TextSize.value_changed.connect(_on_text_size_changed)
	%TextSpeed.value_changed.connect(_on_text_speed_changed)
	%ReducedSensory.toggled.connect(_on_reduced_sensory_toggled)
	%Hints.toggled.connect(_on_hints_toggled)
	%Back.pressed.connect(close)
	for control in [%TextSize, %TextSpeed, %ReducedSensory, %Hints, %Back]:
		MenuUtil.hover_moves_focus(control)


## Show the screen with the controls matching the current settings.
func open() -> void:
	# set_value_no_signal: move the control without it reporting a change.
	%TextSize.set_value_no_signal(Settings.text_scale)
	%TextSpeed.set_value_no_signal(Settings.text_speed)
	%ReducedSensory.set_pressed_no_signal(Settings.reduced_sensory)
	%Hints.set_pressed_no_signal(Settings.interaction_hints)
	_update_labels()
	show()
	%TextSize.grab_focus()


## Save the settings, then hide.
func close() -> void:
	if GameState.slot != -1:
		SaveManager.save_settings(GameState.slot)  # this player's settings
	Settings.save_to(Settings.LAST_USED)          # what the title screen opens with
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		close()


func _on_text_size_changed(value: float) -> void:
	Settings.text_scale = value
	_update_labels()


func _on_text_speed_changed(value: float) -> void:
	Settings.text_speed = value
	_update_labels()


func _on_reduced_sensory_toggled(on: bool) -> void:
	Settings.reduced_sensory = on


func _on_hints_toggled(on: bool) -> void:
	Settings.interaction_hints = on


func _update_labels() -> void:
	%TextSizeLabel.text = "Text size: %s×" % snappedf(Settings.text_scale, 0.01)
	%TextSpeedLabel.text = "Text speed: %s×" % snappedf(Settings.text_speed, 0.01)
```

- **`value_changed`** (sliders) and **`toggled`** (check buttons) are their versions of a Button's `pressed`. They pass along the new value.
- **`set_value_no_signal`** sets the slider to match `Settings` *without* sending `value_changed`. Opening the screen shouldn't count as the player changing something.
- **Sliders and the keyboard:** with a slider highlighted, **left/right** move it and **up/down** move to the next row. That's built into Godot.

### 4. Put it in the pause screen

- [ ] Open `pause_menu.tscn` and drag `settings_menu.tscn` onto **`Center`**, next to SlotList. Mark it **Access as Unique Name**.
- [ ] In `pause_menu.gd`:
  - Remove `MenuUtil.set_enabled(%Settings, false)` from `_ready`.
  - Add to `_ready`:

```gdscript
	%Settings.pressed.connect(_on_settings_pressed)
	%SettingsMenu.closed.connect(_on_settings_closed)
```

  - Add `%SettingsMenu.hide()` in `open()`, under `%SlotList.close()`.
  - Add at the bottom:

```gdscript
## Settings: show the settings screen in place of the buttons.
func _on_settings_pressed() -> void:
	%Panel.hide()
	%SettingsMenu.open()


func _on_settings_closed() -> void:
	%Panel.show()
	%Settings.grab_focus()
```

**Check:**
1. Run, F2, Esc → **Settings**. Text size is highlighted.
2. Press **right** a few times. All the text on the screen grows as you press, and the label says "Text size: 1.75×".
3. Press **down**: the highlight moves to the next control, and the list scrolls to keep it in view.
4. Press **Space** on Reduced sensory: it switches on. Press it again to switch it off.
5. **Esc**: back at the pause buttons, with Settings highlighted. The pause menu text is big too.
6. Drag Text size to **2.0** with the mouse. Nothing runs off the screen; the list scrolls instead.
7. Esc twice to get back to the game, close the game, run it again, and press **F3**. The text is still big: it was saved with slot 1.

---

## Step 11: Title screen

**Goal:** the game opens on the title art, and waits for any button.

### The idea

- **Art goes through `AssetRegistry`,** like everything else. There's a
  480×270 block placeholder already in the repo, `assets/ui/ui_title.png`
  (magenta border, so it's obviously temporary). When the artist delivers
  the real one with the same name, it just appears. No code changes.
- **"Any button" means any:** a key, a mouse click, a controller button.
  But *not* the mouse moving or a stick drifting slightly, or the screen
  would skip itself before anyone saw it.
- **It never moves on by itself.** No timer.

### 1. Build the scene

```
TitleScreen   Control
├─ Art        TextureRect
├─ Name       Label         "Ember & Thread"
└─ Prompt     Label         "Press any button"
```

- [ ] **Scene → New Scene → User Interface** (that makes a Control). Rename it `TitleScreen`. Anchor menu → **Full Rect**.
- [ ] Add a **TextureRect** named `Art`. Anchor menu → **Full Rect**. **Expand Mode** → `Ignore Size`, so it stretches to the screen whatever size the art is. Leave **Texture** empty: the script sets it.
- [ ] Add a **Label** named `Name`. Anchor menu → **Full Rect**. **Horizontal** and **Vertical Alignment** → Center. Under **Theme Overrides → Font Sizes → Font Size**, tick it and set `28`. (The real title art will probably include the name; then delete this label.)
- [ ] Add a **Label** named `Prompt`. Anchor menu → **Bottom Wide**. **Horizontal Alignment** → Center. Then in **Layout → Transform**, set **Position → y** to about `225`, so it sits a little above the bottom edge.
- [ ] Save as `scenes/ui/title_screen.tscn`.

### 2. The script

- [ ] Attach `scenes/ui/title_screen.gd`:

```gdscript
extends Control
## The title screen: the title art and "Press any button". Any key, mouse
## click or controller button moves on to the slot screen. Nothing happens
## on a timer.

const SLOT_SCREEN := "res://scenes/ui/slot_screen.tscn"


func _ready() -> void:
	$Art.texture = AssetRegistry.get_sprite("ui_title")


func _unhandled_input(event: InputEvent) -> void:
	if _is_a_press(event):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(SLOT_SCREEN)


## True for a key, mouse button or controller button being pressed down.
## Not for moving the mouse, nudging a stick, or the scroll wheel, so the
## screen never skips itself by accident.
func _is_a_press(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if event is InputEventMouseButton:
		var button := (event as InputEventMouseButton).button_index
		return button == MOUSE_BUTTON_LEFT or button == MOUSE_BUTTON_RIGHT
	return event is InputEventKey or event is InputEventJoypadButton
```

- **`event is InputEventKey`** asks "is this a keyboard event?". Each kind of input is its own type: keys, mouse buttons, mouse movement, controller buttons, controller sticks. Checking the type is how you accept some and ignore others.
- **`is_echo()`** is a key repeating because it's held down. Only the first press counts.
- **The scroll wheel** counts as a "mouse button" in Godot, which is why the code only accepts left and right clicks.

### 3. Make it the first screen, and make Quit go there

- [ ] **Project → Project Settings → Application → Run → Main Scene**: pick `title_screen.tscn`. Now F5 starts here. (F6 still runs whatever scene you have open, so you can keep testing the world directly.)
- [ ] In `pause_menu.gd`, `_on_quit_confirmed` becomes:

```gdscript
func _on_quit_confirmed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
```

Unpausing first matters: the pause belongs to the whole game, not the
world, so otherwise the title screen would start paused.

**Check:** (the slot screen comes in step 12, so moving on gives an error
for now. That's expected.)
1. F5. The placeholder title shows: a magenta frame, the name, "Press any button".
2. Move the mouse around, and scroll the wheel. Nothing happens.
3. Press a key. The Output panel shows an error about `slot_screen.tscn` not existing. Good: that means it tried to move on.
4. Run again and try a mouse click, and a controller button if you have one. Same.

---

## Step 12: Slot screen and new game

**Goal:** after the title, choose a slot: continue that player, or start a
new one. Settings is here too, so someone can make the text readable
*before* choosing.

### The idea

- **It's mostly the slot list from step 9**, in `"play"` mode, with a
  Settings and a Quit button underneath.
- **No slot is active here.** `GameState.slot = -1` when the screen opens.
  So Settings changes only the screen's own settings (and `LAST_USED`),
  not anyone's slot.
- **A used slot** loads it, then switches to the world. Loading also
  switches to that player's settings (step 4).
- **An empty slot** is a brand-new player: GameState is reset, and the new
  player starts with the settings currently on screen. Their save file
  appears at the first autosave (arriving in the region).
- **Starting over in a used slot** is Delete, then New Game. Delete asks
  first, with **No** highlighted.
- **Back / Esc** goes to the title. **Quit game** closes the game, with no
  question, because nothing is being played.

### 1. Build the scene

```
SlotScreen        Control
├─ Background      ColorRect
└─ Center          CenterContainer
   ├─ Main         VBoxContainer   %
   │  ├─ SlotList  (slot_list.tscn)  %
   │  └─ Buttons   HBoxContainer
   │     ├─ Settings  Button  %  "Settings"
   │     └─ Quit      Button  %  "Quit game"
   └─ SettingsMenu  (settings_menu.tscn)  %
```

- [ ] **Scene → New Scene → User Interface**, renamed `SlotScreen`. Anchor menu → **Full Rect**.
- [ ] Add a **ColorRect** `Background`, Full Rect, a dark colour. (A real background is an art job for later.)
- [ ] Add a **CenterContainer** `Center`, Full Rect.
- [ ] Under Center, a **VBoxContainer** `Main`. Drag `slot_list.tscn` into it, then add an **HBoxContainer** `Buttons` with the two buttons. Set Buttons' **Alignment** → Center.
- [ ] Drag `settings_menu.tscn` onto **Center** (next to Main, not inside it).
- [ ] Mark every `%` node **Access as Unique Name**.
- [ ] Save as `scenes/ui/slot_screen.tscn`.

### 2. The script

- [ ] Attach `scenes/ui/slot_screen.gd`:

```gdscript
extends Control
## The slot screen, after the title: choose a slot to continue that player's
## game, or an empty slot to start a new one. Also Settings and Quit.

const TITLE_SCREEN := "res://scenes/ui/title_screen.tscn"
const WORLD := "res://scenes/main/main.tscn"


func _ready() -> void:
	GameState.slot = -1  # no playthrough until a slot is chosen
	%SlotList.slot_chosen.connect(_on_slot_chosen)
	%SlotList.cancelled.connect(_back_to_title)
	%Settings.pressed.connect(_on_settings_pressed)
	%SettingsMenu.closed.connect(_on_settings_closed)
	%Quit.pressed.connect(get_tree().quit)
	for button in [%Settings, %Quit]:
		MenuUtil.hover_moves_focus(button)
	%SlotList.open("play")


func _on_slot_chosen(slot: int) -> void:
	if SaveManager.slot_info(slot).is_empty():
		_start_new_game(slot)
	elif SaveManager.load_game(slot):
		get_tree().change_scene_to_file(WORLD)
	else:
		%SlotList.show_message("Slot %d couldn't be read." % (slot + 1))


## A brand new player in an empty slot.
func _start_new_game(slot: int) -> void:
	GameState.reset()
	GameState.slot = slot
	# The new player keeps whatever settings are on screen right now.
	SaveManager.save_settings(slot)
	# TODO(character-creation): name & pronouns, then appearance, go here,
	# before the world loads (GDD: "chosen at game start, before anything else").
	get_tree().change_scene_to_file(WORLD)


func _back_to_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCREEN)


func _on_settings_pressed() -> void:
	%Main.hide()
	%SettingsMenu.open()


func _on_settings_closed() -> void:
	%Main.show()
	%Settings.grab_focus()
```

- **`%SlotList.open("play")`** with no slot given highlights the most recently saved slot, or Slot 1 if there are none.
- **`%Quit.pressed.connect(get_tree().quit)`**: you can connect a signal straight to any function, including Godot's own.
- **There's no question on Quit game.** Nothing is being played, so nothing can be lost.

**Check:**
1. F5, press a key. The slot screen shows, with Slot 1 highlighted. The mouse resting somewhere doesn't move the highlight.
2. Choose an empty **Slot 2**: you're in the world. The save icon flashes (the arrival autosave).
3. Walk a bit, Esc → **Quit to Title** → Yes. Press a key.
4. Slot 2 now reads "Coastal Town · 0m · just now" and has a **Delete** button. It's highlighted, because it's the most recent.
5. Choose it: you're back where it autosaved.
6. Quit to Title again. On the slot screen, **Settings** → text size 2.0 → Esc. The slot screen text is big. Choose an empty **Slot 3** (new game): its text is big too, because a new player keeps the settings on screen.
7. Quit to Title, choose **Slot 2**: its text is back to normal. Each player keeps their own.
8. **Delete** on Slot 3: the question has **No** highlighted. Esc: nothing deleted. Delete → Yes: Slot 3 says "New Game" again.
9. **Esc** on the slot screen: back to the title.
10. **Quit game**: the game closes.

---

## Step 13: The opening cutscene and two-press skip

**Goal:** a cutscene system any cutscene can use, with the skip built in,
and a placeholder opening that plays on New Game.

### The idea

- **For now a cutscene is a list of text cards** over a dark screen.
  That's enough to build and test the skip. The real opening (Moss, the
  road, finding Pip) and the memory cutscenes replace the cards later and
  keep everything else.
- **It's an autoload,** like Dialogue: any script can write
  `Cutscene.play([...])` and then `await Cutscene.finished`. `finished`
  fires whether it played to the end or was skipped, so callers don't care
  which.
- **Cards never move on by themselves.** Enter / Space / A or a click goes
  to the next one. Cards on a timer are a reading-speed problem.
- **Skipping takes two presses,** on its own key: **E** (or **Y** on a
  controller). The first press changes the Skip button to "Press E or click
  again to skip". The second skips. There's no time limit on the second
  press, and **Esc** puts the button back (changed my mind).
- **Skip has its own key, not the "next card" key.** If one key did both,
  a fast reader would skip by accident.
- **Mouse players** get a Skip button in the corner. It also needs two
  clicks.
- **It pauses the game while it plays,** so the world doesn't move behind
  it, and it listens to keys *before* any other screen, so Enter can't
  reach a menu hidden underneath.

### 1. A new input action for skipping

- [ ] **Project → Project Settings → Input Map**. In **Add New Action** type `skip_cutscene`, press **Add**.
- [ ] Click the **+** on its row → press **E** → OK.
- [ ] Click **+** again → in the list, open **Joypad Buttons** and pick **Button 3** (Y on Xbox, Triangle on PlayStation) → OK.

E is also Interact, and Y is also Journal. That's fine: during a cutscene
neither of those can happen, because the cutscene takes every key first.

### 2. Build the scene

```
Cutscene        CanvasLayer
└─ Screen       Control          %
   ├─ Background ColorRect       %
   ├─ Card       Label           %
   ├─ Continue   Label              "Enter or click to continue"
   └─ Skip       Button          %  "Skip (E)"
```

- [ ] **Scene → New Scene → Other Node → CanvasLayer**, renamed `Cutscene`. **Layer** → `8` (over the pause menu's 5, under the save icon's 10). **Process → Mode** → `When Paused`. (Same as the dialogue box: it pauses the game, then keeps running *because* it's paused.)
- [ ] Add a **Control** `Screen`, Full Rect.
- [ ] Under Screen, a **ColorRect** `Background`, Full Rect, nearly black.
- [ ] A **Label** `Card`, Full Rect. **Horizontal** and **Vertical Alignment** → Center. **Autowrap Mode** → `Word (Smart)`. Under **Layout → Transform**, bring the left and right edges in a little (about 60 pixels each side) so long lines wrap before the edges. **Mouse → Filter** → `Ignore`, so clicks pass through to the background.
- [ ] A **Label** `Continue`, anchor **Center Bottom**, Horizontal Alignment Center, a bit above the bottom edge. **Mouse → Filter** → `Ignore`. Under **Visibility → Modulate**, lower the alpha a little so it's quieter than the card.
- [ ] A **Button** `Skip`, anchor **Bottom Right**, nudged in from the corner. **Focus → Mode** → `None`. (Important: otherwise Enter, meant for "next card", would press Skip.)
- [ ] Mark `Screen`, `Background`, `Card` and `Skip` **Access as Unique Name**.
- [ ] Save as `scenes/ui/cutscene.tscn`.

### 3. The script

- [ ] Attach `scenes/ui/cutscene.gd`:

```gdscript
extends CanvasLayer
## Cutscenes: `Cutscene.play(cards)`, then `await Cutscene.finished`.
## Today a cutscene is a list of text cards; real scenes replace the cards
## later and keep everything else (the pause, the two-press skip).
##
## Cards never move on by themselves: Enter / Space / A or a click.
## Skipping takes two presses of `skip_cutscene` (E / Y), or two clicks on
## Skip, so nobody skips by accident. Esc / B changes your mind.

## Sent when the cutscene ends, whether it played out or was skipped.
signal finished

var _cards: Array = []
var _index := 0
var _skip_armed := false  # true after the first skip press


func _ready() -> void:
	%Screen.hide()
	_disarm_skip()
	%Skip.pressed.connect(_on_skip_pressed)
	%Background.gui_input.connect(_on_background_input)


func play(cards: Array) -> void:
	_cards = cards
	_index = 0
	_disarm_skip()
	get_tree().paused = true
	%Screen.show()
	_show_card()


func is_playing() -> bool:
	return %Screen.visible


## `_input`, not `_unhandled_input`: a cutscene sits on top of everything, so
## it hears keys first and keeps them from the screens underneath.
func _input(event: InputEvent) -> void:
	if not is_playing() or event is InputEventMouse:
		return
	get_viewport().set_input_as_handled()  # first, before anything can end us
	if event.is_action_pressed("skip_cutscene"):
		_on_skip_pressed()
	elif event.is_action_pressed("ui_cancel"):
		_disarm_skip()
	elif event.is_action_pressed("ui_accept"):
		_next_card()


func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_next_card()


func _show_card() -> void:
	%Card.text = _cards[_index]


func _next_card() -> void:
	_index += 1
	if _index < _cards.size():
		_show_card()
	else:
		_finish()


func _on_skip_pressed() -> void:
	if _skip_armed:
		_finish()
	else:
		_skip_armed = true
		%Skip.text = "Press %s or click again to skip" % _skip_key()


func _disarm_skip() -> void:
	_skip_armed = false
	%Skip.text = "Skip (%s)" % _skip_key()


func _finish() -> void:
	%Screen.hide()
	get_tree().paused = false
	finished.emit()


## The key skip is actually bound to, so the prompt stays right if the
## player remaps it.
static func _skip_key() -> String:
	for event in InputMap.action_get_events(&"skip_cutscene"):
		if event is InputEventKey:
			return (event as InputEventKey).as_text_physical_keycode()
	return "Skip"
```

- **`_input` vs `_unhandled_input`.** Godot offers each key press to `_input` first (on every node), then to buttons and menus, and only then to `_unhandled_input`. Every other screen in this plan uses `_unhandled_input`. The cutscene uses `_input` and marks *every* key as handled, so nothing underneath ever hears them.
- **`event is InputEventMouse`** lets clicks through to the normal button and background handling: a click on Skip presses Skip, and a click anywhere else reaches `Background`, which moves to the next card.
- **`_skip_key()`** reads which key is bound to `skip_cutscene` in the Input Map, so the text says "E" because the Input Map says E, not because "E" is typed into the code. The interaction hint does the same.
- **`await Cutscene.finished`** (below) pauses the *calling* function until the signal fires, then carries on from that line.

### 4. Make it an autoload, and play it on New Game

- [ ] **Project → Project Settings → Globals → Autoload**. Path: `res://scenes/ui/cutscene.tscn`, Name: `Cutscene`, **Global Variable** ticked. **Add**.
- [ ] In `slot_screen.gd`, add the placeholder opening under the `WORLD` constant:

```gdscript
## Placeholder opening until the real one (Moss, the road, finding Pip).
const OPENING := [
	"On the road to the coast, the ash was still warm.",
	"Something small was glowing in it.",
	"It followed you all the way to the sea.",
]
```

- [ ] In `_start_new_game`, replace the last line (`get_tree().change_scene_to_file(WORLD)`) with:

```gdscript
	%Main.hide()
	Cutscene.play(OPENING)
	await Cutscene.finished
	get_tree().change_scene_to_file(WORLD)
```

Continuing a saved game doesn't play it: you've seen it.

**Check:**
1. F5, a key, choose an empty slot. The first card shows, with "Skip (E)" in the corner.
2. Press **Enter**: next card. Press **Space**: next card. **Click** anywhere but the Skip button: the world loads.
3. Quit to Title, Delete that slot, start a new game again. Press **E** once: the button says "Press E or click again to skip", and the card is still there. Press **Enter**: the next card shows, still waiting for the second E.
4. Press **Esc**: the button goes back to "Skip (E)". Press **E**, then **E** again: you're in the world, and you can move (not paused).
5. Once more with **only the mouse**: click Skip, click it again.
6. Wait on a card for a minute. Nothing moves on by itself.

---

## Step 14: Accessibility pass

No new code unless something fails. Walk the whole flow, **title → slot
screen → new game → cutscene → pause → save → load → settings → quit to
title → continue**, three times:

- [ ] **Mouse only.** Everything can be clicked. Nothing needs a key, including skipping the cutscene.
- [ ] **Keyboard only.** Every screen starts with something highlighted, the arrows move it, Enter presses it, Esc goes back.
- [ ] **Controller only**, if you have one. The same with the D-pad, A and B; Start pauses, Y skips.
- [ ] **One highlight.** Rest the mouse over a button while a screen opens: the highlight stays where the code put it. Then move the mouse: the highlight follows it.
- [ ] **Text size 2.0.** Nothing overflows or gets cut off on any screen. The settings list scrolls.
- [ ] **Two players.** Slot 1 at text size 2.0, Slot 2 at 1.0. Switching between them changes the text each time, and the title screen opens at the size of whoever played last.
- [ ] **Nothing is timed.** No screen moves on by itself. "Saved." stays until you leave. The skip has no time limit. The save icon is just information.
- [ ] **Reduced sensory on:** nothing on these screens flashes or pulses. The save icon disappears without fading.

**The highlight must be visible, and not by colour alone.** Godot's default
highlight is an outline, which already passes: look at any of the
screenshots. If it ever looks too faint against real art, make it stronger
for every menu at once in the theme: open `menu_theme.tres`, in the bottom
**Theme** panel click **+** (Add Type) → `Button`, then on its **Styles**
tab add a `StyleBoxFlat` to **focus**, untick **Draw Center**, and give it a
2-pixel **Border** in a light colour.

If anything here fails and you can't see why, push and tell me which check.

---

## Step 15: Tests and docs

### 1. An automatic save test

This checks the save system by itself, in a second, without you clicking
through anything. Run it whenever you change SaveManager or GameState.

- [ ] Create `tests/save_smoke.gd`:

```gdscript
extends Node
## Headless test for saving and loading:
##
##     godot --headless --path . res://tests/save_smoke.tscn
##
## Saves, changes everything, loads, and checks it all came back. Also a
## broken file, and each slot keeping its own settings. Uses its own folder,
## so your real saves are never touched. Exits 0 on pass, 1 on fail.

const TEST_DIR := "user://saves_test/"

var _failures := 0


func _ready() -> void:
	SaveManager.save_dir = TEST_DIR
	for slot in SaveManager.SLOT_COUNT:
		SaveManager.delete_slot(slot)
	var real_settings := ConfigFile.new()
	var had_last_used := real_settings.load(Settings.LAST_USED) == OK

	_test_round_trip()
	_test_broken_file()
	_test_settings_per_slot()

	for slot in SaveManager.SLOT_COUNT:
		SaveManager.delete_slot(slot)
	if had_last_used:
		real_settings.save(Settings.LAST_USED)  # put your own settings back
	if _failures == 0:
		print("PASS: save smoke test")
	get_tree().quit(1 if _failures > 0 else 0)


## Save, scramble GameState, load: everything is back.
func _test_round_trip() -> void:
	GameState.reset()
	GameState.slot = 0
	GameState.player_position = Vector2(123.5, 456)
	GameState.discovered = {"coastal": {"lighthouse": true}}
	GameState.playtime = 75.0
	_check(SaveManager.save_game(0), "save_game returns true")

	GameState.reset()
	GameState.player_position = Vector2(1, 1)
	_check(SaveManager.load_game(0), "load_game returns true")
	_check(GameState.player_position == Vector2(123.5, 456),
			"position came back as a Vector2 (got %s)" % GameState.player_position)
	_check(GameState.discovered.get("coastal", {}).has("lighthouse"), "discoveries came back")
	_check(is_equal_approx(GameState.playtime, 75.0), "playtime came back")
	_check(GameState.region_id == &"coastal", "region came back")
	_check(not SaveManager.slot_info(0).is_empty(), "slot 0 shows as used")
	_check(SaveManager.slot_info(1).is_empty(), "slot 1 shows as empty")


## Garbage in a save file: load_game says no, and GameState is untouched.
func _test_broken_file() -> void:
	var file := FileAccess.open(SaveManager.save_path(1), FileAccess.WRITE)
	file.store_string("this is not a save file {")
	file.close()
	GameState.player_position = Vector2(9, 9)
	_check(not SaveManager.load_game(1), "a broken file doesn't load")
	_check(GameState.player_position == Vector2(9, 9), "a failed load changes nothing")
	_check(SaveManager.slot_info(1).has("broken"), "a broken file shows as broken")


## Two players on one computer: each slot keeps its own text size.
func _test_settings_per_slot() -> void:
	Settings.text_scale = 2.0
	SaveManager.save_settings(0)
	Settings.text_scale = 1.0
	GameState.slot = 2
	SaveManager.save_game(2)
	SaveManager.save_settings(2)

	SaveManager.load_game(0)
	_check(Settings.text_scale == 2.0, "slot 1 loads its own text size (got %s)" % Settings.text_scale)
	SaveManager.load_game(2)
	_check(Settings.text_scale == 1.0, "slot 3 loads its own text size (got %s)" % Settings.text_scale)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		printerr("FAIL: ", what)
```

- [ ] Make its scene: **Scene → New Scene → Other Node → Node**, rename it `SaveSmoke`, attach `tests/save_smoke.gd` (Load, not Create), save as `tests/save_smoke.tscn`.

**Check:** open `save_smoke.tscn` and press **F6** (run this scene). The
Output panel says **PASS: save smoke test**, and the game window closes by
itself. You'll also see two or three red `ERROR: Parse JSON failed...`
lines. Those are expected: they're the broken-file test doing its job.

To see a test fail on purpose: comment out the `GameState.playtime = ...`
line in `from_dict`, run again. It says `FAIL: playtime came back`. Put the
line back.

**Why there's no automatic menu test:** the menus change scenes, and a test
that survives scene changes is fiddly to write and fiddly to keep working.
For a solo project, step 14's walkthrough is the menu test. Do it again
whenever you change a menu.

### 2. Docs

So these systems can be picked up again months from now:

- [ ] `core/README.md`, add a **Saving** section:
  - GameState is everything a playthrough remembers; SaveManager turns it into `user://saves/slot_N.json` and back. Nothing else writes save files.
  - **How to make a system save:** add a field to GameState (with a comment saying what it is), add a line to `reset()`, add one line each to `to_dict` and `from_dict`. If it's a `Vector2` or `StringName`, convert it like `player_position` and `region_id` do. Run `save_smoke`.
  - **How to add an autosave moment:** `SaveManager.autosave("why")` after the moment happens.
  - Each slot has its own settings file. `Settings.LAST_USED` is what the title and slot screens use.
- [ ] `scenes/ui/README.md`, add a section per screen (title, slot screen, slot list, pause, settings, cutscene), one or two lines each. Plus:
  - **How to add a menu:** use the project theme (automatic), `MenuUtil.set_enabled` and `MenuUtil.hover_moves_focus` for every button, `grab_focus()` on something when it opens, `ui_cancel` goes back, and call `set_input_as_handled()` *before* anything that changes scene.
  - **How to add a cutscene:** `Cutscene.play(["card one", "card two"])`, then `await Cutscene.finished`. Real animated scenes will replace the cards later; the skip and the `finished` signal stay.
  - **How to add a region name to the slot list:** one line in `REGION_NAMES` in `slot_list.gd`.
- [ ] Root `README.md`, Controls table: Pause is no longer *(reserved)*, and add a row **Skip cutscene (press twice) | E | Y**.
- [ ] At the top of this plan, change the status line to **built**.

**Check:** read your README sections as if you've forgotten everything.
Could you add a new saved thing from them alone?

---

## Things that commonly go wrong

| Symptom | Usually |
|---|---|
| Esc does nothing in the world | The pause menu's `CanvasLayer` is *When Paused* instead of *Always*, so it can't hear the key while the world runs |
| Can't press any button with keyboard/controller | No `grab_focus()` when the screen opens |
| Title screen frozen after Quit to Title, or the world frozen after Load | Changed or reloaded the scene before `get_tree().paused = false` |
| Title screen skips itself | Mouse motion or stick drift counted as "any button"; only accept pressed buttons and keys |
| Cutscene skips when the player only meant to read on | Skip and "next card" share a key; give skip its own action |
| Enter on a cutscene presses Skip | The Skip button's Focus Mode isn't `None` |
| "set_input_as_handled" on null / "Cannot call method on a null value" after Esc | `set_input_as_handled()` was called *after* the scene changed; call it first |
| A menu opens with the wrong button highlighted | The mouse was resting there and `mouse_entered` grabbed focus; use `MenuUtil.hover_moves_focus` |
| Arrow keys land on a greyed-out button | Use `MenuUtil.set_enabled`, which also sets Focus Mode to None |
| Menu text doesn't follow Text size | The project theme isn't set in Project Settings → GUI → Theme → Custom, or a node overrides its font size |
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
