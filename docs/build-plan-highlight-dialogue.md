# Build plan — highlight, click-to-interact, dialogue box

You're building this one; I've written the shader, the stubs and this plan,
and I'll review when you push.

**What you're making.** Walk near an object → it gets a soft outline. Press E
or click it → a box slides up at the bottom with the text. Replaces the
floating `[E] Read` label, which is going away entirely.

**Order matters.** Each step ends with something you can run. Don't move on
until the check passes — the middle steps are much harder to debug in a pile.

---

## Decisions to make first

Three of these I'd answer a particular way; the last one is genuinely yours.

**Which key?** **E.** Already bound, standard for top-down RPGs, and it keeps
Space free. Do *not* use Space for interact: Space and Enter should advance
dialogue, and if the same key opens the box and advances it, short lines look
like they get skipped. Different keys make that class of bug impossible
instead of merely fixed.

**Can the mouse reach across the room?** No — clicking only works on objects
already in reach, same as the keyboard. Clicking a distant object to walk
there is click-to-move, a genuinely large feature (pathfinding around the
crates, cancelling, controller parity) and not one you need. Hovering
highlights, clicking interacts, both within reach.

**Keep `prompt_verb` now that nothing draws it?** I'd keep it. A pure outline
tells you *that* something is interactable, never *what will happen* — the
difference between "Talk" and "Take" matters, and a low-vision player leans on
the words. Sensible home for it later: a short line at the top of the frame,
or a small HUD hint. Keep the data, drop the floating label.

**Does the outline pulse?** Yours. A steady outline is calmer and cheaper; a
slow breath draws the eye. If you pulse it, it must go steady under
`Settings.reduced_sensory` — that flag exists precisely for this.

---

## Step 1 — Delete the floating prompt

**Goal:** clear the old approach out before building the new one, so you're
never debugging both.

In `scenes/interactable/interactable.gd`, delete:

- `BASE_FONT_SIZE`, `PROMPT_COLOR`, `prompt_offset`, `_label`, `_message_time`
- `show_message()`, `_process()`, `_build_label()`, `_apply_text_scale()`,
  `_refresh_label()`, `_set_label()`, `_position_label()`, `input_hint()`
- the `set_process(false)` and `Settings.changed.connect(...)` lines in `_ready()`
- the `_refresh_label()` call in the `active` setter

**Keep** `interacted`, `focus_changed`, `set_focused()`, `interact()`,
`active`, `radius`, `prompt_verb`, `_ensure_shape()`, and the layer constant.
What's left should be about 60 lines that only announce and emit.

`scenes/main/test_room.gd` calls `show_message()` and will break. Comment out
`_on_signpost_read`'s body with a `# TODO: Dialogue.say` for now — step 8
fills it in.

**Check:** project runs, walking near the signpost does nothing visible, no
errors in the Output panel.

---

## Step 2 — Fix the mouse binding

**Goal:** stop left-click meaning "interact" everywhere on screen.

Left mouse is currently bound to the `interact` action in `project.godot`,
which means clicking anywhere at all fires the focused object — click the sky,
read the sign. Fine when the mouse was an afterthought, wrong now that you
want to click the object itself.

Project Settings → Input Map → `interact` → remove the mouse button event.
Leave E, Space and the pad button. Clicks get handled per-object in step 5.

**Check:** clicking empty ground does nothing; E still works.

---

## Step 3 — Build the highlight

**Goal:** objects outline when focused.

Stub: `scenes/interactable/highlight.gd`. Read its header first — there's a
Godot vocabulary section, then the two-paths explanation, then six TODOs.
TODO 1 is filled in as a worked example; 2–6 are yours, each with the exact
API calls and how to check it.

Shader: `shaders/outline.gdshader`, written and tested, no edits needed.
Its uniforms are `outline_color`, `thickness`, `alpha_threshold` and
`strength`. You drive `strength` (0→1) and leave the rest at defaults.

**Adding the node** (editor, not code): right-click `Signpost` in the Scene
dock → Add Child Node → search "Node" → plain `Node` → rename it `Highlight`
→ with it selected, drag `highlight.gd` from the FileSystem dock onto the
Inspector's Script property.

Watch for: each node needs its **own** `ShaderMaterial` instance. Share one
and every object in the room lights up together.

**Check:** temporarily call `set_shown(true)` in `_ready()` on the signpost's
highlight. Both the post and the board should brighten together — the
Polygon2D fallback path, because the shader does nothing on an untextured
polygon. To see the real shader path, add a `Sprite2D` to the test room, set
its Texture to any PNG under `assets/sprites/`, and put a `Highlight` under
that instead.

