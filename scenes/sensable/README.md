# Sensable

A point Pip can sense and lead the player toward (Pip's region-1 ability).
Attach the `sensable.gd` script to any `Node2D` (or instance it) and Pip
handles the notice → lead → arrive arc on its own.

## Why it's a component

The design needs two *different* sensing behaviours, and putting the knobs
on each object — rather than one global setting on Pip — is what makes that
work with no special-casing:

- **NPC objects** should pull Pip from a comfortable distance. Give them a
  generous `sense_radius` so the player doesn't have to stumble onto them.
- **Main mending objects** should only draw Pip once the story has reached
  that beat. Start them dormant (`active = false`); the progression system
  flips them on at the right moment.

## Properties

| Property | Default | Meaning |
|---|---|---|
| `sense_radius` | `96.0` | Pip begins leading when within this range (px) |
| `active` | `true` | Dormant sensables are ignored until switched on |

## API

```gdscript
sensable.set_active(true)   # story unlocks a main mending object
sensable.mark_mended()      # retire after its mend: leaves the group,
                            # emits `mended`
```

`mark_mended()` emits the `mended` signal — the journal and NPC state will
hook into it later.

## Usage

```
# NPC object — Pip notices from well across the room:
Node2D (script = sensable.gd, sense_radius = 130)

# Main mending object — dormant until Act 2 opens it:
Node2D (script = sensable.gd, active = false)   # then later: set_active(true)
```

A plain `Node2D` added to the `pip_sensable` group still works as a
fallback — Pip uses its own `default_sense_radius` for those. The test
room's `HiddenTrinket` is a live example (`sense_radius = 120`).

When a mend completes, Pip's `reached_object` signal fires first (the mend
system starts), and `mark_mended()` is called when it finishes.
