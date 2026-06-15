class_name Sensable
extends Node2D
## A point Pip can sense and lead the player toward (region-1 ability).
##
## Each sensable owns *how far it can be sensed from* and *whether it is
## currently active*, so the two cases in the design work differently with
## no special-casing in Pip:
##
## - NPC objects: a generous `sense_radius` so Pip starts leading from a
##   comfortable distance — you don't have to stumble onto them.
## - Main mending objects: start dormant (`active = false`) and are switched
##   on by the story/progression system at the right beat, so Pip only
##   leads to them once that part of the tale has opened.
##
## Put one in the world, set its two knobs, and Pip handles the rest.
## Call `mark_mended()` when its mend completes to retire it quietly.

signal mended

## Pip begins the notice -> lead arc when within this range (pixels).
@export var sense_radius := 96.0

## Dormant sensables are ignored until switched on (story gating).
@export var active := true


func _ready() -> void:
	add_to_group(&"pip_sensable")


func set_active(value: bool) -> void:
	active = value


## Retire this sensable once its object has been mended: it leaves the
## group so Pip no longer leads here, and emits `mended` for listeners
## (journal, NPC state) to react.
func mark_mended() -> void:
	active = false
	remove_from_group(&"pip_sensable")
	mended.emit()
