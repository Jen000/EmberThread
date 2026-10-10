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
	if region_scene == null:
		push_warning("Main: no region_scene set — nothing to stand on.")
		return
	region = region_scene.instantiate()
	add_child(region)
	move_child(region, 0)  # drawn under the player, Pip and the HUD
	if region is Region:
		_arrive(region as Region)


## Put the player at the region's spawn point, Pip just beside them, and keep
## the camera inside the map. Regions without the Region script (the test
## room) keep the positions set in main.tscn.
func _arrive(target: Region) -> void:
	var pip_offset := _pip.position - _player.position
	_player.global_position = target.get_spawn_position()
	_pip.global_position = _player.global_position + pip_offset
	var camera := _player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		target.apply_camera_limits(camera)
		camera.reset_smoothing()
