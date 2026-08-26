extends CanvasLayer
## STUB — you're building this one. See docs/build-plan-highlight-dialogue.md
## steps 5–7.
##
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
## GODOT VOCABULARY for this file.
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
##                  Critical here — see TODO 3.
## ---------------------------------------------------------------------------
##
## BUILD THE SCENE FIRST (dialogue_box.tscn), then write the code.
##
##   1. New Scene -> Other Node -> CanvasLayer. Rename it DialogueBox.
##      Attach this script to it. Save as scenes/ui/dialogue_box.tscn.
##   2. Add child Control, name it Root.
##        Inspector -> Layout -> Anchors Preset -> Full Rect.
##        Inspector -> Mouse -> Filter -> Ignore   (so it never eats clicks
##        meant for the world underneath).
##   3. Under Root add NinePatchRect, name it Frame.
##        Anchors Preset -> Bottom Wide. Height 76, offset_top -76.
##        No texture yet — that's TODO 4.
##   4. Under Frame add TextureRect "Portrait", 64x64, a few px in from the
##      left. 64x64 is locked by art-pipeline.md §2 — don't shrink it to make
##      the layout easier, that decision belongs to the artist.
##   5. Under Frame add RichTextLabel "Text", filling the space right of the
##      portrait (roughly 396x60).
##   6. Under Frame add TextureRect "Continue", small, bottom-right. This is
##      the little "press to go on" arrow. Leave it hidden for now.
##   7. Select DialogueBox (the root) -> Inspector -> Process -> Mode ->
##      "When Paused". THIS IS THE ONE PEOPLE MISS. See TODO 3.
##   8. Project -> Project Settings -> Globals -> Autoload. Add
##      scenes/ui/dialogue_box.tscn (the SCENE, not the script) with the name
##      `Dialogue`. That name is what makes `Dialogue.say(...)` resolve.
##
## Sizes are at native 480x270 — build to that, never to 1920x1080. Portraits
## at 64x64 are a big chunk of a 270px-tall screen; that's what sets the box
## height, so lay it out against a real 64x64 block before the artist commits.

## Emitted when the last line is dismissed and the world resumes. Await it to
## sequence things: a memory cutscene after a conversation, say.
signal finished

## Emitted as each line is fully revealed. The journal will want this.
signal line_shown(index: int)

const BASE_FONT_SIZE := 8

## Characters revealed per second. Slow enough to feel spoken, fast enough
## that nobody's waiting. Tune it by reading along out loud.
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
	_text.add_theme_font_size_override(&"normal_font_size", BASE_FONT_SIZE)
	_root.visible = false


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





# =============================================================================
# TODO 1 — guard and store.
#   Return early if lines.is_empty(). Store `lines` in a member var, and reset
#   a line-index var to 0. Declare both up with is_open.
#
# TODO 2 — go visible.
#   is_open = true, _root.visible = true.
#   Also record Engine.get_process_frames() into a member var here. You won't
#   use it until TODO 12, but this is where the value has to be captured.
#
# TODO 3 — pause the world.
#   get_tree().paused = true
#
#   Everything in the tree stops: player, Pip, the interaction sensor. That's
#   what you want — except this box would stop too, and then nothing can
#   un-pause it. The game appears to freeze with a dead box on screen and it
#   looks exactly like a crash.
#
#   The fix is step 7 of the scene setup: process_mode = "When Paused" on the
#   DialogueBox root. Set it in the INSPECTOR, not in code — a thing you can
#   see in the scene is a thing you can debug.
#
# TODO 4 — resolve the art, degrade quietly.
#   var frame_texture := AssetRegistry.get_sprite("ui_dialogue_box")
#   var portrait := AssetRegistry.get_portrait(speaker_id)
#
#   Both return null when the file doesn't exist yet, which is TODAY and will
#   be true for months. So:
#     - frame null -> leave the NinePatchRect untextured and give Frame a
#       plain background (a ColorRect behind it, or a StyleBox) so text is
#       readable. Temporary and honest, like the block placeholders.
#     - portrait null or speaker_id empty -> _portrait.visible = false, and
#       let the text use the full width.
#
#   Do NOT write `if speaker_id == "sable"` anywhere. The key goes to the
#   registry, the registry finds the file. That's the whole seam.
#
# TODO 5 — show the first line: call _show_line(0).
# =============================================================================


