class_name LocationZone
extends Area2D
## A named place inside a region — the Tide Pools, the Inn. When the player
## walks in, the Region hears about it and records the discovery (the journal
## map reveals itself place by place from these, build step 7).
##
## Drop one under a region, set `location_id` and `display_name`, and size it
## with `size` (or give it your own CollisionShape2D child instead).

signal player_entered(zone: LocationZone)

## Stable id for saves and the map, e.g. &"tide_pools".
@export var location_id: StringName
## How the place is named to the player (map label, discovery text).
@export var display_name: String
## Rectangle the zone covers, centred on the node. Ignored if the zone has
## its own collision shape child.
@export var size := Vector2(96, 64)


func _ready() -> void:
	# Watches for the player; nothing needs to detect the zone itself.
	collision_layer = 0
	collision_mask = 1  # "world": the layer the player's body is on
	monitorable = false
	monitoring = true
	_ensure_shape()
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		player_entered.emit(self)


## An Area2D with no shape silently never triggers; build one from `size`.
func _ensure_shape() -> void:
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			return
	var rect := RectangleShape2D.new()
	rect.size = size
	var shape := CollisionShape2D.new()
	shape.shape = rect
	add_child(shape)
