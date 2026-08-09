class_name Interactable
extends Area2D
## A thing in the world the player can press [interact] on.
##
## This is the "trigger" half of the interaction system: a small Area2D that
## sits on an object and announces itself. It deliberately knows NOTHING about
## what happens next — it emits `interacted` and lets whoever cares respond.
## That is what makes one component serve signs, NPCs, trees, doors and
## mending objects without ever growing an `if type == "sign"` branch.
##
## The other half is `interaction_sensor.gd`, a matching Area2D on the player
## that decides which nearby Interactable you actually mean.
##
## Put it in the world:
##   Area2D  (script = interactable.gd, prompt_verb = "Read")
##     Visual ...                      <- your sprite / placeholder polygon
##
## and connect the signal from wherever the response lives:
##   signpost.interacted.connect(_on_signpost_read)
##
## Note this is a *sibling* system to `sensable.gd`, not a replacement.
## Sensable = "Pip can feel this from across the room." Interactable = "you
## are standing next to this and pressed a button." A mending object will
## eventually be both, and that is fine — they answer different questions.

## Emitted when the player presses [interact] while focused on this.
## `interactor` is the actor who did it (the Player node), so a response can
## ask where they were standing or which way they faced.
signal interacted(interactor: Node2D)

## Emitted when this becomes / stops being the thing the player would hit.
## Useful later for a highlight outline, a sound, or Pip reacting.
signal focus_changed(focused: bool)

## Physics layer 3 ("interactable" — see project.godot). Interactables sit on
## it; the sensor is the only thing that looks at it. Keeping interaction on
## its own layer means it can never accidentally block movement or catch the
## walls, and you don't have to remember to tick boxes in the inspector.
const INTERACTABLE_LAYER := 1 << 2

const BASE_FONT_SIZE := 8
const PROMPT_COLOR := Color(0.949, 0.874, 0.764, 0.95)

## Shown in the prompt as e.g. "[E] Read". Keep it a plain verb — the key
## name is filled in from whatever [interact] is currently bound to, so the
## prompt stays correct after the player remaps their controls.
@export var prompt_verb := "Look"

## How close the player has to be (pixels). Add your own CollisionShape2D
## child instead if you need a non-circular reach — this is only used when
## there isn't one.
@export var radius := 16.0

## Dormant interactables are skipped entirely: no prompt, no signal. Story
## gating and "already done" both use this (same idea as Sensable.active).
@export var active := true:
	set(value):
		active = value
		_refresh_label()

## Where the prompt floats, relative to this node's origin.
@export var prompt_offset := Vector2(0, -20)

var _focused := false
var _message_time := 0.0
var _label: Label


func _ready() -> void:
	add_to_group(&"interactable")
	# Detected BY the sensor, detecting nothing itself — an Area2D that isn't
	# monitoring costs nothing per frame, and a world can hold hundreds.
	collision_layer = INTERACTABLE_LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true
	_ensure_shape()
	_build_label()
	set_process(false)  # only runs while a floating message is on screen
	Settings.changed.connect(_apply_text_scale)


## Called by the sensor when [interact] is pressed. Anything else may call it
## too — a cutscene, a tutorial, an automated test — which is exactly why the
## input handling lives in the sensor and not in here.
func interact(interactor: Node2D = null) -> void:
	if not active:
		return
	interacted.emit(interactor)


## Called by the sensor as you walk in and out of range.
func set_focused(value: bool) -> void:
	if value == _focused:
		return
	_focused = value
	_refresh_label()
	focus_changed.emit(value)


## Retire this interactable — it stops prompting and stops emitting.
## (`active = true` again brings it back; nothing here is one-way.)
func set_active(value: bool) -> void:
	active = value


## A single line of floating text above the object, for casual background
## chatter and small acknowledgements ("A few leaves come loose.").
##
## This is NOT the dialogue system. Real conversations — portrait, text box,
## paused world — arrive in build step 6 and will listen to `interacted`
## exactly like this does. This exists so an interaction can *visibly do
## something* before that lands.
func show_message(text: String, seconds := 2.5) -> void:
	_message_time = maxf(seconds, 0.0)
	_set_label(text)
	set_process(true)


func _process(delta: float) -> void:
	_message_time -= delta
	if _message_time <= 0.0:
		set_process(false)
		_refresh_label()


# --- the prompt label --------------------------------------------------------

func _build_label() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.z_index = 10
	_label.add_theme_color_override(&"font_color", PROMPT_COLOR)
	# A dark outline keeps the prompt readable over any tileset. Reduced
	# sensory mode never needs to touch this: the prompt does not pulse.
	_label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.7))
	_label.add_theme_constant_override(&"outline_size", 2)
	_label.visible = false
	add_child(_label)
	_apply_text_scale()


## Adjustable text size is a required accessibility option, so the prompt
## reads it from day one rather than being retrofitted later.
func _apply_text_scale() -> void:
	if _label == null:
		return
	_label.add_theme_font_size_override(
			&"font_size", maxi(1, roundi(BASE_FONT_SIZE * Settings.text_scale)))
	_position_label()


func _refresh_label() -> void:
	if _message_time > 0.0:
		return  # a message is showing; let it finish
	if _focused and active:
		_set_label("[%s] %s" % [input_hint(), prompt_verb])
	else:
		_label.visible = false


func _set_label(text: String) -> void:
	_label.text = text
	_label.visible = true
	_position_label()


func _position_label() -> void:
	# reset_size() shrinks the Label to its text, so centring is just maths.
	_label.reset_size()
	_label.position = prompt_offset - Vector2(_label.size.x * 0.5, _label.size.y)


## The key currently bound to [interact], so the prompt survives remapping
## (another required accessibility option). Falls back to the action name if
## someone unbinds the keyboard entirely and plays on a pad.
static func input_hint() -> String:
	for event in InputMap.action_get_events(&"interact"):
		if event is InputEventKey:
			return event.as_text_physical_keycode()
	return "Interact"


# --- internals ---------------------------------------------------------------

## An Area2D with no shape silently never triggers — the single most common
## way this system "doesn't work". Rather than make every object carry the
## same circle by hand, build one when the scene didn't provide its own.
func _ensure_shape() -> void:
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			return
	var circle := CircleShape2D.new()
	circle.radius = radius
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)
