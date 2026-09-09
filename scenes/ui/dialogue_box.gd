extends CanvasLayer
## The text box at the bottom of the screen. Registered as an autoload
## (`Dialogue`) so any object anywhere can say something without wiring a
## path to it:
##
##     Dialogue.say("sable", ["The lamp's been dark three weeks now.",
##                            "Longer than I'd like to admit."])
##
## The GDD's rules for this, which shape the whole design:
## - Classic box at the bottom, portrait beside the text, clean and readable.
## - The player only listens — no choices anywhere except the one response to
##   the guild NPC's harsh comment. Don't build a choice system yet.
## - The world pauses completely during dialogue.
##
## ART SEAM — the reason this exists before your artist has finished.
## Nothing here hardcodes a file path. The frame is a NinePatchRect whose
## texture comes from AssetRegistry ("ui_dialogue_box"), and the portrait
## from AssetRegistry.get_portrait(speaker_id). Until those files exist, draw
## a plain box so the system is playable. When the art arrives it drops into
## assets/ui/dialogue/ and assets/portraits/ and replaces the stand-in with
## zero code edits (art-pipeline.md §10).
##
## ---------------------------------------------------------------------------
## GODOT VOCABULARY, kept as a reference for whoever picks this up next.
##
##   CanvasLayer    Draws its children on a layer above the world, unaffected
##                  by the camera. That's why UI goes in one — the box stays
##                  at the bottom of the SCREEN, not the bottom of the map.
##
##   Control        The base class of UI nodes. Positioned by anchors and
##                  offsets rather than a plain x/y, so things stay put at any
##                  window size.
##
##   NinePatchRect  An image that stretches without distorting its corners.
##                  You set margins saying "these edges are the frame"; the
##                  middle stretches, the corners stay crisp. Exactly what a
##                  dialogue box needs.
##
##   RichTextLabel  A label that can do markup and — the part you need —
##                  `visible_ratio`, a 0..1 knob for how much of the text is
##                  shown. Animate that and you have a typewriter, without
##                  touching the string.
##
##   autoload       A scene or script Godot loads once at startup and makes
##                  available everywhere by name. That's how `Dialogue.say()`
##                  works from any script without a node path.
##
##   process_mode   Whether a node keeps running while the tree is paused.
##                  This scene's root is "When Paused" — without it the box
##                  would pause along with the world it just paused, and
##                  nothing could un-pause it.
## ---------------------------------------------------------------------------
##
## SCENE STRUCTURE (dialogue_box.tscn), all sized at native 480x270:
##
##   DialogueBox            CanvasLayer   process_mode = When Paused
##     Root                 Control       full rect, mouse_filter = Ignore
##       Frame              NinePatchRect bottom wide, offset_top -76
##         ColorRect        ColorRect     the drawn stand-in until art lands
##         Portrait         TextureRect   64x64, locked by art-pipeline.md §2
##         Text             RichTextLabel right of the portrait
##         Continue         TextureRect   the "press to go on" arrow
##
## Portraits at 64x64 are a big chunk of a 270px-tall screen; that is what
## sets the box height. Lay out against a real 64x64 block before changing it.


## Emitted when the last line is dismissed and the world resumes. Await it to
## sequence things: a memory cutscene after a conversation, say.
signal finished

## Emitted as each line is fully revealed. The journal will want this.
signal line_shown(index: int)

const BASE_FONT_SIZE := 8

## Characters revealed per second, before the player's `Settings.text_speed`
## multiplier. Slow enough to feel spoken, fast enough that nobody's waiting.
## Tune it by reading along out loud.
@export var reveal_speed := 30.0

## True while a conversation is on screen. Interaction must not start a new
## one while this is true.
var is_open := false

var _opened_on_frame := -1

var _lines: PackedStringArray
var _line_index := 0

var _reveal: Tween

# Node references. @onready means "assign this the moment the scene is ready",
# which is the only safe time — $Root doesn't exist before then. The $ is
# shorthand for get_node().
@onready var _root: Control = $Root
@onready var _frame: NinePatchRect = $Root/Frame
@onready var _portrait: TextureRect = $Root/Frame/Portrait
@onready var _text: RichTextLabel = $Root/Frame/Text
@onready var _continue: TextureRect = $Root/Frame/Continue
@onready var _color_rect: ColorRect = $Root/Frame/ColorRect


func _ready() -> void:
	_root.visible = false
	_apply_text_scale()
	# Live updates when the settings sliders move. Settings is an autoload, so
	# this connection outlives any scene change.
	Settings.changed.connect(_apply_text_scale)


## Adjustable text size is a required accessibility option, so the box derives
## its size from the setting rather than baking one into the scene.
func _apply_text_scale() -> void:
	_text.add_theme_font_size_override(
			&"normal_font_size", maxi(1, roundi(BASE_FONT_SIZE * Settings.text_scale)))


## Show a conversation. `speaker_id` is the AssetRegistry portrait key
## ("sable" -> npc_sable_portrait); pass "" for an unattributed line like a
## signpost, and hide the portrait.
func say(speaker_id: String, new_lines: PackedStringArray) -> void:

	if new_lines.is_empty():
		return
	_lines = new_lines
	_line_index = 0

	is_open = true
	_root.visible = true
	_opened_on_frame = Engine.get_process_frames()

	get_tree().paused = true

	var frame_texture := AssetRegistry.get_sprite("ui_dialogue_box")
	var portrait := AssetRegistry.get_portrait(speaker_id)
	if frame_texture != null:
		_frame.texture = frame_texture
	else:
		_color_rect.visible = true  # temporary stand-in until the art arrives

	if portrait != null and speaker_id != "":
		_portrait.texture = portrait
		_portrait.visible = true
	else:
		_portrait.visible = false

	_show_line(0)


## Reveal one line, typewriter style.
func _show_line(index: int) -> void:
	_text.text = _lines[index]
	_text.visible_ratio = 0.0
	_continue.visible = false
	_reveal = create_tween()
	# Duration from the line's length, so the *speed* stays constant and a long
	# line doesn't crawl. Settings.text_speed lets the player scale that.
	var duration := _lines[index].length() / (reveal_speed * Settings.text_speed)
	_reveal.tween_property(_text, "visible_ratio", 1.0, duration)
	_reveal.finished.connect(_finish_reveal.bind(index))


## Everything that should be true once a line is fully on screen — whether it
## got there by the tween completing or by the player pressing through it.
func _finish_reveal(index: int) -> void:
	_text.visible_ratio = 1.0
	_continue.visible = true
	line_shown.emit(index)


## Advance: finish the current reveal if it's still running, otherwise move to
## the next line, or close if that was the last.
##
## Public because the player's press is not the only thing that will ever want
## to advance a line — an auto-advance during a cutscene, a "skip" button, and
## the smoke test all call it. (Tests calling private methods is a smell: the
## test then breaks on any rename, and it hides that the thing has no API.)
func advance() -> void:
	if _reveal != null and _reveal.is_running():
		_reveal.kill()
		_finish_reveal(_line_index)
		return
	_line_index += 1
	if _line_index < _lines.size():
		_show_line(_line_index)
	else:
		_close()


func _close() -> void:
	_root.visible = false
	is_open = false
	get_tree().paused = false
	finished.emit()


func _unhandled_input(_event: InputEvent) -> void:
	if is_open == false or _event == null:
		return
	if Engine.get_process_frames() == _opened_on_frame:
		return
	if _event.is_action_pressed("interact") or (_event is InputEventMouseButton and _event.button_index == MOUSE_BUTTON_LEFT and _event.pressed):
		advance()
		get_viewport().set_input_as_handled()  # don't let the world see this press