---

## Step 4 — Connect highlight to focus

**Goal:** the highlight follows the player instead of needing the debug key.

### What a signal is

A signal is an announcement a node makes. It doesn't know or care who's
listening — it just says "this happened" and carries on. Other nodes
*connect* to it, and when it fires, their function runs.

That's how the pieces stay independent. `Interactable` announces "I'm the
thing you'd press now"; it has no idea a `Highlight` exists. `Highlight`
knows how to draw an outline and nothing about interaction. Step 4 is the one
line that introduces them.

### What already works

Everything except the introduction:

```
you walk near the signpost
  └─ InteractionSensor._physics_process picks it as the best target
      └─ calls signpost.set_focused(true)
          └─ Interactable emits  focus_changed(true)
              └─ ...nothing is listening.        ← step 4 is here
```

`Highlight.set_shown(value: bool)` is already the right shape to receive it:
`focus_changed` carries one `bool`, `set_shown` takes one `bool`. They match,
so they can be wired straight together with no glue in between.

### What to write

In **`scenes/interactable/interactable.gd`**, at the end of `_ready()`: look
through your own children for a `Highlight`, and if there is one, connect the
signal to its `set_shown`.

The connect syntax is `<signal>.connect(<function>)`:

```gdscript
focus_changed.connect(some_highlight.set_shown)
```

**`set_shown` with no brackets after it.** That's the whole trick, and it's
the thing everyone gets wrong the first time. With brackets you'd be *calling*
the function right now and handing the signal its return value. Without them,
you're handing over the function itself, to be called later. Godot calls that
a `Callable`.

To find the child, loop `get_children()` and test with `is Highlight`, the
same way `_find_visuals()` does in `highlight.gd`. Don't look it up by the
name "Highlight" — then renaming the node in the editor silently breaks it.

Guard for there being no `Highlight` at all. Most interactables won't have
one, and `focus_changed` firing with nothing listening is perfectly fine.

### The ordering question, since it usually comes up here

`Highlight._ready()` runs **before** `Interactable._ready()` — children are
always ready before their parent. That's exactly what you want: by the time
`Interactable` goes looking, the `Highlight` has already built its materials
and remembered the block colours. It's ready to be called.

### Isn't this Interactable "knowing about" something?

Slightly, and it's worth being clear about where the line is. The rule this
project follows is that `Interactable` must not know **what happens when you
press it** — that's what keeps signs, trees and NPCs sharing one component.
Showing that it's *focusable* is a different thing: `focus_changed` exists for
no other reason. Wiring an optional presentation child is fair game.

If it ever stops feeling that way — say three different things want to react
to focus — move the wiring out to whoever owns the scene, exactly like
`test_room.gd` does with `interacted`.

### Check

1. Walk up to the signpost. Both blocks brighten. Walk away — they go back.
2. Turn your back while standing next to it. Highlight goes out. That's
   `behind_cutoff` in the sensor, and it's the clearest proof the whole chain
   is live rather than just proximity.
3. Walk to the lantern. It gets the outline instead of the tint.
4. Walk the line between them without stopping. Only one should be lit at a
   time. If they flicker as you pass, raise `fade_time` on the Highlight.

### Then clean up

Delete `_toggle_highlights()` and the `KEY_5` branch from
`scenes/main/test_room.gd`, and take key 5 out of the header comment. It was
scaffolding for step 3, and leaving dead debug paths around is how a test room
turns into a haunted house.

---

## Step 5 — Mouse hover and click

**Goal:** the mouse does what the keyboard does, within reach.

`Interactable` is an `Area2D`, so it gets mouse events for free once
`input_pickable = true`. In `_ready()`, set that and connect three signals:

```gdscript
mouse_entered  -> highlight on   (hover, even before you're in range)
mouse_exited   -> highlight off  (unless the sensor still has focus — careful)
input_event    -> on a left-click press, call interact() IF in range
```

"IF in range" is the fiddly bit. The object shouldn't decide; ask the player's
sensor whether it currently has this object in reach. Simplest honest version:
`get_tree().get_first_node_in_group("player")` → its sensor → is this in
`get_overlapping_areas()`. The Player isn't in a group yet — add it to
`&"player"` in `player.gd:_ready()` the way Pip does with `&"pip"`.

The hover/focus interaction is where you'll trip: two independent sources now
want the highlight on. Track them separately (`_hovered`, `_focused`) and show
the outline when *either* is true, rather than letting the second one to
change state turn it off.