## Reveal one line, typewriter style.
func _show_line(index: int) -> void:
	_text.text = _lines[index]
	_text.visible_ratio = 0.0
	_continue.visible = false
	_reveal = create_tween()
	_reveal.tween_property(_text, "visible_ratio", 1.0, _lines[index].length() / reveal_speed)
	_reveal.finished.connect(_finish_reveal.bind(index))


## Everything that should be true once a line is fully on screen — whether it
## got there by the tween completing or by the player pressing through it.
func _finish_reveal(index: int) -> void:
	_text.visible_ratio = 1.0
	_continue.visible = true
	line_shown.emit(index)

# =============================================================================
# TODO 6 — the typewriter.
#   _text.text = <the line at index>
#   _text.visible_ratio = 0.0
#   then tween visible_ratio to 1.0 over (line.length() / reveal_speed)
#   seconds:
#
#     var tween := create_tween()
#     tween.tween_property(_text, "visible_ratio", 1.0, duration)
#
#   Dividing by length is what keeps a long line from crawling and a short one
#   from flashing past — the speed stays constant, the duration varies.
#
#   Keep the tween in a member var (`var _reveal: Tween`). TODO 9 needs to
#   interrupt it.
#
# TODO 7 — the continue arrow.
#   _continue.visible = false while revealing, true once it finishes. Use
#   `await tween.finished` or tween.tween_callback(...) — either is fine;
#   await usually reads better.
#
# TODO 8 — emit line_shown(index) once the reveal completes.
# =============================================================================


## Advance: finish the current reveal if it's still running, otherwise move to
## the next line, or close if that was the last.
func _advance() -> void:
	if _reveal != null and _reveal.is_running():
		_reveal.kill()
		_finish_reveal(_line_index)
		return
	else:
		_line_index += 1
		if _line_index < _lines.size():
			_show_line(_line_index)
		else:
			_close()

# =============================================================================
# TODO 9 — impatience should help, not punish.
#   If _reveal != null and _reveal.is_running():
#       _reveal.kill()
#       _text.visible_ratio = 1.0
#       _continue.visible = true
#       return
#
#   A player pressing the key mid-reveal wants the REST of the line, not to
#   skip it. Getting this backwards is the single most irritating dialogue bug
#   in games, and it's four lines to get right.
#
# TODO 10 — otherwise advance the index. If there's another line, _show_line()
#   it; if there isn't, _close().
# =============================================================================


func _close() -> void:
	_root.visible = false
	is_open = false
	get_tree().paused = false
	finished.emit()

# =============================================================================
# TODO 11 — unwind everything TODO 2 and 3 did, in reverse:
#   _root.visible = false
#   is_open = false
#   get_tree().paused = false
#   finished.emit()
#
#   Order matters: unpause before emitting, or a listener that starts a
#   cutscene will do it into a still-paused tree.
# =============================================================================


func _unhandled_input(_event: InputEvent) -> void:
	if is_open == false or _event == null:
		return
	if Engine.get_process_frames() == _opened_on_frame:
		return 
	if _event.is_action_pressed("interact") or (_event is InputEventMouseButton and _event.button_index == MOUSE_BUTTON_LEFT and _event.pressed):
		_advance()
		get_viewport().set_input_as_handled()  # don't let the world see this press


# =============================================================================
# TODO 12 — input, and the bug this whole TODO exists to prevent.
#
#   Rename the parameter from `_event` to `event` when you start using it.
#   The leading underscore is Godot's convention for "deliberately unused",
#   and it's what stops the editor warning about it while this is still a stub.
#
#   if not is_open: return
#   Advance on the "interact" action and on a left mouse click:
#     event.is_action_pressed("interact")
#     event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
#         and event.pressed
#   Then call _advance() and get_viewport().set_input_as_handled() so the
#   press never reaches the world underneath and re-triggers the object you
#   just talked to.
#
#   THE BUG, described in advance so you recognise it instead of hunting it:
#   the same press that opens the box also advances its first line, so short
#   lines look like they get skipped entirely. It happens because the box
#   starts existing part-way through a press and then sees that same press.
#
#   The fix is the frame number you stored in TODO 2:
#
#     if Engine.get_process_frames() == _opened_on_frame:
#         return
#
#   Ignore input on the frame the box opened, and the press that opened it
#   can't also advance it.
#
#   (Using a different key to advance — Space/Enter rather than E — makes this
#   impossible rather than merely fixed, which is why the plan recommends it.
#   Keep the guard anyway: the mouse can still click twice in one press path.)
# =============================================================================
