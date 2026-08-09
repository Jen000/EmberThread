# Ember & Thread

A cozy, narrative pixel-art game for Steam about learning the language someone speaks when no one else has bothered to listen. Built by a solo creator working with Claude Fable. Build it with that in mind.

## Project documents

Read these rather than re-deriving anything; they are the source of truth.

- **`docs/Ember_and_Thread_Claude_Fable_Prompt.md`** — master brief: design pillars, the sensitivity note, and the build order. Start here each session.
- **`docs/Ember_and_Thread_GDD.docx`** — full design: the four-act narrative, all NPC arcs, the 11 mending interactions, every mechanic (Pip AI, overwhelm, comfort items, journal, map, economy), and accessibility requirements. This defines *what* to build.
- **`docs/art-pipeline.md`** — the asset layer: locked sizes, naming convention, placeholder strategy, and Kenney gap-filler rules. This defines *how art enters the project*.
- `docs/Ember_and_Thread_Art_Brief.*` — art direction (what each asset depicts). Optional; dimensions already live in the pipeline doc.

## Tech stack

- **Godot 4 / GDScript.** Keep the stack simple and well-documented.
- **Native resolution 480×270**, scaled 4× to 1920×1080. Build everything at native resolution. Set **Filter = Nearest** on every texture or pixel art renders blurry.
- **State machines** drive Pip's AI. **Custom shaders** handle palette-swapping (player customisation) and glow (Pip).

## How we build

- **Build order** (from the Fable prompt): 1) Godot setup → 2) Pip basics (following, colour states, movement states) → 3) coastal town → 4) mending mechanic → 5) journal → 6) dialogue system → 7) map → 8) memory cutscenes → 9) overwhelm moments → 10) comfort items.
- **One region fully before the next.** Coastal Town is the reference implementation; Forest Village, Mountain Shrine Town, and Castle Ruins follow its patterns. Each region should be complete and playable before expanding.
- **Work in scoped sessions.** Pull the relevant GDD section for the day's task rather than loading the whole design at once.

## Git workflow

- **Develop on a feature branch and push there — never merge to `main`.** The developer pulls the branch, tests locally, vets it, and merges to `main` themselves. Stop at "pushed to the branch; here's what to test."
- **Don't open pull requests unless asked.** Don't push to `main` unless the developer explicitly says so for that change.

## Standing rules

- **Document every system.** Ship each as a reusable component with a short README explaining how to add content to it (how to add an NPC, a comfort item, a mending interaction, a region).
- **Accessibility is non-negotiable** — it is the point of the game, not a polish task. Scaffold accessibility options as you build, not at the end.
- **Art is a swappable layer.** Follow `art-pipeline.md` exactly: build to the locked sizes and naming, route all asset paths through the asset registry, never hardcode a path. A real asset must be able to replace a stand-in with zero code edits.
- **Gap-filler art is Kenney only** (CC0). Anything else → stop and ask. The player, Pip, NPCs, portraits, journal illustrations, and the map stay as block placeholders; only 16×16 tiles and 16×16/32×32 objects are sourced from Kenney.
- **Solo creator scope.** When something is too complex, say so and suggest a simpler path that preserves the emotional vision — don't silently over-engineer.
- **Sensitivity.** The game deals with neurodivergence and institutional erasure. If anything in the design or implementation reads as reductive, stereotyping, or harmful in its representation, flag it directly and constructively.
- **Clean, readable, maintained code.** This project lives over time — write it to be picked up again months later.
