class_name Pip
extends Node2D
## Pip — the tiny glowing fae who chose to follow the player.
##
## Two independent axes, per the GDD (§9, §17):
## - MoveState (the AI state machine): FOLLOW / NOTICING / LEADING /
##   DISTRESSED. Movement IS communication (design principle 9) — gentle
##   drift, eager pull-ahead and jagged retreat must each read distinctly
##   without any tutorial.
## - Emotion (the glow language): seven colours with smooth transitions.
##   Colour is never the only signal: every emotion also has its own pulse
##   rhythm and depth, so the language survives colourblind play, and
##   reduced sensory mode softens all of it.
##
## Pip is a sibling of the player, never a child node — following is a
## choice (principle 7). With no follow_target, Pip hovers where they are
## (how the prologue finds them).
##
## Frames resolve through AssetRegistry keys (pip_idle, pip_distressed,
## pip_leading, pip_glow, pip_shimmer); real art swaps in with zero edits
## here. The glow is an additive gradient sprite for now — upgrade path to
## the custom glow shader once the artist's frames land.

signal state_changed(state: MoveState)
signal emotion_changed(emotion: Emotion)
signal reached_object(object: Node2D)

enum MoveState { FOLLOW, NOTICING, LEADING, DISTRESSED }
enum Emotion { GOLDEN, BLUE, RED, GREEN, WHITE, PURPLE, SHIMMER }

## Glow colour, pulse speed (Hz), pulse depth and brightness per emotion.
## The rhythm carries meaning alongside the colour: safe breathes slowly,
## overwhelmed flickers fast (cozy-capped), afraid is dim and near-still.
## Hex values are provisional until the Art Brief palette lands — they
## live only here.
const EMOTION_GLOW := {
	Emotion.GOLDEN: { "color": Color(1.0, 0.78, 0.35), "speed": 0.8, "depth": 0.12, "strength": 0.85 },
	Emotion.BLUE: { "color": Color(0.30, 0.42, 0.75), "speed": 0.45, "depth": 0.06, "strength": 0.55 },
	Emotion.RED: { "color": Color(0.92, 0.33, 0.25), "speed": 4.5, "depth": 0.22, "strength": 1.0 },
	Emotion.GREEN: { "color": Color(0.55, 0.83, 0.55), "speed": 1.6, "depth": 0.18, "strength": 0.9 },
	Emotion.WHITE: { "color": Color(0.95, 0.94, 0.9), "speed": 0.35, "depth": 0.04, "strength": 0.35 },
	Emotion.PURPLE: { "color": Color(0.7, 0.45, 0.88), "speed": 2.6, "depth": 0.2, "strength": 0.95 },
	Emotion.SHIMMER: { "color": Color(1.0, 1.0, 1.0), "speed": 1.2, "depth": 0.15, "strength": 1.0 },
}

const ANIM_FPS := {
	"idle": 4.0,
	"distressed": 9.0,
	"leading": 6.0,
	"glow": 6.0,
	"shimmer": 8.0,
}

## Scene wiring for who Pip follows (resolved in _ready). At runtime, set
## `follow_target` directly instead — that's the moment Pip chooses to
## follow (prologue), or stops.
@export var follow_target_path: NodePath

var follow_target: Node2D

@export_group("Follow feel")
@export var follow_offset := Vector2(12.0, -18.0)
@export var follow_damping := 3.5
@export var bob_amplitude := 1.6
@export var bob_speed := 2.2

@export_group("Sensing (region 1 ability)")
@export var detect_radius := 56.0
@export var lead_distance := 36.0
@export var reach_radius := 24.0   ## player this close to the object = arrived
@export var lose_radius := 260.0   ## player this far from it = let it go

@export_group("Distressed feel")
@export var retreat_distance := 44.0
@export var jitter_amount := 9.0
@export var distressed_damping := 7.0

var move_state := MoveState.FOLLOW
var emotion := Emotion.GOLDEN
var sensed_object: Node2D

