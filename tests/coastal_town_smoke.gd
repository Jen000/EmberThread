extends Node
## Headless smoke test for the Coastal Town region scene:
##
##     godot --headless --path . res://tests/coastal_town_smoke.tscn
##
## Drives the real main scene (which starts in the Coastal Town): the player
## arrives at the road spawn point, the camera is held inside the map, the
## edge walls stop you walking off it, the painted sea and the block buildings
## stop you walking into them, terrain painting picks real tiles from the
## coastal tileset, walking into the tide pools is recorded as a discovery
## exactly once, and the harbour exit talks.
## Exits 0 on pass, 1 on fail — wire into CI whenever that exists.

var _main: Node
var _town: Region
var _player: Node2D
var _discoveries: Array[StringName] = []
var _frame := 0
var _phase := 0
var _deadline := 0
var _probe: TileMapLayer


func _ready() -> void:
	# The harbour exit opens dialogue, which pauses the tree; keep running.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main = load("res://scenes/main/main.tscn").instantiate()
	add_child(_main)
	_town = _main.region as Region
	_player = _main.get_node("Player")
	if _town == null or _town.region_id != &"coastal":
		_fail("main did not start in the Coastal Town (region=%s)" % _main.region)
		return
	_town.location_discovered.connect(func(id: StringName): _discoveries.append(id))
	_check_arrival()
	_check_tileset()
	_set_phase(0, 5)


func _check_arrival() -> void:
	var spawn := _town.get_node("SpawnPoints/default") as Node2D
	if _player.global_position.distance_to(spawn.global_position) > 0.5:
		_fail("player not at spawn (%s vs %s)" % [_player.global_position, spawn.global_position])
		return
	print("ok: player arrives at the road spawn point")
	var cam := _player.get_node("Camera2D") as Camera2D
	if cam.limit_right != _town.bounds.end.x or cam.limit_bottom != _town.bounds.end.y \
			or cam.limit_left != 0 or cam.limit_top != 0:
		_fail("camera limits not set to the region bounds")
		return
	print("ok: camera limits match the region bounds")


## Paint a small sea-and-beach patch through the terrain system on a scratch
## layer and check real tiles come out: open sea, open sand, and a shoreline
## tile between them, with collision on the sea only. (ignore_empty_terrains
## is off because a fresh layer has no neighbours to ignore; with it on, the
## API leaves an isolated patch on a blank layer empty.)
func _check_tileset() -> void:
	var ground := _town.get_node("Ground") as TileMapLayer
	_probe = TileMapLayer.new()
	_probe.tile_set = ground.tile_set
	_probe.position = Vector2(0, 0)
	_town.add_child(_probe)
	var sea: Array[Vector2i] = []
	var sand: Array[Vector2i] = []
	for y in 6:
		for x in 6:
			(sea if x < 3 else sand).append(Vector2i(x, y))
	_probe.set_cells_terrain_connect(sea, 0, 0, false)   # terrain 0 = sea
	_probe.set_cells_terrain_connect(sand, 0, 1, false)  # terrain 1 = beach sand
	for cell in sea + sand:
		if _probe.get_cell_source_id(cell) == -1:
			_fail("terrain painting left %s empty" % cell)
			return
	var deep := _probe.get_cell_tile_data(Vector2i(0, 2))
	if deep.get_collision_polygons_count(0) == 0:
		_fail("open sea tile has no collision")
		return
	var beach := _probe.get_cell_tile_data(Vector2i(4, 2))
	if beach.get_collision_polygons_count(0) != 0:
		_fail("open sand tile blocks movement")
		return
	var shore := _probe.get_cell_tile_data(Vector2i(3, 2))
	if shore.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER) != 0 \
			or shore.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER) != 1:
		_fail("no shoreline tile where sea meets sand")
		return
	print("ok: terrain painting picks coastal tiles: sea blocks, sand doesn't, shoreline between")
	_probe.queue_free()


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame > 900:
		_fail("global timeout")
		return
	match _phase:
		0:  # walk east along the road, into the map's edge
			if _frame >= _deadline:
				Input.action_press(&"move_right")
				_set_phase(1, 60)
		1:  # the invisible edge wall holds
			if _frame >= _deadline:
				Input.action_release(&"move_right")
				if _player.global_position.x > _town.bounds.end.x:
					_fail("walked off the east edge (x=%s)" % _player.global_position.x)
					return
				print("ok: edge wall stops the player at x=%.1f" % _player.global_position.x)
				# Stand on the beach under the cliff and walk west into the sea.
				_player.global_position = Vector2(184, 400)
				Input.action_press(&"move_left")
				_set_phase(10, 90)
		10:  # the painted sea blocks
			if _frame >= _deadline:
				Input.action_release(&"move_left")
				if _player.global_position.x < 112.0:
					_fail("walked into the sea (x=%s)" % _player.global_position.x)
					return
				print("ok: the sea stops the player at x=%.1f" % _player.global_position.x)
				# Stand below the inn and walk up into its front wall.
				var inn := _town.get_node("Objects/Inn") as Node2D
				_player.global_position = inn.global_position + Vector2(0, 30)
				Input.action_press(&"move_up")
				_set_phase(11, 60)
		11:  # buildings block, at their base
			if _frame >= _deadline:
				Input.action_release(&"move_up")
				var inn_base := (_town.get_node("Objects/Inn") as Node2D).global_position.y
				if _player.global_position.y < inn_base - 1.0:
					_fail("walked into the inn (y=%s, base=%s)" % [_player.global_position.y, inn_base])
					return
				print("ok: the inn's front wall stops the player")
				_player.global_position = (_town.get_node("Locations/TidePools") as Node2D).global_position
				_set_phase(2, 30)
		2:  # entering the tide pools is a discovery
			if _discoveries.has(&"tide_pools"):
				print("ok: tide pools discovered on entry")
				_player.global_position = Vector2(1100, 400)  # step out...
				_set_phase(3, 20)
			elif _frame >= _deadline:
				_fail("tide pools never discovered")
		3:  # ...and back in: still only one discovery
			if _frame == _deadline - 10:
				_player.global_position = (_town.get_node("Locations/TidePools") as Node2D).global_position
			elif _frame >= _deadline:
				if _discoveries.count(&"tide_pools") != 1:
					_fail("tide pools discovered %d times" % _discoveries.count(&"tide_pools"))
					return
				print("ok: re-entering is not a second discovery")
				(_town.get_node("Objects/HarbourExit") as Interactable).interact(_player)
				_set_phase(4, 10)
		4:  # the harbour exit answers (gently) until the key gift exists
			if Dialogue.is_open:
				print("ok: harbour exit opens dialogue")
				_set_phase(5, 120)
			elif _frame >= _deadline:
				_fail("harbour exit did not open dialogue")
		5:
			if Dialogue.is_open:
				Dialogue.advance()
			elif not get_tree().paused:
				print("PASS: coastal town smoke test")
				get_tree().quit(0)
			elif _frame >= _deadline:
				_fail("dialogue never closed")


func _set_phase(phase: int, frames: int) -> void:
	_phase = phase
	_deadline = _frame + frames


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	if _player != null:
		print("  player=", _player.global_position, " discoveries=", _discoveries)
	get_tree().quit(1)
