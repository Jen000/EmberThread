extends Node2D
## The game's root: one region, plus the player, Pip and the HUD that travel
## with you from region to region.
##
## `region_scene` picks where the game starts. It is the Coastal Town; the
## old test room (scenes/main/test_room.tscn) still works as a playground —
## drag it into `region_scene` on the Main node to play there instead. The
## smoke tests do exactly that.
##
## Main is y-sorted so the player and Pip pass behind buildings and trees in
## the region (the region's own y-sorted children sort together with them).

## The region the game starts in.
@export var region_scene: PackedScene

## The region currently loaded (null until _ready).
var region: Node2D

@onready var _player: Node2D = $Player
@onready var _pip: Node2D = $Pip


func _ready() -> void:
	SaveManager.about_to_save.connect(_remember_position)
	if region_scene == null:
		push_warning("Main: no region_scene set — nothing to stand on.")
		return
	region = region_scene.instantiate()
	add_child(region)
	move_child(region, 0)  # drawn under the player, Pip and the HUD
	Dialogue.finished.connect(_on_dialogue_finished)
	if region is Region:
		(region as Region).location_discovered.connect(_on_location_discovered)
		_arrive(region as Region)


## Put the player at the region's spawn point, Pip just beside them, and keep
## the camera inside the map. Regions without the Region script (the test
## room) keep the positions set in main.tscn.
func _arrive(target: Region) -> void:
	if GameState.player_position != Vector2.ZERO:
		_player.global_position = GameState.player_position
	else:
		_player.global_position = target.get_spawn_position()
		SaveManager.autosave("arrived in a region")
	var pip_offset := _pip.position - _player.position
	_pip.global_position = _player.global_position + pip_offset
	var camera := _player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		target.apply_camera_limits(camera)
		camera.reset_smoothing()

## Just before a save, copy where the player is standing into GameState.
func _remember_position() -> void:
	GameState.player_position = _player.global_position


	## Debug keys (debug builds only): F2 saves to slot 1, F3 loads it.
func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_F2:
		GameState.slot = 0
		print("saved: ", SaveManager.save_game(0))
	elif key.physical_keycode == KEY_F3:
		if SaveManager.load_game(0):
			get_tree().reload_current_scene()

func _on_dialogue_finished() -> void:
	SaveManager.autosave("conversation finished")


func _on_location_discovered(_location_id: StringName) -> void:
	SaveManager.autosave("new place discovered")