var _time := 0.0
var _notice_timer := 0.0
var _scan_timer := 0.0
var _jitter := Vector2.ZERO
var _jitter_timer := 0.0
var _retreat_dir := Vector2.ZERO
var _side := -1.0
var _glow_color := Color.WHITE
var _reached_emitted := false

@onready var _body: Node2D = $Body
@onready var _sprite: AnimatedSprite2D = $Body/Sprite
@onready var _glow: Sprite2D = $Body/Glow


func _ready() -> void:
	if not follow_target_path.is_empty():
		follow_target = get_node_or_null(follow_target_path)
	_build_frames()
	_glow_color = EMOTION_GLOW[emotion]["color"]
	_sprite.play("idle")


func _physics_process(delta: float) -> void:
	_time += delta
	match move_state:
		MoveState.FOLLOW:
			_process_follow(delta)
		MoveState.NOTICING:
			_process_noticing(delta)
		MoveState.LEADING:
			_process_leading(delta)
		MoveState.DISTRESSED:
			_process_distressed(delta)
	if move_state != MoveState.LEADING:
		_body.rotation = lerpf(_body.rotation, 0.0, 1.0 - exp(-6.0 * delta))
	var bob_scale := 0.35 if move_state == MoveState.DISTRESSED else 1.0
	_body.position = Vector2(0.0, sin(_time * bob_speed) * bob_amplitude * bob_scale)
	_update_glow(delta)


func set_move_state(state: MoveState) -> void:
	if state == move_state:
		return
	move_state = state
	_reached_emitted = false
	match state:
		MoveState.FOLLOW:
			sensed_object = null
			_sprite.play("idle")
			if emotion == Emotion.GREEN:
				set_emotion(Emotion.GOLDEN)
		MoveState.NOTICING:
			_notice_timer = 0.7
			_sprite.play("glow")
			set_emotion(Emotion.GREEN)
		MoveState.LEADING:
			_sprite.play("leading")
		MoveState.DISTRESSED:
			sensed_object = null
			_retreat_dir = Vector2.ZERO
			_sprite.play("distressed")
	state_changed.emit(state)


func set_emotion(value: Emotion) -> void:
	if value == emotion:
		return
	emotion = value
	if value == Emotion.SHIMMER:
		_sprite.play("shimmer")
		# The final moment's unique chime — colourblind players still feel
		# something new happening (accessibility requirement). Clip lands
		# at the SoundManager key when SFX are made.
		SoundManager.play_sfx("pip_shimmer_chime")
	emotion_changed.emit(value)


## The final-moment glow: all colours at once, never seen before.
func play_shimmer() -> void:
	set_emotion(Emotion.SHIMMER)


# --- movement states ---------------------------------------------------------

func _process_follow(delta: float) -> void:
	if follow_target == null:
		return  # hovering in place — bob still applies
	# Drift to the player's quieter side, biased by where they face.
	var facing_value = follow_target.get("facing")
	var desired_side := _side
	if facing_value is Vector2 and absf(facing_value.x) > 0.1:
		desired_side = -signf(facing_value.x)
	_side = lerpf(_side, desired_side, 1.0 - exp(-2.0 * delta))
	var wander := Vector2(sin(_time * 0.9) * 4.0, sin(_time * 1.3 + 1.7) * 3.0)
	var anchor := follow_target.global_position \
			+ Vector2(follow_offset.x * _side, follow_offset.y) + wander
	_drift_to(anchor, follow_damping, delta)

	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.25
		var found := _nearest_sensable()
		if found != null:
			sensed_object = found
			set_move_state(MoveState.NOTICING)


func _process_noticing(delta: float) -> void:
	if not is_instance_valid(sensed_object):
		set_move_state(MoveState.FOLLOW)
		return
	# The "oh!" beat: hold, glow, lean gently toward what was sensed.
	var lean := (sensed_object.global_position - global_position).limit_length(8.0)
	_drift_to(global_position + lean, 2.0, delta)
	_notice_timer -= delta
	if _notice_timer <= 0.0:
		set_move_state(MoveState.LEADING)


