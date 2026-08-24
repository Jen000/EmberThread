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

**Goal:** the mouse does what the keyboard does.

This is the fiddliest step in the batch. Read the whole thing before writing
any of it — there's a decision in the middle that changes what you build.

### Decide first: what does an outline promise?

An earlier draft of this plan said hover should highlight an object *at any
distance*. I've changed my mind, and you should make the call knowingly:

- **Outline = "you can do this right now."** Hovering something across the
  room does nothing. One meaning, never a lie. **My recommendation.**
- **Outline = "this is an interactable thing."** Hover lights it up from
  anywhere, but clicking only works up close.

The second option teaches the player that a lit object is sometimes actionable
and sometimes not, and the only way to tell is to try. That's a small
frustration repeated hundreds of times, which is the opposite of cozy. It's
also worse for anyone relying on the visual cue rather than a sense of
distance.

Everything below assumes the first. If you pick the second, drop the reach
check from the hover path only — the click path keeps it either way.

### The Godot part

`Interactable` is an `Area2D`, and an `Area2D` can receive mouse events
directly once you turn them on. In `_ready()`:

```gdscript
input_pickable = true
```

That gives you three signals to connect, same `.connect()` syntax as step 4:

| Signal | Fires when | Note |
|---|---|---|
| `mouse_entered` | cursor moves onto its collision shape | no arguments |
| `mouse_exited` | cursor moves off | no arguments |
| `input_event` | any input over it | see below |

`input_event` hands you three things —
`(viewport: Node, event: InputEvent, shape_idx: int)` — and it fires for
**mouse motion too**, not just clicks. So the first thing your handler does is
filter:

```gdscript
if event is InputEventMouseButton \
        and event.button_index == MOUSE_BUTTON_LEFT \
        and event.pressed:
```

Without that filter you'll fire the interaction on every pixel of cursor
movement across the object.

### Answering "is the player close enough?"

The object shouldn't work this out — the player's sensor already knows. Give
`InteractionSensor` a small public method (in
`scenes/interactable/interaction_sensor.gd`):

```gdscript
## True while this interactable is within the player's reach.
func is_in_reach(interactable: Interactable) -> bool:
	return interactable in get_overlapping_areas()
```

Three lines, and it means `Interactable` never has to know how reach is
measured. If reach later becomes a cone, or ignores things behind walls, one
function changes and nothing else does.

To find the sensor, `Interactable` needs to find the player. Nothing is in a
`player` group yet — add one line to `player.gd`'s `_ready()`:

```gdscript
add_to_group(&"player")
```

exactly like `Sensable` does with `pip_sensable`. Then
`get_tree().get_first_node_in_group("player")` finds it from anywhere.

### The bit that will actually trip you

**Two independent things now want the highlight on:** walking near it, and
pointing at it. They can turn on and off in any order. The classic bug is
hover-off switching the outline off while the player is still standing right
next to the object.

Do not try to fix that with cleverness in the handlers. Track the two reasons
separately and derive the answer:

```gdscript
var _focused := false      # the sensor picked me
var _hovered := false      # the cursor is on me

func _refresh_highlight() -> void:
	if _highlight != null:
		_highlight.set_shown(_focused or _hovered)
```

Each handler sets its own flag and calls `_refresh_highlight()`. Neither one
ever calls `set_shown` directly. Add a third reason later — a quest marker,
Pip pointing at something — and it's one more flag in the same `or`.

**This changes what you wrote in step 4.** There, `focus_changed` connected
straight to `highlight.set_shown`. Now that there are two sources, that
connection has to go: keep the loop that finds the `Highlight` child, but
store it in a `_highlight` variable instead of connecting it, and have
`set_focused()` set `_focused` and call `_refresh_highlight()`.

That isn't wasted work — step 4 was the simplest thing that worked, and it
worked. This is what adding a second reason costs, and it's the normal shape
of that change.

### Two more traps

