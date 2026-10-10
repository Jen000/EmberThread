@tool
class_name BlockBuilding
extends StaticBody2D
## Block stand-in for a building or large prop (cottage, inn, lighthouse,
## market stall) at its real footprint, so a town can be laid out and walked
## at true scale before building art exists. Draws in the editor too.
##
## The node's origin is the middle of the building's BASE (where it meets the
## ground), so y-sorting puts the player behind it when they're above that
## line and in front when below. Only the lower `solid_fraction` of the block
## collides: the roof overhangs, so you can walk up close to the front wall.
##
## Follows the placeholder convention (docs/art-pipeline.md §6): magenta
## border and a baked-in label, so it can't pass for finished art. Replace
## with a Sprite2D + the same collision when building art lands.

@export var size := Vector2(64, 64):  # a cottage
	set(value):
		size = value
		_refresh()
@export var label := "":
	set(value):
		label = value
		queue_redraw()
@export var wall_colour := Color(0.91, 0.86, 0.76):
	set(value):
		wall_colour = value
		queue_redraw()
@export var roof_colour := Color(0.6, 0.33, 0.25):
	set(value):
		roof_colour = value
		queue_redraw()
## Share of the height, measured up from the base, that blocks movement.
@export_range(0.1, 1.0) var solid_fraction := 0.5:
	set(value):
		solid_fraction = value
		_refresh()

const MAGENTA := Color(1, 0, 1)
const ROOF_SHARE := 0.45

var _shape: CollisionShape2D


func _ready() -> void:
	# Built here, never saved into the scene: the size export is the only
	# thing to edit.
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	add_child(_shape, false, Node.INTERNAL_MODE_FRONT)
	_refresh()


func _refresh() -> void:
	if _shape != null:
		var solid := Vector2(size.x, maxf(4.0, size.y * solid_fraction))
		(_shape.shape as RectangleShape2D).size = solid
		_shape.position = Vector2(0, -solid.y / 2.0)
	queue_redraw()


func _draw() -> void:
	var top := -size.y
	var roof_h := roundf(size.y * ROOF_SHARE)
	var body := Rect2(-size.x / 2.0, top, size.x, size.y)
	draw_rect(Rect2(body.position.x, top + roof_h, size.x, size.y - roof_h), wall_colour)
	draw_rect(Rect2(body.position, Vector2(size.x, roof_h)), roof_colour)
	draw_rect(body, MAGENTA, false, 1.0)
	if label != "":
		var font := ThemeDB.fallback_font
		var font_size := 8
		var text_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var pos := Vector2(-text_w / 2.0, top + roof_h + (size.y - roof_h) / 2.0 + 3)
		draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.15, 0.1, 0.08))
