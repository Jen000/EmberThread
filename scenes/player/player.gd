class_name Player
extends CharacterBody2D
## The mender — the player character.
##
## Cozy top-down movement: soft acceleration, gentle stop, walking pace.
## No dash, no stamina — walking is the pace of this game. The feel values
## are exported so they can be tuned from the editor while playtesting.

@export var walk_speed := 85.0
@export var acceleration := 600.0
@export var friction := 900.0

## Last non-zero movement direction — kept for facing-dependent things
## later (interactions, animation, where Pip drifts to).
var facing := Vector2.DOWN

@onready var _sprite: Sprite2D = $Sprite2D


func _physics_process(delta: float) -> void:
	# get_vector handles deadzones and normalisation, and preserves analog
	# magnitude, so a gentle stick tilt gives a gentle stroll.
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	else:
		facing = input_dir
		velocity = velocity.move_toward(input_dir * walk_speed, acceleration * delta)
		if not is_zero_approx(input_dir.x):
			_sprite.flip_h = input_dir.x < 0.0
	move_and_slide()
