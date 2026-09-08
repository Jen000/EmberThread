# scenes/ui/ — screen-space systems

Three pieces, all driven by the interaction system in `scenes/interactable/`
and none of which that system knows about. They listen; they are never called
into by the objects themselves.

| File | What it is | How it's reached |
|---|---|---|
| `dialogue_box.tscn/.gd` | Bottom text box, portrait, typewriter | Autoload `Dialogue` |
| `mend_screen.tscn/.gd` | Full-screen mending surface (a shell so far) | Autoload `MendScreen` |
| `interaction_hint.gd` | "[E] Talk" floating over the focused object | Node in `main.tscn` → `UI` |

Both autoloads are registered as **scenes**, not scripts — pointing an
autoload at the `.gd` gives you a bare node with no children and every
`@onready` comes back null.

## Dialogue

```gdscript
Dialogue.say("fisherman", ["Hmph. That light of yours."])
Dialogue.say("", ["Harbour, down the hill."])     # no speaker, no portrait
await Dialogue.finished
```

`speaker_id` is an AssetRegistry portrait key: `"fisherman"` resolves to
`assets/portraits/npc_fisherman_portrait.png` (64×64, locked). No file yet →
the portrait hides and the box still reads. **Adding a portrait is dropping a
correctly-named PNG in that folder** — there is no registration step.

Pauses the world while open. Advance with `interact` or a left click; a press
mid-reveal completes the line rather than skipping it.

## MendScreen

```gdscript
MendScreen.open("Sable's cracked lantern")
await MendScreen.closed                # closed(completed: bool)
```

**Currently a shell**: it opens, dims the world, pauses, and closes on the X
or Escape. Nothing mends yet. It exists so the way in and out is proven before
any technique is built on top.

What belongs inside later (GDD, build step 4): eleven techniques, each unique
to its object — heat sealing, threading, breathing rhythm, piecing. They share
this frame: Pip lands on the object as the signal, the world dims and quiets,
a gentle prompt introduces each technique the first time, and it ends on a
soft chime into a memory cutscene.

Two design rules constrain whatever goes in: **cozy first** (no timers, no
fail states, no mashing) and **gentle failures, not punishments**.

`closed` already carries a `completed` flag, false for now, so the journal,
gratitude and autosave hooks can be written against the right shape today.

## InteractionHint

No API — it wires itself up. On ready it finds the player's
`InteractionSensor` and listens to `focus_changed`, then floats
`"[<key>] <verb>"` above whatever is focused.

Per-object knobs live on the `Interactable`:

| Property | Meaning |
|---|---|
| `prompt_verb` | The word shown — `"Talk"`, `"Read"`, `"Mend"` |
| `hint_offset` | How high above the origin it floats. Origins are at the feet, so this is roughly the object's height plus clearance: `-24` for a 16px lantern, `-46` for a 32px NPC |

Switched off with `Settings.interaction_hints` (the settings menu is pending;
the flag is live now). It also hides itself whenever the tree is paused, which
covers every full-screen UI without needing to know any of them exist.

The key in `"[E] Talk"` is read from the current `interact` binding, so it
stays correct after remapping — never hardcode `E`.

## Adding a new full-screen UI

1. `CanvasLayer` root, `layer` above 1 so it covers the HUD (MendScreen uses 20).
2. **`process_mode = When Paused`** on the root, set in the Inspector. Miss it
   and the screen pauses itself along with the world — the game appears to
   freeze and looks exactly like a crash.
3. Register the `.tscn` as an autoload if anything anywhere should be able to
   open it.
4. Guard the opening press: record `Engine.get_process_frames()` in `open()`
   and ignore input on that frame, or the press that opened it also closes it.
5. Font sizes from `BASE_FONT_SIZE * Settings.text_scale`, reapplied on
   `Settings.changed`. A size set in the scene cannot respond to the slider,
   and adjustable text is a required accessibility option.
