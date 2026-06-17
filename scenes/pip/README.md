# Pip

The emotional heart of the game: a tiny floating **glowing orb** who chose
to follow the player. (Pip's detailed character look lives in a dialogue
portrait, not the in-world sprite.) Two independent axes, per the GDD — a
movement state machine and an emotion (glow) language. Movement is
communication (design principle 9); colour is never the only signal.

## In-world visual (orb)

A soft round `Sprite2D` core (`Body/Orb`, a 16px radial dot) plus a
`PointLight2D` (`Body/Light`) for the glow falloff — no detailed sprite,
no shader. `_update_glow()` drives both each frame: the orb's `modulate`
and the light's `color` take the current emotion colour; a gentle sine
"breathes" the orb scale/alpha and the light energy while idle. The whole
`Body` bobs so Pip is always slightly airborne, never grounded.

## Movement states (`Pip.MoveState`)

| State | Reads as | Behaviour |
|---|---|---|
| `FOLLOW` | calm, connected | floats at the player's quieter side (flips with facing), smooth drift + gentle bob; scans for sensable objects |
| `NOTICING` | "oh!" | brief hold (~0.45s): stronger glow pulse, turns curious-green, leans toward what was sensed, then leads |
| `LEADING` | eager, pulling ahead | sits `lead_distance` ahead of the player on the line to the object (never past it), tracked tightly so a full-speed player can't outrun Pip; tilts forward; hovers over the object on arrival and emits `reached_object` |
| `DISTRESSED` | jagged, withdrawn | retreats `retreat_distance` away from the player with erratic jitter, faster snappier motion, reduced bob |

Transitions in: `set_move_state()`. Sensing→noticing→leading is automatic;
distressed is driven externally (overwhelm system, step 9). If the player
walks `lose_radius` away from a sensed object, Pip lets it go and returns
to following — freedom, not nagging.

## Emotion language (`Pip.Emotion`)

Seven glow colours with smooth transitions, each paired with a distinct
pulse rhythm so the language survives colourblind play:

| Emotion | Colour | Rhythm |
|---|---|---|
| GOLDEN (happy/safe, default) | warm gold | slow breathing |
| BLUE (sad/withdrawn) | deep blue | dim, faint, slow |
| RED (overwhelmed) | bright red | fast flicker (cozy-capped) |
| GREEN (curious) | soft green | lively pulse — precedes finding objects |
| WHITE (afraid) | pale white | very dim, near-still |
| PURPLE (excited) | purple | quick shimmer |
| SHIMMER (final moment only) | hue-cycling | unique chime (`pip_shimmer_chime` SFX key) |

Set with `set_emotion()` — the simple "change Pip's colour" entry point;
`play_shimmer()` is the ending's entry point. Colour/rhythm values live in
plain data, never a shader: `EMOTION_GLOW` in `pip.gd`, with the calm gold
exposed as the exported `calm_color` so it's tweakable in the inspector.
The colour smoothly tweens onto the orb and light. **Reduced sensory mode**
(`Settings.reduced_sensory`) caps flicker speed and depth.

## Signals

- `state_changed(state)` / `emotion_changed(emotion)` — journal + sound layer hooks later.
- `reached_object(object)` — fired once when Pip hovers over a sensed
  object with the player nearby. The mending system (step 4) connects here.

## Adding a sensable object

Attach the **`Sensable`** component (`scenes/sensable/`) to a `Node2D` —
it owns how far Pip senses it from (`sense_radius`) and whether it's
currently active (`active`, for story-gating main mending objects). Pip
runs the notice→lead arc on its own. See that folder's README. A plain
`Node2D` in the `pip_sensable` group still works, using Pip's
`default_sense_radius` fallback. The test room's `HiddenTrinket` is the
working example.

## Art & audio seams

The orb is procedural (gradient sub-resources in `pip.tscn`), so the
in-world Pip needs no sprite assets. The detailed fae look is deferred to a
dialogue portrait (separate task). The old per-state stand-ins
(`pip_idle` …) and the fae stand-in (`pip_placeholder.png`) are no longer
used in-world — left in place for now; the fae is the likely source for
that future portrait. Per-emotion ambient sound (optional layer) will use
`pip_emotion_<name>` SFX keys when the audio pass happens.

## Wiring & verification

Scenes point Pip at their player via the exported `follow_target_path`.
At runtime, set `follow_target` directly — that is Pip choosing: the
prologue assigns it the moment Pip decides to follow, and `null` means
Pip hovers where they are. Smoke test for the whole sensing arc:

```sh
godot --headless --path . res://tests/pip_smoke.tscn
```

## Playground (debug builds, in the test room)

`1` calm · `2` distressed · `3` cycle emotion · `4` shimmer ·
`9` toggle reduced sensory · `0` reset. Walk near the north-east trinket
for the sensing arc. Feel values are exported on the Pip node — tune in
the inspector while running.
