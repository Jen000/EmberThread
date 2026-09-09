# Interaction triggers

Talking to an NPC, reading a sign, shaking a tree, opening a door, starting a
mend — from the code's point of view these are all the same three questions:

1. **What's near me?** → an `Area2D` on the object (`interactable.gd`)
2. **Which one do I mean?** → an `Area2D` on the player (`interaction_sensor.gd`)
3. **What happens?** → *not this system's business.* It emits a signal and
   whoever owns the object decides.

Question 3 is the important one. The moment an interaction component knows
what a sign is, it will want to know what a tree is, and then a door, and
soon it's a 400-line file with a `match type:` in the middle of it. Keeping
"what happened" outside means signs, NPCs, trees and mending objects all
share one small component that never grows.

## The pieces

```
scenes/interactable/
  interactable.gd          the trigger — goes on the object
  interaction_sensor.gd    the finder — lives on the Player (already wired)
scenes/player/player.tscn  Player > InteractionSensor        <- added here
scenes/main/test_room.gd   the worked example's response     <- start here
project.godot              [layer_names] physics layer 3 = "interactable"
```

## How a press flows

```
      walk into range                 press E / Space / A
             │                                 │
   InteractionSensor._physics_process   InteractionSensor._unhandled_input
             │                                 │
   picks the best target                target.interact(player)
             │                                 │
   target.set_focused(true)             emits  interacted(player)
             │                                 │
  outline + "[E] Read" hint      test_room.gd._on_signpost_read()  ← your code
```

The sensor is the **only** place in the game that turns a button press into an
interaction. If interactions ever feel wrong — too far, too fussy, wrong
object picked — there is one file to open.

## Try it

Run the project and walk up to the signpost. It outlines, an `[E] Read` hint
floats above it, and pressing E opens the dialogue box. The lantern opens the
mending screen; the fisherman talks, with a portrait. Then read
`scenes/main/test_room.gd` — each response is one line.

## `Interactable` — the trigger

Attach `interactable.gd` to an `Area2D`. That's the whole setup; it gives
itself a collision shape at runtime, so there is nothing to forget. Add a
`Highlight` child if it should outline on approach.

| Property | Default | Meaning |
|---|---|---|
| `prompt_verb` | `"Look"` | The verb the hint shows — `"Talk"`, `"Read"`, `"Mend"`. The key name comes from the current binding; never type "E" yourself |
| `radius` | `16.0` | Reach in pixels. Ignored if you add your own `CollisionShape2D` child |
| `active` | `true` | Dormant = no hint, no highlight, no signal. Story gating and "already done" both use this |
| `hint_offset` | `(0, -24)` | How high the hint floats. Origins are at the feet, so roughly the object's height plus clearance |

| Signal | When |
|---|---|
| `interacted(interactor)` | The player pressed the button on it. `interactor` is the Player node |
| `focus_changed(focused)` | It became / stopped being the thing you'd hit — for a highlight, a sound, Pip reacting |

```gdscript
interactable.set_active(false)   # story hasn't opened this yet
```

**Saying something is not this component's job.** `interacted` is announced;
what happens next lives wherever the object does. In the test room that's
`test_room.gd`, calling `Dialogue.say(...)` or `MendScreen.open(...)` — see
`scenes/ui/README.md`.

## `InteractionSensor` — picking the right target

Already on the Player; you shouldn't need to touch it, but two knobs decide
how targeting *feels*:

| Property | Default | Meaning |
|---|---|---|
| `radius` | `14.0` | The player's reach. Add the object's own radius for total range (~2 tiles) |
| `facing_bias` | `0.8` | How much facing beats distance. `0.0` = pure nearest-wins |
| `behind_cutoff` | `-0.35` | Anything further behind you than this is ignored |

Nearest-wins alone feels bad as soon as two things sit side by side — you face
the sign, the game opens the barrel. So the score is `distance − alignment ×
bias`, and things clearly behind you don't count at all. Tune it while
playing, not on paper.

It also exposes `focused` (the current target or `null`), plus
`focus_changed` and `interacted` signals if you ever want one global hook —
autosave on interaction, say.

---

# Walkthrough: add an NPC you can talk to

Everything below is you, not me. It's the same shape every time.

**1. Make the node.** In the test room, add a child `Area2D`, name it
`Fisherman`, drag `interactable.gd` onto its Script property. Set
`prompt_verb` to `Talk` in the inspector.

**2. Give it a body.** Add a `Polygon2D` child so you can see it (block
placeholder — the art pipeline says NPCs stay blocks until real art lands).
Copy the signpost's if you like.

**3. Give it something to say.** In `test_room.gd`:

```gdscript
@onready var _fisherman: Interactable = $Fisherman

func _ready() -> void:
    _signpost.interacted.connect(_on_signpost_read)
    _fisherman.interacted.connect(_on_fisherman_talk)

func _on_fisherman_talk(_interactor: Node2D) -> void:
    Dialogue.say("fisherman", ["Hmph. That light of yours."])
```

**4. Play it.** Walk up. Prompt appears. Press E.

**5. Now make it remember you.** The GDD gives most townsfolk a V1 / V2 / V3 /
Return arc — the fisherman grumbles, then asks what Pip eats, then leaves a
fish out. Add a counter:

