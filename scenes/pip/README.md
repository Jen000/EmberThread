# Pip

The emotional heart of the game: a tiny glowing fae who chose to follow
the player. Two independent axes, per the GDD — a movement state machine
and an emotion (glow) language. Movement is communication (design
principle 9); colour is never the only signal.

## Movement states (`Pip.MoveState`)

| State | Reads as | Behaviour |
|---|---|---|
| `FOLLOW` | calm, connected | floats at the player's quieter side (flips with facing), smooth drift + gentle bob; scans for sensable objects |
| `NOTICING` | "oh!" | brief hold (0.7s): glow-pulse animation, turns curious-green, leans toward what was sensed, then leads |
| `LEADING` | eager, pulling ahead | stays `lead_distance` ahead of the player toward the object, tilts forward; hovers over the object when the player arrives and emits `reached_object` |
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

Set with `set_emotion()`; `play_shimmer()` is the ending's entry point.
Colour/rhythm values live in one place: `EMOTION_GLOW` in `pip.gd`
(hexes provisional until the Art Brief palette lands). **Reduced sensory
mode** (`Settings.reduced_sensory`) caps flicker speed and depth.

## Signals

- `state_changed(state)` / `emotion_changed(emotion)` — journal + sound layer hooks later.
- `reached_object(object)` — fired once when Pip hovers over a sensed
  object with the player nearby. The mending system (step 4) connects here.

## Adding a sensable object

Put any `Node2D` in the **`pip_sensable`** group. Within `detect_radius`
of Pip (while following), the notice→lead arc triggers on its own. Remove
it from the group (or free it) when mended. The test room's
`HiddenTrinket` is the working example.

## Art & audio seams

Frames resolve through AssetRegistry keys `pip_idle` (3), `pip_distressed`
(3), `pip_leading` (2), `pip_glow` (3), `pip_shimmer` (6–8 tolerated) —
real frames overwrite the stand-ins, zero code edits. The glow is an
additive gradient sprite for now; upgrade to the custom glow shader when
real art lands. Per-emotion ambient sound (optional layer) will use
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
