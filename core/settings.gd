extends Node
## Game settings and accessibility flags — scaffolded from the start so
## systems hook in as they are built (accessibility is the point of the
## game, not a polish task). The settings menu UI arrives later; the flags
## live here now so nothing has to be retrofitted.

signal changed

## Reduced sensory mode: systems that pulse, flash or flicker read this
## and soften — Pip's glow caps its flicker, particles dim, ambient sound
## layers quiet (each system applies its own softening when built).
var reduced_sensory := false:
	set(value):
		reduced_sensory = value
		changed.emit()

## Text size multiplier: every piece of text in the game derives its font
## size from a base size times this, so one slider scales the lot (interaction
## prompts already do; dialogue and the journal follow as they are built).
var text_scale := 1.0:
	set(value):
		text_scale = clampf(value, 0.75, 2.0)
		changed.emit()

## How fast dialogue reveals itself, as a multiplier on each box's base speed.
## "Adjustable game speed" is on the required accessibility list and text speed
## is part of it: some players read far faster than a comfortable default, and
## some need longer. High values are effectively instant, which is the setting
## a screen-reader user or an impatient replayer wants.
var text_speed := 1.0:
	set(value):
		text_speed = clampf(value, 0.5, 5.0)
		changed.emit()

## Interaction hints: the "[E] Talk" label that floats over whatever you could
## act on. Some players want the world uncluttered and are happy to just press
## the button; others rely on the words to know what an outline means. On by
## default — it is the only part of the cue that says *what will happen*.
var interaction_hints := true:
	set(value):
		interaction_hints = value
		changed.emit()
