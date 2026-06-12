class_name Player
extends CharacterBody2D
## The mender — the player character.
##
## Cozy top-down movement: soft acceleration, gentle stop, walking pace.
## No dash, no stamina — walking is the pace of this game. The feel values
## are exported so they can be tuned from the editor while playtesting.
##
## The visual is modular per docs/art-pipeline.md §5: base, outfit, hair
## and accessory layers stack in that draw order, each animated from
## frames resolved through AssetRegistry — never file paths. The
## customisation screen later swaps a layer's variant via
## set_appearance(); the palette-swap shader will sit on these same
## layers.

const WALK_FPS := 8.0
const IDLE_FPS := 2.0
const DIRECTIONS := ["down", "up", "left", "right"]

@export var walk_speed := 85.0
@export var acceleration := 600.0
@export var friction := 900.0

## Layer -> variant. "" means the layer name carries no variant suffix.
## Frames resolve as player_<layer>[_<variant>]_<anim> registry keys.
var appearance := {
	"base": "",
	"outfit": "default",
	"hair": "short",
	"accessory": "default",
}

## Last non-zero movement direction — facing for interactions, Pip, anims.
var facing := Vector2.DOWN

@onready var _layers := {
	"base": $Visual/Base as AnimatedSprite2D,
	"outfit": $Visual/Outfit as AnimatedSprite2D,
	"hair": $Visual/Hair as AnimatedSprite2D,
	"accessory": $Visual/Accessory as AnimatedSprite2D,
}


func _ready() -> void:
	_rebuild_layer_frames()
	_play_all("idle")


func _physics_process(delta: float) -> void:
	# get_vector handles deadzones and normalisation, and preserves analog
	# magnitude, so a gentle stick tilt gives a gentle stroll.
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	else:
		facing = input_dir
		velocity = velocity.move_toward(input_dir * walk_speed, acceleration * delta)
	move_and_slide()
	_update_animation(input_dir != Vector2.ZERO)


## Swap one layer's variant (customisation screen entry point).
func set_appearance(layer: String, variant: String) -> void:
	appearance[layer] = variant
	_rebuild_layer_frames()


## Builds each layer's SpriteFrames from the registry. The registry is the
## only seam — whatever files sit at the final paths right now are what
## appears, so real art swaps in with zero edits here.
func _rebuild_layer_frames() -> void:
	for layer in _layers:
		var frames := SpriteFrames.new()
		frames.remove_animation(&"default")
		_add_animation(frames, layer, "idle", IDLE_FPS)
		for direction in DIRECTIONS:
			_add_animation(frames, layer, "walk_" + direction, WALK_FPS)
		_layers[layer].sprite_frames = frames


func _add_animation(frames: SpriteFrames, layer: String, anim: String, fps: float) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, true)
	for texture in AssetRegistry.get_frames(_layer_key(layer, anim)):
		frames.add_frame(anim, texture)


func _layer_key(layer: String, anim: String) -> String:
	var variant: String = appearance[layer]
	if variant.is_empty():
		return "player_%s_%s" % [layer, anim]
	return "player_%s_%s_%s" % [layer, variant, anim]


func _update_animation(moving: bool) -> void:
	var direction := _facing_name()
	if moving:
		_play_all("walk_" + direction)
	elif direction == "down":
		_play_all("idle")
	else:
		# The locked spec has idle frames facing down only; resting on the
		# first walk frame keeps other facings standing naturally.
		_freeze_all("walk_" + direction)


func _facing_name() -> String:
	if absf(facing.x) > absf(facing.y):
		return "left" if facing.x < 0.0 else "right"
	return "up" if facing.y < 0.0 else "down"


func _play_all(anim: String) -> void:
	for layer in _layers:
		var sprite: AnimatedSprite2D = _layers[layer]
		if sprite.animation != anim or not sprite.is_playing():
			sprite.play(anim)


func _freeze_all(anim: String) -> void:
	for layer in _layers:
		var sprite: AnimatedSprite2D = _layers[layer]
		if sprite.animation != anim or sprite.is_playing():
			sprite.animation = anim
			sprite.frame = 0
			sprite.pause()
