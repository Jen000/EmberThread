class_name Region
extends Node2D
## One explorable region: the root of a region scene (Coastal Town, Forest
## Village, ...). Main instances exactly one of these and puts the player,
## Pip and the HUD alongside it. See scenes/regions/README.md.
##
## A region owns its own space and nothing else:
## - `bounds` keeps the camera inside the map and the player from walking
##   off its edge (invisible walls are built here at runtime);
## - spawn points (Marker2D children of `SpawnPoints`) say where you arrive;
## - LocationZone children report named places as the player first enters
##   them, which the journal map will use to reveal itself (build step 7).
##
## What happens *in* the region (an NPC talking, a door opening) belongs to
## the region's own script, which extends this one — see coastal_town.gd.

## A named place was entered for the first time this session. The map and
## save systems will listen to this; nothing does yet.
signal location_discovered(location_id: StringName)

const EDGE_THICKNESS := 32

## Stable id for saves and the map, e.g. &"coastal".
@export var region_id: StringName
## Playable area in pixels. Camera limits and edge walls follow it.
@export var bounds := Rect2i(0, 0, 480, 270)

func _ready() -> void:
	_build_edge_walls()
	for zone in find_children("*", "LocationZone", true, false):
		(zone as LocationZone).player_entered.connect(_on_location_entered)


## Where the player arrives. Falls back to the middle of the map so a region
## with no spawn points is still playable.
func get_spawn_position(spawn_name: StringName = &"default") -> Vector2:
	var marker := get_node_or_null(NodePath("SpawnPoints/" + spawn_name)) as Node2D
	if marker != null:
		return marker.global_position
	return global_position + Vector2(bounds.get_center())


## Keep the camera from showing anything outside the map.
func apply_camera_limits(camera: Camera2D) -> void:
	var rect := Rect2(global_position + Vector2(bounds.position), Vector2(bounds.size))
	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)


func _on_location_entered(zone: LocationZone) -> void:
	# GameState keeps one list of found places per region.
	# The first time we're in this region, make its empty list.
	if not GameState.discovered.has(region_id):
		GameState.discovered[region_id] = {}
	var places: Dictionary = GameState.discovered[region_id]
	# If this place is new, add it and tell the world.
	if places.has(zone.location_id):
		return
	places[zone.location_id] = true
	location_discovered.emit(zone.location_id)

## Invisible walls just outside `bounds`, so nobody walks off the map before
## (or regardless of whether) the edge has blocking tiles painted on it.
func _build_edge_walls() -> void:
	var body := StaticBody2D.new()
	body.name = "EdgeWalls"
	var r := Rect2(bounds)
	var t := float(EDGE_THICKNESS)
	var edges := [
		Rect2(r.position.x - t, r.position.y - t, r.size.x + 2 * t, t),  # north
		Rect2(r.position.x - t, r.end.y, r.size.x + 2 * t, t),           # south
		Rect2(r.position.x - t, r.position.y, t, r.size.y),              # west
		Rect2(r.end.x, r.position.y, t, r.size.y),                       # east
	]
	for edge: Rect2 in edges:
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = edge.size
		var shape := CollisionShape2D.new()
		shape.shape = rect_shape
		shape.position = edge.get_center()
		body.add_child(shape)
	add_child(body)
