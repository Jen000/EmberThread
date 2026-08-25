class_name InteractionSensor
extends Area2D
## The player's half of the interaction system: finds what's in reach, picks
## the one you mean, and presses the button on it.
##
## It lives as a child of the Player so `player.gd` stays about walking. The
## split is the whole design:
##
##   Interactable  "I am here, I can be talked to / read / shaken"
##   Sensor        "of the things here, THIS is the one you mean"
##   the listener  "...and here is what happens"
##
## Choosing the target is the part people get wrong. Nearest-wins alone feels
## bad the moment two objects sit side by side — you face the sign, the game
## opens the barrel. So distance is weighed against where the player is
## facing, and things clearly behind you are ignored outright.

## Emitted when the highlighted target changes (null when nothing is in
## reach). The HUD, a tutorial, or Pip can hang off this later.
signal focus_changed(interactable: Interactable)

## Emitted after a successful press, alongside the Interactable's own
## `interacted` signal. Handy for one global hook: autosave, an SFX, an
## "interactions made" counter.
signal interacted(interactable: Interactable)

## How far the player can reach (pixels, from their feet). Combined with each
## Interactable's own radius — roughly two tiles of total reach by default.
@export var radius := 14.0

## How strongly facing beats distance when several things are in range.
## 0.0 = pure nearest-wins. Higher = "the thing I'm looking at", even if
## something else is a little closer.
@export var facing_bias := 0.8

## Anything more than this far off from straight-ahead is ignored (dot
## product: 1.0 = dead ahead, 0.0 = beside you, -1.0 = directly behind).
@export var behind_cutoff := -0.35

## The Interactable that would respond right now, or null.
var focused: Interactable

## Whose `facing` we read. Defaults to the parent (the Player).
var _actor: Node2D


func _ready() -> void:
	_actor = get_parent() as Node2D
	# Mirror of the Interactable's setup: this one does the looking, so it
	# monitors layer 3 and sits on no layer of its own.
	collision_layer = 0
	collision_mask = Interactable.INTERACTABLE_LAYER
	monitoring = true
	monitorable = false
	_ensure_shape()


func _physics_process(_delta: float) -> void:
	_set_focus(_best_candidate())


## Input lives here, not on the Interactable, so there is exactly one place
## in the game that turns a button press into an interaction.
##
## `_unhandled_input` (rather than `_input`) means any UI that opens later —
## dialogue box, journal, pouch — gets the press first simply by existing.
## And marking it handled stops the same press from being read twice by
## anything further down the chain.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"interact"):
		return
	if focused == null:
		return
	var target := focused
	get_viewport().set_input_as_handled()
	target.interact(_actor)
	interacted.emit(target)


func _set_focus(target: Interactable) -> void:
	if target == focused:
		return
	if is_instance_valid(focused):
		focused.set_focused(false)
	focused = target
	if target != null:
		target.set_focused(true)
	focus_changed.emit(target)


## Lowest score wins: distance in pixels, discounted by how squarely the
## player faces it. Everything about how targeting *feels* is these ten lines
## — tune `facing_bias` and `behind_cutoff` while playing, not on paper.
func _best_candidate() -> Interactable:
	var best: Interactable = null
	var best_score := INF
	var facing := _facing()
	for area in get_overlapping_areas():
		var candidate := area as Interactable
		if candidate.hovered:
			return candidate  # you are pointing at it; facing doesn't get a veto
		if candidate == null or not candidate.active:
			continue
		var to_target: Vector2 = candidate.global_position - global_position
		var distance := to_target.length()
		var alignment := 1.0
		if distance > 0.5:
			alignment = facing.dot(to_target / distance)
		if alignment < behind_cutoff:
			continue  # behind you — you did not mean this one
		var score := distance - alignment * facing_bias * radius
		if score < best_score:
			best_score = score
			best = candidate
	return best


func _facing() -> Vector2:
	# Read loosely (like Pip does) so this component works on any actor that
	# happens to expose `facing` — the player today, an NPC or a test harness
	# tomorrow.
	if _actor != null:
		var value = _actor.get("facing")
		if value is Vector2 and value.length_squared() > 0.0:
			return value.normalized()
	return Vector2.DOWN


func _ensure_shape() -> void:
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			return
	var circle := CircleShape2D.new()
	circle.radius = radius
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)

## True while this interactable is within the player's reach.
func is_in_reach(interactable: Interactable) -> bool:
	return interactable in get_overlapping_areas()