extends CanvasLayer
## The full-screen mending surface — currently a shell.
##
## Opens over the world, dims it, pauses everything, and closes on the X or
## Escape. There is deliberately no mending in it yet: this exists so the
## *route in and out* is proven before any technique is built on top.
##
##     MendScreen.open("Sable's lantern")
##
## Registered as an autoload (`MendScreen`), same as `Dialogue`, so any object
## can start a mend without wiring a path to it.
##
## WHAT GOES HERE LATER (GDD, build step 4). Eleven mending techniques, each
## unique to its object — heat sealing, threading, breathing rhythm, piecing,
## and so on. They all share this frame: Pip lands on the object first as the
## signal, the world dims and quiets, a gentle prompt introduces each new
## technique the first time it appears, and it ends on a soft chime and a
## memory cutscene. None of that is here yet; `open()` just shows the shell.
##
## Two rules from the design that constrain whatever gets built inside:
## - Cozy first. No timers, no fail states, no mashing. A mend that feels
##   stressful is wrong however satisfying the mechanic is.
## - Gentle failures, not punishments. Getting it wrong is a learning moment,
##   never a setback.
##
## ART SEAM. Nothing here hardcodes a path. The backdrop will come from
## AssetRegistry when there is art for it; until then it is a drawn panel,
## exactly like the dialogue box's fallback.

## Emitted when the screen closes. `completed` is false while this is a shell —
## it becomes meaningful when a mend can actually be finished, so callers
## written now (journal, gratitude, autosave) already have the right shape.
signal closed(completed: bool)

const BASE_FONT_SIZE := 8

## True while the screen is up. Interaction must not start a second one.
var is_open := false

## Guards against the press that opened the screen also closing it — the same
## one-frame problem the dialogue box solves the same way.
var _opened_on_frame := -1

@onready var _root: Control = $Root
@onready var _title: Label = $Root/Panel/Title
@onready var _close_button: Button = $Root/Panel/CloseButton


func _ready() -> void:
	_root.visible = false
	_apply_text_scale()
	Settings.changed.connect(_apply_text_scale)
	_close_button.pressed.connect(close)


## Open the mending surface for an object. `object_name` is display text for
## now; when mending is real this will take the object's key so the screen can
## pick the right technique.
func open(object_name: String = "") -> void:
	if is_open:
		return
	is_open = true
	_opened_on_frame = Engine.get_process_frames()
	_title.text = object_name if not object_name.is_empty() else "Mending"
	_root.visible = true
	# Everything stops: player, Pip, the sensor. This node keeps running only
	# because its process_mode is When Paused — set in the scene, not here.
	get_tree().paused = true
	_close_button.grab_focus()  # so Enter/controller can close it too


func close() -> void:
	if not is_open:
		return
	is_open = false
	_root.visible = false
	get_tree().paused = false
	closed.emit(false)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	# The press that opened this screen must not also close it.
	if Engine.get_process_frames() == _opened_on_frame:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Adjustable text size is a required accessibility option, so the screen
## reads the setting rather than baking a size into the scene.
func _apply_text_scale() -> void:
	var size := maxi(1, roundi(BASE_FONT_SIZE * Settings.text_scale))
	_title.add_theme_font_size_override(&"font_size", size)
	_close_button.add_theme_font_size_override(&"font_size", size)
