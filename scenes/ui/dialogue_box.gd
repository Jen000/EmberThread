extends CanvasLayer
## STUB — you're building this one. See docs/build-plan-highlight-dialogue.md
## steps 5–7 for the walkthrough.
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
## a plain rounded box so the system is playable. When the art arrives it
## drops into assets/ui/dialogue/ and assets/portraits/ and replaces the
## stand-in with zero code edits (art-pipeline.md §10).
##
## SCENE STRUCTURE to build in the editor (dialogue_box.tscn):
##
##   DialogueBox            CanvasLayer   (this script)
##     Root                 Control       full-rect, mouse_filter = Ignore
##       Frame              NinePatchRect anchored bottom, 480x76 (full width)
##         Portrait         TextureRect   left inset, 64x64 (locked size)
##         Text             RichTextLabel right of the portrait, ~396x60
##         Continue         TextureRect   small blinking arrow, bottom-right
##
## Sizes are at native 480x270 — build to that, never to 1920x1080. Portraits
## are locked at 64x64 by art-pipeline.md §2, which is a big chunk of a
## 270px-tall screen — that's what sets the box height, so lay it out against
## a real 64x64 block before the artist commits to anything.

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


## Show a conversation. `speaker_id` is the AssetRegistry portrait key
## ("sable" -> npc_sable_portrait); pass "" for an unattributed line like a
## signpost, and hide the portrait.
func say(speaker_id: String, lines: PackedStringArray) -> void:
	# TODO 1. Bail if lines is empty. Store lines, reset the line index.
	# TODO 2. is_open = true; show the Root control.
	# TODO 3. Pause the world: get_tree().paused = true
	#         This node needs process_mode = PROCESS_MODE_WHEN_PAUSED or it
	#         will pause itself along with everything else and hang the game.
	#         (Set it in the scene, not here — easier to see.)
	# TODO 4. Resolve the portrait via AssetRegistry.get_portrait(speaker_id);
	#         hide the Portrait node when the key is empty or missing.
	# TODO 5. Show the first line.
	pass


## Reveal one line, typewriter style.
func _show_line(index: int) -> void:
	# TODO 6. Set the RichTextLabel's text, then animate visible_ratio from
	#         0 to 1 over (line length / reveal_speed) seconds with a tween.
	# TODO 7. Hide the Continue arrow until the reveal finishes, then show it.
	# TODO 8. Emit line_shown(index).
	pass


## Advance: finish the current reveal if it's still running, otherwise move to
## the next line, or close if that was the last.
func _advance() -> void:
	# TODO 9. If the reveal tween is still running, kill it and jump
	#         visible_ratio to 1.0 — impatient players should get the whole
	#         line, not a skipped one.
	# TODO 10. Otherwise: next line, or _close() when they run out.
	pass


func _close() -> void:
	# TODO 11. Hide, is_open = false, get_tree().paused = false, emit finished.
	pass


func _unhandled_input(_event: InputEvent) -> void:
	# TODO 12. When open, advance on "interact" and on a left mouse click,
	#          and call get_viewport().set_input_as_handled() so the press
	#          never reaches the world underneath.
	#
	# THE BUG YOU WILL HIT, described in advance so you recognise it:
	# the same press that opens the box also advances its first line, so
	# short lines appear to be skipped entirely. It happens because the box
	# starts existing mid-press and then sees that same press.
	# Fix: ignore input on the frame the box opened — record
	# Engine.get_process_frames() in say() and compare here.
	pass
