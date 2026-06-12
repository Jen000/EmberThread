# core/ — pipeline seams (autoloads)

These three singletons are the only code in the project that touches asset
file paths. Everything else uses logical keys, per `docs/art-pipeline.md`.

## AssetRegistry

Scans `res://assets/` at startup and maps logical keys to files using the
locked naming convention. A key is the filename stem minus the `_NN`
animation-frame suffix.

```gdscript
AssetRegistry.get_sprite("pip_idle")        # Texture2D, first frame
AssetRegistry.get_frames("pip_idle")        # Array[Texture2D], _01.._NN
AssetRegistry.get_portrait("sable")         # npc_sable_portrait
AssetRegistry.has_asset("object_lantern_broken")
AssetRegistry.frame_count("pip_shimmer")    # tolerates 6, 7 or 8 frames
```

**Adding an asset:** drop a correctly-named PNG anywhere under
`res://assets/` (final path per the pipeline doc §3). No registration step —
the naming *is* the registration. Real art overwrites a stand-in file in
place and appears on the next run with zero code edits (§10).

**Temp-art audit (debug builds):** at startup the registry prints every
block stand-in still in use (from `assets/stand_ins.json`, hash-verified, so
overwritten files drop off automatically) and every sourced gap-filler still
present (rows in `assets/temp_assets.md`), then one summary warning.
Ship gate: both lists empty. Programmatic access: `stand_ins_in_use()`,
`temp_art_in_use()`.

## SoundManager

```gdscript
SoundManager.play_sfx("mend_complete")           # optional volume_db, pitch_scale
```

Resolves `res://assets/audio/sfx/<key>.ogg` (or `.wav`); 8 pooled voices on
the `SFX` bus. A missing clip is silence plus a one-time debug warning —
sound never gates gameplay. **Adding a sound:** drop the clip at that path
with the key as filename. SoundManager also creates the `Music`, `SFX` and
`Ambient` buses at startup (stable targets for volume sliders and reduced
sensory mode).

## MusicManager

```gdscript
MusicManager.play_music("coastal_town")
MusicManager.stop_music()
```

Resolves `res://assets/audio/music/<key>.ogg` (or `.wav`) on the `Music`
bus. Until the composer delivers, calls are silent no-ops — wire region
music cues now; tracks slot in 1:1 later.
