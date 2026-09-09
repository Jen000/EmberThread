class_name Highlight
extends Node
## Turns an outline on and off around whatever visual its parent owns, so the
## player can see that something is interactable before pressing anything.
##
## It is a separate Node rather than code inside Interactable for one reason:
## highlighting isn't only an interaction thing. A quest marker, a tutorial
## pointer or Pip drawing your eye to something will all want the same
## outline, on objects that can't be pressed at all.
##
## ---------------------------------------------------------------------------
## GODOT VOCABULARY, kept as a reference for whoever picks this up next.
##
##   CanvasItem     The base class of everything drawn in 2D. Sprite2D,
##                  AnimatedSprite2D and Polygon2D are all CanvasItems, which
##                  is why one array can hold any of them.
##
##   material       A property every CanvasItem has. Assign a ShaderMaterial
##                  to it and your shader runs on that node's pixels.
##
##   Resource       Anything that lives in the .../ tree as data rather than a
##                  node — Shader, ShaderMaterial, Texture2D. The important
##                  part: resources are shared by REFERENCE. Two nodes handed
##                  the same ShaderMaterial share every setting on it.
##
##   modulate       A colour every CanvasItem multiplies itself by. White
##                  (1,1,1,1) is "unchanged", which is why it's the default.
##                  Values ABOVE 1.0 brighten — that's the fallback trick
##                  below.
##
##   Tween          A short-lived object that animates a property over time.
##                  You create one, tell it what to animate, and it runs
##                  itself. It dies when finished; you make a new one next
##                  time. Never store one and reuse it.
##
##   _ready()       Called once when the node enters the tree. CHILDREN run
##                  _ready() BEFORE their parent, which matters here: when
##                  this runs, Interactable._ready() has not run yet.
## ---------------------------------------------------------------------------
##
## TWO PATHS, and this is the part worth understanding before you write it:
##
##   Real art (Sprite2D / AnimatedSprite2D)
##     -> shaders/outline.gdshader traces the sprite's silhouette. This is
##        the real thing, the one the game ships with.
##
##   Block placeholders (Polygon2D)
##     -> a Polygon2D has no texture, so there is no alpha edge for the
##        shader to find and it will do precisely nothing. Brighten it with
##        `modulate` instead until real art lands.
##
## Deciding which path applies at runtime (rather than making yourself
## remember) means the day the artist's PNG replaces a block, the highlight
## quietly upgrades itself with no code edit. Same rule as everything else in
## art-pipeline.md.

## preload() loads at compile time rather than when the line runs, so a typo
## in this path is an error the moment you open the project, not a mystery
## crash later when someone finally walks near a sign.
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")

## How much to brighten block placeholders. 1.5 = 150% brightness. Measured
## by eye against the test-room signpost: 1.2 is too subtle to notice, 2.0
## blows out to near-white.
const PLACEHOLDER_BRIGHTNESS := 1.5

## Which node gets outlined. Leave empty (the normal case) and it finds every
## visual under its parent by itself.
@export var target_path: NodePath

## Warm pale gold by default. Deliberately NOT Pip's exact calm colour —
## the player should never mistake a highlighted crate for Pip.
@export var outline_color := Color(1.0, 0.93, 0.72)

## Outline width in texture pixels. 1.0 suits 16x16 objects.
@export var thickness := 1.0

## Seconds to fade in/out. Instant on/off reads as a flicker when you walk
## along a row of objects; ~0.12 is enough to feel soft without feeling laggy.
@export var fade_time := 0.12

var _shown := false

## Split by path, not one mixed array: the two get treated completely
## differently and never together, so sorting them once here keeps
## set_shown() to two plain loops instead of a type check per node per frame.
var _shader_targets: Array[CanvasItem] = []
var _polygon_targets: Array[Polygon2D] = []
var _tween: Tween
var _base_modulate: Dictionary = {}


func _ready() -> void:
	for node in _find_visuals():
		if node is Polygon2D:
			_polygon_targets.append(node)
		else:
			_shader_targets.append(node)
	_build_materials()


func _build_materials() -> void:
	for node in _shader_targets:
		var mat := ShaderMaterial.new()
		mat.shader = OUTLINE_SHADER
		mat.set_shader_parameter("outline_color", outline_color)
		mat.set_shader_parameter("thickness", thickness)
		mat.set_shader_parameter("strength", 0.0)     #<- starts invisible
		node.material = mat

	# Remember the blocks' starting colour so the fade can put it back. Its own
	# loop: these are the polygons, not the sprites the loop above handled.
	for node in _polygon_targets:
		_base_modulate[node] = node.modulate


## The nodes this highlight affects: the target_path node if one was set,
## otherwise every visual directly under our parent.
##
## Returns a list, not one node, because an object usually has several visible
## pieces — the test-room signpost is a post plus a board. Collision children
## are skipped: they aren't something you can see.
func _find_visuals() -> Array[CanvasItem]:
	var found: Array[CanvasItem] = []
	if not target_path.is_empty():
		var node := get_node_or_null(target_path) as CanvasItem
		if node != null:
			found.append(node)
		return found
	for child in get_parent().get_children():
		if child is Sprite2D or child is AnimatedSprite2D or child is Polygon2D:
			# The `as CanvasItem` is required, not decoration: get_children()
			# hands you Array[Node], and putting a plain Node into an
			# Array[CanvasItem] fails at runtime.
			found.append(child as CanvasItem)
	return found


## Show or hide the highlight. Called by whatever decided this object matters
## right now — for interaction that's Interactable.focus_changed.
func set_shown(value: bool) -> void:
	if value == _shown:
		return
	_shown = value

	# Stop whatever fade was already running, or the two fight each other.
	if _tween != null and _tween.is_running():
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)

	var strength := 1.0 if _shown else 0.0
	for node in _shader_targets:
		var mat := node.material as ShaderMaterial
		if mat != null:
			_tween.tween_property(mat, "shader_parameter/strength", strength, fade_time)

	for node in _polygon_targets:
		var base: Color = _base_modulate[node]
		var target := base * PLACEHOLDER_BRIGHTNESS if _shown else base
		_tween.tween_property(node, "modulate", target, fade_time)


## True while the outline is showing. Handy in tests.
func is_shown() -> bool:
	return _shown