**Hover fires through the dialogue box unless you stop it.** Once step 6
exists, a `Control` sitting over the world will block mouse events only if its
`mouse_filter` is `Stop`. The stub sets `Root` to `Ignore` deliberately so the
world stays clickable — but the `Frame` itself should stop clicks, or players
will interact with objects *through* the text box.

**Keyboard and mouse must not double-fire.** The sensor's `_unhandled_input`
handles `interact`; `input_event` handles clicks. They're separate paths, so a
click can't trigger both — provided you removed the mouse button from the
`interact` action back in step 2. If you skipped that, a click fires the
focused object *and* the clicked object.

### Check

1. Hover an object across the room — nothing (with my recommendation).
2. Walk close, hover it — outline on. Move the cursor off while standing
   still — outline **stays**, because you're still in range.
3. Walk away with the cursor still on it — outline off.
4. Click it while in range — it fires. Click it from across the room —
   nothing.
5. E still works, and one click never fires two interactions.

Test 2 is the one that catches the bug this step is really about.

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

The API detail is in TODOs 6–12 in `scenes/ui/dialogue_box.gd`. What follows
is the shape those TODOs add up to, which is easier to hold in your head than
twelve numbered instructions.

### The box is only ever in one of two states

```
        say()                    reveal finishes
  closed ────> REVEALING ──────────────────────> WAITING
                  │  press: finish this line now      │
                  └──────────<───────────────────────-┘
                                                      │ press: next line
                                            ┌─────────┴─────────┐
                                      more lines?           that was the last
                                            │                   │
                                       REVEALING             _close()
```

Every bug in a dialogue box is a state confusion: input arriving in the wrong
state, or a state you forgot to leave. If you keep asking "which of the two am
I in, and what does a press mean here?", the whole thing stays simple.

### The typewriter is one property

`RichTextLabel` has `visible_ratio` — a number from 0 to 1 for how much of the
text is drawn. You don't touch the string at all: set the full text, set
`visible_ratio = 0.0`, and tween it to 1.0. Same `tween_property` you used in
the highlight, so this is familiar ground.

Duration comes from the line's length divided by `reveal_speed`, not a fixed
number. That's what keeps a long line from crawling and a two-word line from
flashing past — the *speed* stays constant and the duration varies.

### The rule that makes it feel good

**A press during REVEALING completes the line. It does not skip it.**

Someone pressing the key mid-reveal wants the rest of the sentence *now* —
they haven't read it yet. Skipping to the next line loses text they never saw,
and they can't go back. Getting this backwards is the most irritating bug in
game dialogue, and it's four lines to get right: kill the tween, set
`visible_ratio = 1.0`, show the continue arrow, return.

### The bug you will hit

The press that *opens* the box also advances its first line, so short lines
appear to be skipped entirely. It happens because the box begins existing
part-way through a press and then sees that same press.

Record `Engine.get_process_frames()` in `say()`, and in the input handler
ignore anything arriving on that same frame. TODO 12 has it written out. Read
it **before** you write the handler — it's far more annoying to diagnose than
to prevent, because it only shows on short lines and looks like a text bug.

### Pause is already handled, if you did step 6 right

`get_tree().paused = true` in `say()` stops the player, Pip and the sensor.
The box keeps running only because its root has `process_mode = When Paused`.
If the game freezes with a dead box on screen, that setting is the first thing
to check — it's not a crash.

Unpause in `_close()` **before** emitting `finished`, or anything listening
(a memory cutscene, later) starts up into a still-paused tree.

### Check

1. Three lines. Advance all three with E, then again with clicks.
2. The player can't walk while it's open, and Pip stops drifting.
3. Press mid-reveal: the line **completes**. Press again: it advances.
4. Give it a one-word line. It must not vanish instantly — that's the
   frame-guard bug, and a short line is the only place it shows.
5. After the last line the world moves again. Walk around to be sure.

### Done looks like

`Dialogue.say("", ["one", "two"])` from anywhere in the game opens a box,
reads properly, closes cleanly, and leaves the world running. Nothing else in
the project needed to know it exists.

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
