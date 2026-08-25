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

var _focused := false
## True while the mouse cursor is over this. The sensor reads it.
var hovered := false


func _ready() -> void:
	add_to_group(&"interactable")
	# Detected BY the sensor, detecting nothing itself — an Area2D that isn't
	# monitoring costs nothing per frame, and a world can hold hundreds.
	collision_layer = INTERACTABLE_LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true
	_ensure_shape()
	# If this object has a Highlight child, let it react to focus.
	for child in get_children():
		if child is Highlight:
			focus_changed.connect((child as Highlight).set_shown)
			break
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)

func _on_mouse_entered() -> void:
	hovered = true

func _on_mouse_exited() -> void:
	hovered = false

func _on_input_event(_viewport: Node, event: InputEvent, _shape: int) -> void:
	if not (event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed):
		return
	if not _focused:
		return
	get_viewport().set_input_as_handled()
	interact(get_tree().get_first_node_in_group("player") as Node2D)


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
	focus_changed.emit(value)


## Retire this interactable — it stops prompting and stops emitting.
## (`active = true` again brings it back; nothing here is one-way.)
func set_active(value: bool) -> void:
	active = value



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