```gdscript
var _fisherman_visits := 0

const FISHERMAN_LINES := [
    "Hmph. That light of yours.",
    "...what does it eat, anyway?",
    "Left a bit of the catch out. Don't read into it.",
]

func _on_fisherman_talk(_interactor: Node2D) -> void:
    var line: String = FISHERMAN_LINES[mini(_fisherman_visits, FISHERMAN_LINES.size() - 1)]
    _fisherman_visits += 1
    Dialogue.say("fisherman", [line])
```

That counter belongs in a save file eventually, not in the room script — see
*Things to think about* below. Getting it working here first is the right
order.

---

# Your turn: shake a tree

A tree is a different shape of interaction from a sign: it changes something
in the world, and it shouldn't be spammable. Try it before reading the hints.

**Decide first** (these are design questions, not code questions):

- Does shaking give anything, or is it just lovely? *Cozy first* says a tree
  that gives nothing but a sound and some leaves is completely fine.
- Can you shake it again immediately? A cooldown is kinder than a hard "no" —
  and remember *gentle failures, not punishments*: an empty tree should say
  something warm, not buzz at you.
- Does Pip react? `focus_changed` is right there.

**Hints.** Put the response on the tree itself this time — a small script on
the `Area2D`, extending `Interactable`, so the tree owns its own behaviour:

```gdscript
extends Interactable

@export var shake_cooldown := 3.0
var _ready_at := 0.0

func _ready() -> void:
    super()                      # <- easy to forget; the base sets everything up
    interacted.connect(_on_shaken)

func _on_shaken(_interactor: Node2D) -> void:
    if Time.get_ticks_msec() / 1000.0 < _ready_at:
        Dialogue.say("", ["Still settling."])
        return
    _ready_at = Time.get_ticks_msec() / 1000.0 + shake_cooldown
    _shake()
    Dialogue.say("", ["A few leaves come loose."])

func _shake() -> void:
    var visual := $Visual
    var start := visual.position
    var tween := create_tween()
    for i in 3:
        tween.tween_property(visual, "position", start + Vector2(1.5, 0), 0.05)
        tween.tween_property(visual, "position", start - Vector2(1.5, 0), 0.05)
    tween.tween_property(visual, "position", start, 0.05)
```

Two ways to hold behaviour, and both are correct — connect from the parent
scene (the signpost, simple one-offs) or extend `Interactable` (the tree,
anything with its own state). Prefer the first until the object clearly owns
something.

---

# Gotchas

These are the ones that cost an evening:

- **An `Area2D` is not solid.** Walking through your sign is not a bug in this
  system. Add a `StaticBody2D` + `CollisionShape2D` child for solidity — the
  test-room signpost has one (`Signpost/Solid`), copy that.
- **Layers must match.** Interactables are on physics layer 3
  (`Interactable.INTERACTABLE_LAYER`), the sensor masks layer 3. Both are set
  in code so the inspector can't drift out of sync. If you hand-build an
  `Area2D` without the script, the sensor will never see it.
- **No shape = silence.** An `Area2D` with no collision shape never triggers
  anything, with no error. Both scripts build one for you; if you add your own
  child shape, yours wins.
- **`_unhandled_input`, not `_input`.** UI that opens later (dialogue,
  journal, pouch) gets first refusal on the press just by existing. If you
  ever handle `interact` in a `_input`, you'll swallow it everywhere.
- **One press, two actions.** When dialogue is wired up, the press that opens
  the box must not also advance its first line. The sensor calls
  `set_input_as_handled()`, which is half the answer; the box should open on
  the *release* or ignore input for one frame.
- **Pausing.** When the world pauses (dialogue, journal), the sensor stops
  with everything else, which is what you want. The UI doing the pausing needs
  `process_mode = WHEN_PAUSED` on itself.
- **`facing` is the player's last movement direction**, set in `player.gd`.
  Standing still keeps the last one, so targeting doesn't drift while idle.

# Things to think about (not built yet)

- **Where does NPC state live?** Visit counts, "already mended", "already
  read" — these need to survive a reload. A small `GameState` autoload
  (`core/`) holding a dictionary keyed by a stable NPC id, saved with the save
  system, is the simple path. Doing that *before* there are twelve NPCs is
  much cheaper than after.
- **Autosave** fires on NPC interactions per the brief — the sensor's own
  `interacted` signal is the one hook that sees every interaction.
- **Interactable + Sensable on one object.** A mending object is both: Pip
  senses it from across the room (`sensable.gd`) *and* you press a button on
  it (`interactable.gd`). Two Area2D/Node2D children under one parent, no
  special-casing needed.
- **Prompt during overwhelm.** When Pip is distressed, is the world still
  offering you `[E] Talk` on a market trader? Possibly it shouldn't be, or
  should be quieter. `active` is the switch if you decide it matters.
- **Controller glyphs.** The prompt shows the bound *keyboard* key. Showing a
  pad glyph when a pad was last used is a small addition to
  `Interactable.input_hint()` when you get to controller polish.
- **Keyboard layouts.** `input_hint()` reports the physical key, which reads
  as `E` on QWERTY and `E` where AZERTY players expect `E` too — but a
  non-Latin layout will want `DisplayServer.keyboard_get_keycode_from_physical`.
  A remapping screen makes this mostly moot.
- **Art.** Prompts and highlights are UI, so they route through the asset
  registry when real art lands — no hardcoded paths, same rule as everything
  else.

# Test

```
godot --headless --path . res://tests/interaction_smoke.tscn
```

Drives the real main scene: walks the player to the signpost, checks the
prompt focuses, fires `interact`, checks the signal arrives, then walks away
and checks focus clears. Exits 0 on pass, 1 on fail.
