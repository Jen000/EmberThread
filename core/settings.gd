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
