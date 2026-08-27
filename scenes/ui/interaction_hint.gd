extends Label
## STUB — you're building this one. Four TODOs, and TODO 4 is filled in.
##
## The one line of text that tells the player what the button will DO.
##
## The outline says "something is here". It cannot say whether pressing E will
## Talk, Take or Mend — three quite different promises that look identical as
## a glow. This closes that gap, and it's the accessible half of the cue:
## presence/absence of an outline is purely visual, whereas a word can be
## read, scaled up, or spoken by a screen reader later.
##
## ONE LABEL FOR THE WHOLE GAME. Not one per object. The hint describes *your
## current state* ("you could talk to someone"), not the object, so it belongs
## on the HUD — and that way adding an NPC needs no hint wiring at all.
##
## ---------------------------------------------------------------------------
## SCENE SETUP — in scenes/main/main.tscn, under the existing `UI` CanvasLayer:
##
##   1. Right-click UI -> Add Child Node -> Label. Name it InteractionHint.
##   2. Layout -> Anchors Preset -> Center Bottom.
##   3. Layout -> Anchor Offsets -> Top = -28   (sits just above ControlsHint)
##   4. Inspector -> Horizontal Alignment -> Center.
##   5. Drag this script onto its Script property.
##
## Sizes are at native 480x270. Don't set a font size in the Inspector —
## TODO 2 does it in code so it can scale with the accessibility setting.
## ---------------------------------------------------------------------------
##
## WHERE THE DATA COMES FROM. Nothing new is needed; both halves already exist:
##
##   InteractionSensor.focus_changed(interactable)   fires with the object when
##       you walk into range, and with null when you leave
##   Interactable.prompt_verb                        "Talk", "Read", "Mend"
##
## `prompt_verb` has been sitting unread since the floating prompt was deleted
## in step 1. This is the home it was waiting for.

## The base size before the accessibility multiplier. Matches the old floating
## prompt so the hint and the dialogue box read as the same voice.
const BASE_FONT_SIZE := 8


func _ready() -> void:
	# TODO 1 — listen to the player's sensor.
	#
	#   The player joined the "player" group in step 5, so:
	#     var player := get_tree().get_first_node_in_group("player")
	#   then find its InteractionSensor child (by type, the way
	#   interactable.gd finds its Highlight — not by name), and connect
	#   its `focus_changed` signal to _on_focus_changed.
	#
	#   Guard for not finding either. This label lives in main.tscn and a
	#   scene might not have a player in it (a menu, a cutscene), and a
	#   missing player should mean "no hint", not a crash.
	#
	#   ORDERING, because it bites here: main.tscn's UI is a sibling of the
	#   Player, and sibling _ready() order follows scene-tree order. If the
	#   sensor isn't found, `await get_tree().process_frame` first, then look.

	# TODO 2 — accessibility, and start hidden.
	#
	#   add_theme_font_size_override(&"font_size", <base * scale>) where the
	#   scale is Settings.text_scale, rounded to a whole number and at least 1.
	#   Then connect Settings.changed so it updates live when the slider moves
	#   (the same shape core/settings.gd documents, and what the dialogue box
	#   will do in step 9).
	#
	#   Then `visible = false` — nothing is focused at startup.
	pass


## Called whenever the sensor changes its mind about what you'd press.
## `interactable` is null when nothing is in reach.
func _on_focus_changed(_interactable: Interactable) -> void:
	# TODO 3 — show or hide.
	#
	#   null            -> visible = false
	#   an Interactable -> text = "[%s] %s" % [_input_hint(), it.prompt_verb]
	#                      visible = true
	#
	#   Rename the parameter to `interactable` once you use it; the leading
	#   underscore is Godot's "deliberately unused" convention.
	#
	#   Worth considering, not required: an object with `active = false` is
	#   skipped by the sensor entirely, so it can never reach you here. One
	#   less case to handle.
	pass


# =============================================================================
# TODO 4 — DONE, as a worked example.
# =============================================================================

## The key currently bound to [interact], so the hint reads "[E] Talk" and
## stays correct after the player remaps their controls — which they can,
## and remappable controls are on the required accessibility list. Hardcoding
## "E" is a bug that ships.
##
## Falls back to the action name if someone unbinds the keyboard entirely and
## plays on a pad. Showing a controller glyph when a pad was last used is the
## natural next step, and is deliberately not done here yet.
static func _input_hint() -> String:
	for event in InputMap.action_get_events(&"interact"):
		if event is InputEventKey:
			return (event as InputEventKey).as_text_physical_keycode()
	return "Interact"