**Check:** hover a far object — outlines, click does nothing. Walk close —
click opens it. Keyboard still works. Move the mouse away while standing
close — outline stays (you're still in range).

---

## Step 6 — Build the dialogue box scene

**Goal:** a box exists and can be shown by hand.

Stub: `scenes/ui/dialogue_box.gd` — its header walks the scene build node by
node, with the anchor presets and inspector settings spelled out, then the
twelve TODOs.

Build `scenes/ui/dialogue_box.tscn` to that structure, then register it as an
autoload named `Dialogue` (Project Settings → Globals → Autoload → point at
the **scene**, not the script — a CanvasLayer autoload is a scene autoload).

Set `process_mode = When Paused` on the root **in the scene**, not in code.
Miss it and the box pauses itself along with the world, and the game hangs
with a frozen box on screen. It looks like a crash and isn't.

Art seam, the reason this is worth doing before the artist finishes: the
`NinePatchRect` texture comes from `AssetRegistry.get_sprite("ui_dialogue_box")`
and the portrait from `AssetRegistry.get_portrait(speaker_id)`. When either
returns null, fall back to a drawn box / hidden portrait. Their PNG then lands
in `assets/ui/dialogue/` and appears with no code edit.

**Check:** call `Dialogue.say("", ["Testing."])` from anywhere. Box appears.
It won't advance yet.

---

## Step 7 — Reveal, advance, close

**Goal:** it behaves like a dialogue box.

TODOs 6–12 in the stub. Typewriter reveal via the `RichTextLabel`'s
`visible_ratio`, advance on `interact` / left-click, close after the last
line, unpause, emit `finished`.

TODO 12 describes the one bug you will definitely hit (the opening press also
advancing the first line) and how to kill it. Read it *before* you write the
input handler; it's much more annoying to diagnose than to prevent.

**Check:** three lines, advance through all three with E, then with clicks.
The player can't walk while it's open. Mashing the key doesn't skip a line —
it completes the reveal, then advances.

---

## Step 8 — Wire the signpost

**Goal:** the loop closes.

`test_room.gd:29` becomes `Dialogue.say("", [...])`. Add the fisherman NPC
from the interactable README with a real `speaker_id` so you exercise the
portrait path (there's no portrait file yet — confirm it degrades quietly
rather than erroring).

**Check:** walk up, outline; press E, box; read it, closes; walk on.
That's the feature.

---

## Step 9 — Accessibility pass

Not optional and not a later task:

- Box text size derives from `Settings.text_scale`, like the old prompt did.
  Set it to 2.0 and confirm the text still fits its box — this is exactly the
  bug that ships in real games.
- Reveal speed needs to be adjustable or skippable; "adjustable game speed" is
  on the required list and text speed is part of it.
- Outline colour must not be the only signal. It isn't — presence/absence is
  the signal and that survives any colourblindness — but don't add a
  colour-coded highlight later (gold = talk, blue = mend) without a second cue.
- The world pausing during dialogue is itself an accessibility feature. Keep it.

---

## Step 10 — Tests and docs

`tests/interaction_smoke.gd` still passes as-is (it tests focus and the
signal, not the label). Add to it, or write a sibling test:

- highlight `is_shown()` true on approach, false when facing away
- `Dialogue.say(...)` sets `is_open`, advance closes it, `finished` fires
- the tree is actually paused while open

```
godot --headless --path . res://tests/interaction_smoke.tscn
```

Then update `scenes/interactable/README.md` — the prompt-label sections and
the `show_message` references are wrong once step 1 lands.

---

## To send your artist

They can start now; nothing here waits on code.

| Asset | Size | Notes |
|---|---|---|
| `ui_dialogue_box.png` | 480×76 at native res | 9-slice: corners fixed, edges stretch. Tell me the margins and I'll set them. Full-width bottom anchor |
| `ui_dialogue_arrow.png` | ~8×8 | "Continue" indicator, bottom-right |
| `npc_<name>_portrait.png` | 64×64 | Locked by art-pipeline.md §2 |

One request that's easy to honour now and expensive to retrofit: **leave 1px
of empty space around any sprite meant to be highlighted.** The outline is
drawn inside the sprite's own rectangle, so art running to the edge of its
frame gets its outline clipped on that side. Worth adding to
`docs/art-pipeline.md` while they're still working.

The whole box is 76px tall on a 270px screen — over a quarter of the vertical
view. Worth sketching against a real screenshot before they commit, because
64×64 portraits are what forces that height, and shrinking the portrait later
means re-cutting every character.

---

## Where to ask for help

Push whatever you have, even half-done, and I'll review it. The two places I'd
expect to get stuck: the hover/focus double-source in step 5, and the
pause/process-mode interaction in step 6. Both are more confusing than hard.
