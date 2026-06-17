class_name Player
extends CharacterBody2D
## The mender — the player character.
##
## Cozy top-down movement: soft acceleration, gentle stop, walking pace.
## No dash, no stamina — walking is the pace of this game. The feel values
## are exported so they can be tuned from the editor while playtesting.
##
## The visual is modular (docs/art-pipeline.md §5): four layers stack
## back-to-front — body, clothes, face, hair — each a single spritesheet
## sliced on a fixed grid. The sheet texture is resolved through
## AssetRegistry (never a file path), so the artist's sheet overwrites the
## stand-in with zero code edits. The customisation screen swaps a layer's
## variant via set_appearance(); the palette-swap shader sits on these
## layers (skin tone on body, eye colour on face, hair colour on hair,
## the recolourable zones on clothes).

const WALK_FPS := 8.0
const IDLE_FPS := 2.0

## Spritesheet contract — every player layer sheet is this grid of 16×32
## cells. anim -> [row, frame_count]; columns run left-to-right. The
## artist draws to this layout; slicing here stays fixed.
const FRAME_SIZE := Vector2i(16, 32)
const SHEET_LAYOUT := {
	"idle": [0, 2],
	"walk_down": [1, 4],
	"walk_up": [2, 4],
	"walk_left": [3, 4],
	"walk_right": [4, 4],
}

@export var walk_speed := 85.0
@export var acceleration := 600.0
@export var friction := 900.0

## Layer -> variant. "" means the base sheet (player_<layer>.png); a
## variant resolves to player_<layer>_<variant>.png. Draw order is the
## node order under Visual: body, clothes, face, hair.
var appearance := {
	"body": "",
	"clothes": "",
	"face": "",
	"hair": "",
}

## Last non-zero movement direction — facing for interactions, Pip, anims.
var facing := Vector2.DOWN

@onready var _layers := {
	"body": $Visual/Body as AnimatedSprite2D,
	"clothes": $Visual/Clothes as AnimatedSprite2D,
	"face": $Visual/Face as AnimatedSprite2D,
	"hair": $Visual/Hair as AnimatedSprite2D,
}
@onready var _visual: Node2D = $Visual
@onready var _placeholder: AnimatedSprite2D = $Placeholder

## The AnimatedSprite2D(s) driven by _update_animation — either the four
## modular layers or, while stand-in art is present, the single flat
## placeholder sprite.
var _active: Array[AnimatedSprite2D] = []


func _ready() -> void:
	_setup_visual()
	_play_all("idle")


## Modular layers are the real target and are always built. If whole-sprite
## stand-in art is present (player_placeholder_*), it is shown instead until
## real layered art lands — delete those files and the modular layers return,
## with zero code edits.
func _setup_visual() -> void:
	_rebuild_layer_frames()
	if AssetRegistry.has_asset("player_placeholder_idle"):
		_placeholder.sprite_frames = _build_placeholder_frames()
		var texture := AssetRegistry.get_sprite("player_placeholder_idle")
		if texture != null:
			_placeholder.position = Vector2(0, -texture.get_height() / 2.0)  # feet at origin
		_placeholder.visible = true
		_visual.visible = false
		_active = [_placeholder]
	else:
		_placeholder.visible = false
		_visual.visible = true
		_active = [_layers["body"], _layers["clothes"], _layers["face"], _layers["hair"]]


func _build_placeholder_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim in SHEET_LAYOUT:
		var key := "player_placeholder_%s" % anim
		frames.add_animation(anim)
		frames.set_animation_loop(anim, true)
		frames.set_animation_speed(anim, IDLE_FPS if anim == "idle" else WALK_FPS)
		for texture in AssetRegistry.get_frames(key):
			frames.add_frame(anim, texture)
	return frames


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


## Builds each layer's SpriteFrames by slicing its sheet on the grid. The
## registry is the only seam — whatever sheet sits at the final path now is
## what appears, so real art swaps in with zero edits here.
func _rebuild_layer_frames() -> void:
	for layer in _layers:
		_layers[layer].sprite_frames = _slice_sheet(AssetRegistry.get_sprite(_layer_key(layer)))


func _slice_sheet(sheet: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim in SHEET_LAYOUT:
		var row: int = SHEET_LAYOUT[anim][0]
		var count: int = SHEET_LAYOUT[anim][1]
		frames.add_animation(anim)
		frames.set_animation_loop(anim, true)
		frames.set_animation_speed(anim, IDLE_FPS if anim == "idle" else WALK_FPS)
		if sheet == null:
			continue  # missing layer: empty animation, nothing drawn
		for col in count:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(
					col * FRAME_SIZE.x, row * FRAME_SIZE.y, FRAME_SIZE.x, FRAME_SIZE.y)
			frames.add_frame(anim, atlas)
	return frames


func _layer_key(layer: String) -> String:
	var variant: String = appearance[layer]
	if variant.is_empty():
		return "player_%s" % layer
	return "player_%s_%s" % [layer, variant]


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
	for sprite in _active:
		if sprite.animation != anim or not sprite.is_playing():
			sprite.play(anim)


func _freeze_all(anim: String) -> void:
	for sprite in _active:
		if sprite.animation != anim or sprite.is_playing():
			sprite.animation = anim
			sprite.frame = 0
			sprite.pause()
