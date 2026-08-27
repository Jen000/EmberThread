extends Label
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
## Lives at main.tscn -> UI -> InteractionHint, anchored centre-bottom just
## above the ControlsHint line.
##
## WHERE THE DATA COMES FROM. Nothing bespoke; both halves already existed:
##
##   InteractionSensor.focus_changed(interactable)   fires with the object when
##       you walk into range, and with null when you leave
##   Interactable.prompt_verb                        "Talk", "Read", "Mend"
##
## `prompt_verb` had been unread since the floating prompt was deleted in step
## 1. This is the home it was waiting for.

## The base size before the accessibility multiplier. Matches the dialogue box
## so the hint and the box read as the same voice.
const BASE_FONT_SIZE := 8


func _ready() -> void:
	visible = false
	_apply_text_scale()
	# Live updates when the settings slider moves (step 9). Settings is an
	# autoload, so this connection outlives any scene change.
	Settings.changed.connect(_apply_text_scale)

	var sensor := await _find_sensor()
	if sensor != null:
		sensor.focus_changed.connect(_on_focus_changed)


## Called whenever the sensor changes its mind about what you'd press.
## `interactable` is null when nothing is in reach.
func _on_focus_changed(interactable: Interactable) -> void:
	if interactable == null:
		visible = false
		return
	text = "[%s] %s" % [_input_hint(), interactable.prompt_verb]
	visible = true


## Adjustable text size is a required accessibility option, so the hint reads
## the setting rather than baking a size into the scene.
func _apply_text_scale() -> void:
	add_theme_font_size_override(
			&"font_size", maxi(1, roundi(BASE_FONT_SIZE * Settings.text_scale)))


## The player's sensor, or null in a scene that has no player (a menu, a
## cutscene) — in which case there is simply never a hint.
##
## The UI layer is a *sibling* of the Player in main.tscn, and sibling _ready()
## order follows scene-tree order, so on the first look the player may not
## exist yet. One frame's wait is enough; after that it genuinely isn't there.
func _find_sensor() -> InteractionSensor:
	for attempt in 2:
		var player := get_tree().get_first_node_in_group(&"player")
		if player != null:
			for child in player.get_children():
				if child is InteractionSensor:
					return child as InteractionSensor
		if attempt == 0:
			await get_tree().process_frame
	return null


## The key currently bound to [interact], so the hint reads "[E] Talk" and
## stays correct after the player remaps their controls — which they can, and
## remappable controls are on the required accessibility list. Hardcoding "E"
## is a bug that ships.
##
## Falls back to the action name if someone unbinds the keyboard entirely and
## plays on a pad. Showing a controller glyph when a pad was last used is the
## natural next step, and is deliberately not done here yet.
static func _input_hint() -> String:
	for event in InputMap.action_get_events(&"interact"):
		if event is InputEventKey:
			return (event as InputEventKey).as_text_physical_keycode()
	return "Interact"