func _process_leading(delta: float) -> void:
	if not is_instance_valid(sensed_object) or not sensed_object.is_in_group("pip_sensable"):
		set_move_state(MoveState.FOLLOW)
		return
	var object_pos := sensed_object.global_position
	if follow_target == null:
		_drift_to(object_pos + Vector2(0, -8), 4.0, delta)
		return
	var player_pos: Vector2 = follow_target.global_position
	var to_object := object_pos - player_pos
	if to_object.length() > lose_radius:
		set_move_state(MoveState.FOLLOW)  # the player walked away; let it go
		return
	var target: Vector2
	if to_object.length() < reach_radius:
		target = object_pos + Vector2(0, -8)
		if not _reached_emitted and global_position.distance_to(target) < 6.0:
			_reached_emitted = true
			reached_object.emit(sensed_object)  # mend system hooks here later
	else:
		target = player_pos + to_object.limit_length(lead_distance) + Vector2(0, -12)
	_drift_to(target, 5.0, delta)
	# Eager forward tilt — pulling ahead should feel like pulling.
	var tilt := clampf((target.x - global_position.x) * 0.02, -0.2, 0.2)
	_body.rotation = lerpf(_body.rotation, tilt, 1.0 - exp(-6.0 * delta))


func _process_distressed(delta: float) -> void:
	var anchor := global_position
	if follow_target != null:
		if _retreat_dir == Vector2.ZERO:
			var away: Vector2 = global_position - follow_target.global_position
			_retreat_dir = away.normalized() if away.length() > 0.5 \
					else Vector2.from_angle(randf() * TAU)
		anchor = follow_target.global_position \
				+ _retreat_dir * retreat_distance + Vector2(0, -14)
	_jitter_timer -= delta
	if _jitter_timer <= 0.0:
		_jitter_timer = randf_range(0.1, 0.22)
		_jitter = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * jitter_amount
	_drift_to(anchor + _jitter, distressed_damping, delta)


# --- glow --------------------------------------------------------------------

func _update_glow(delta: float) -> void:
	var params: Dictionary = EMOTION_GLOW[emotion]
	var target_color: Color = params["color"]
	if emotion == Emotion.SHIMMER:
		target_color = Color.from_hsv(fmod(_time * 0.25, 1.0), 0.4, 1.0)
	_glow_color = _glow_color.lerp(target_color, 1.0 - exp(-3.0 * delta))

	var depth: float = params["depth"]
	var speed: float = params["speed"]
	var strength: float = params["strength"]
	if move_state == MoveState.NOTICING or move_state == MoveState.LEADING:
		depth += 0.12  # the region-1 sensing pulse
		strength = minf(strength + 0.15, 1.0)
	if Settings.reduced_sensory:
		depth *= 0.35
		speed = minf(speed, 2.2)
		strength *= 0.85

	var pulse := 1.0 + sin(_time * speed * TAU) * depth
	_glow.modulate = Color(_glow_color, clampf(strength * pulse * 0.9, 0.0, 1.0))
	_glow.scale = Vector2.ONE * 0.9 * (1.0 + (pulse - 1.0) * 0.6)
	_sprite.modulate = _sprite.modulate.lerp(
			_glow_color.lerp(Color.WHITE, 0.45), 1.0 - exp(-3.0 * delta))


# --- internals ---------------------------------------------------------------

func _drift_to(target: Vector2, damping: float, delta: float) -> void:
	global_position = global_position.lerp(target, 1.0 - exp(-damping * delta))


func _nearest_sensable() -> Node2D:
	var nearest: Node2D = null
	var best := detect_radius
	for node in get_tree().get_nodes_in_group("pip_sensable"):
		var node_2d := node as Node2D
		if node_2d == null:
			continue
		var distance := global_position.distance_to(node_2d.global_position)
		if distance <= best:
			best = distance
			nearest = node_2d
	return nearest


func _build_frames() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim in ANIM_FPS:
		frames.add_animation(anim)
		frames.set_animation_speed(anim, ANIM_FPS[anim])
		frames.set_animation_loop(anim, true)
		for texture in AssetRegistry.get_frames("pip_" + anim):
			frames.add_frame(anim, texture)
	_sprite.sprite_frames = frames
