extends Label
## The line of text that tells the player what the button will DO, floating
## just above whatever they could act on.
##
## The outline says "something is here". It cannot say whether pressing E will
## Talk, Read or Mend — three quite different promises that look identical as
## a glow. This closes that gap, and it's the accessible half of the cue:
## presence/absence of an outline is purely visual, whereas a word can be
## read, scaled up, or spoken by a screen reader later.
##
## ONE LABEL FOR THE WHOLE GAME, moved to wherever the focused object is.
## Not one per object — adding an NPC needs no hint wiring at all, and there
## is only ever one hint on screen because there is only ever one focus.
##
## Lives at main.tscn -> UI -> InteractionHint. It sits in a CanvasLayer, so
## it is positioned in *screen* space; `_follow()` does the world -> screen
## conversion each frame so it tracks the object as the camera moves.
##
## Switched off with `Settings.interaction_hints` (settings menu pending).
##
## WHERE THE DATA COMES FROM. Nothing bespoke; both halves already existed:
##
##   InteractionSensor.focus_changed(interactable)   fires with the object when
##       you walk into range, and with null when you leave
##   Interactable.prompt_verb / .hint_offset         "Talk", and how high above

## The base size before the accessibility multiplier. Matches the dialogue box
## so the hint and the box read as the same voice.
const BASE_FONT_SIZE := 8

## The object the hint is currently describing, or null.
var _target: Interactable


func _ready() -> void:
	visible = false
	set_process(false)
	_apply_settings()
	# Live updates when the settings sliders/toggles move. Settings is an
	# autoload, so this connection outlives any scene change.
	Settings.changed.connect(_apply_settings)

	var sensor := await _find_sensor()
	if sensor != null:
		sensor.focus_changed.connect(_on_focus_changed)


## Only runs while a hint is on screen — see set_process() in _refresh().
##
## This node's process_mode is Always, so it keeps running while the tree is
## paused. That is deliberate: a paused tree means a full-screen UI is up
## (dialogue, mending), and a hint reading "[E] Mend" behind the mending
## screen would be nonsense. Hiding on pause covers every such screen without
## the hint needing to know any of them exist.
func _process(_delta: float) -> void:
	if not is_instance_valid(_target):
		return
	visible = not get_tree().paused
	if visible:
		_follow()


## Called whenever the sensor changes its mind about what you'd press.
## `interactable` is null when nothing is in reach.
func _on_focus_changed(interactable: Interactable) -> void:
	_target = interactable
	_refresh()


func _refresh() -> void:
	if _target == null or not Settings.interaction_hints:
		visible = false
		set_process(false)
		return
	text = "[%s] %s" % [_input_hint(), _target.prompt_verb]
	reset_size()  # shrink to the text so centring is just maths
	_follow()
	visible = not get_tree().paused
	set_process(true)


## World position -> screen position. The label is in a CanvasLayer, which the
## camera doesn't move, so the conversion has to be done by hand: the canvas
## transform is exactly "where the camera has put the world right now".
##
## Rounded to whole pixels deliberately. At 480x270 a half-pixel offset makes
## the text shimmer as you walk, which is the one thing that would make this
## feel cheap.
func _follow() -> void:
	var world: Vector2 = _target.global_position + _target.hint_offset
	var screen: Vector2 = get_viewport().get_canvas_transform() * world
	position = (screen - Vector2(size.x * 0.5, size.y)).round()


## Font size from the accessibility setting, and hide immediately if hints
## were just switched off.
func _apply_settings() -> void:
	add_theme_font_size_override(
			&"font_size", maxi(1, roundi(BASE_FONT_SIZE * Settings.text_scale)))
	_refresh()


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
