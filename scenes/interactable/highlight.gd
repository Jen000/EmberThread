class_name Highlight
extends Node
## STUB — you're building this one. See docs/build-plan-highlight-dialogue.md
## step 3. TODO 1 is filled in as a worked example; 2–6 are yours.
##
## Turns an outline on and off around whatever visual its parent owns, so the
## player can see that something is interactable before pressing anything.
##
## It is a separate Node rather than code inside Interactable for one reason:
## highlighting isn't only an interaction thing. A quest marker, a tutorial
## pointer or Pip drawing your eye to something will all want the same
## outline, on objects that can't be pressed at all.
##
## ---------------------------------------------------------------------------
## GODOT VOCABULARY you'll need here. Skim it once; the TODOs assume it.
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



# =============================================================================
# TODO 1 — DONE, as a worked example. Read it, then carry the style into 2–6.
# =============================================================================
func _ready() -> void:
	for node in _find_visuals():
		if node is Polygon2D:
			_polygon_targets.append(node)
		else:
			_shader_targets.append(node)
	_build_materials()   

	# TODO 2 goes here — see below.
func _build_materials() -> void:
	for node in _shader_targets:
		var mat := ShaderMaterial.new()
		mat.shader = OUTLINE_SHADER
		mat.set_shader_parameter("outline_color", outline_color)
		mat.set_shader_parameter("thickness", thickness)
		mat.set_shader_parameter("strength", 0.0)     #<- starts invisible
		node.material = mat

	# TODO 3 goes here — see below.
	_base_modulate[node] = node.modulate


## The nodes this highlight affects: the target_path node if one was set,
## otherwise every visual directly under our parent.
##
## Your signpost has TWO visible pieces (Visual = the post, Board = the sign),
## which is exactly why this returns a list and not one node. It skips Solid
## and its CollisionShape2D — those are collision, not something you can see.
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


# =============================================================================
# TODO 2 — give every textured node its own outline material.
#
# Write a function (call it _build_materials) and call it from _ready().
# For each node in _shader_targets:
#
#   1. var mat := ShaderMaterial.new()
#   2. mat.shader = OUTLINE_SHADER
#   3. mat.set_shader_parameter("outline_color", outline_color)
#      mat.set_shader_parameter("thickness", thickness)
#      mat.set_shader_parameter("strength", 0.0)      <- starts invisible
#   4. node.material = mat
#
# set_shader_parameter() takes the uniform name as a STRING, matching the
# `uniform` lines in shaders/outline.gdshader exactly. A typo here fails
# silently — no error, the value just never arrives. If nothing happens
# later, check the spelling here first.
#
# WHY A NEW ShaderMaterial PER NODE, rather than building one and assigning
# it to all of them: materials are Resources, and resources are shared by
# reference. One material across ten objects means one `strength` across ten
# objects — walk near a crate, the whole room lights up. Worth doing wrong
# once on purpose; the bug is very memorable.
#
# HOW TO CHECK IT: your signpost is Polygon2D blocks, so _shader_targets is
# EMPTY and this does nothing visible. That's correct, not a bug. To see the
# shader path work, add a Sprite2D to the test room, set its Texture to any
# PNG under assets/sprites/, and put a Highlight under it.
# =============================================================================


# =============================================================================
# TODO 3 — remember what the blocks looked like before you touched them.
#
# You're about to change each Polygon2D's `modulate`, and you need to put it
# back afterwards. Store the originals in a Dictionary keyed by the node:
#
#   var _base_modulate: Dictionary = {}      (declare it up with the others)
#   _base_modulate[node] = node.modulate
#
# A Dictionary rather than a parallel array because looking up "what was this
# node's colour" by the node itself can't fall out of sync.
#
# In practice these will all be white — that IS the default — but reading the
# real value means a designer tinting a block in the inspector doesn't get it
# silently reset the first time the player walks past.
# =============================================================================


## Show or hide the highlight. Called by whatever decided this object matters
## right now — for interaction that's Interactable.focus_changed.
func set_shown(value: bool) -> void:

	if value == _shown:
		return
	_shown = value

	# TODO 4 and TODO 5 go here — see below.

	tween.tween_property(mat, "shader_parameter/strength", 1.0 _shown else 0.0, fade_time)
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


# =============================================================================
# TODO 4 — fade the outline in and out.
#
# Tweens are the Godot way to animate a property over time. The shape:
#
#   var tween := create_tween()
#   tween.tween_property(<object>, <property path>, <end value>, <seconds>)
#
# For a shader uniform the property path is the odd one. It is NOT the plain
# uniform name — it's the string "shader_parameter/strength", on the MATERIAL,
# not the node:
#
#   tween.tween_property(mat, "shader_parameter/strength", 1.0, fade_time)
#
# (I verified that exact path animates 0.0 -> 1.0 on Godot 4.4, because it
# looks wrong enough to doubt.)
#
# Three things to handle:
#
#   a. The end value is 1.0 when `value` is true, 0.0 when false.
#
#   b. Several materials at once. By default a tween runs its steps one after
#      another, so three sprites would fade in sequence. tween.set_parallel(true)
#      before adding them makes them run together.
#
#   c. Walking quickly in and out starts a second tween while the first is
#      still going, and they fight. Keep the tween in a variable
#      (`var _tween: Tween`) and at the top of set_shown():
#
#        if _tween != null and _tween.is_running():
#            _tween.kill()
#
#      Getting the node's material back out is node.material as ShaderMaterial.
#
# HOW TO CHECK IT: on your Sprite2D test object, walk in and out. The outline
# should ease rather than pop. Set fade_time to 2.0 temporarily to be sure
# it's really tweening and not just switching.
# =============================================================================


# =============================================================================
# TODO 5 — the block-placeholder fallback.
#
# Same tween, different property. For each node in _polygon_targets, animate
# `modulate` between its remembered value and a brightened one:
#
#   var lit: Color = _base_modulate[node] * PLACEHOLDER_BRIGHTNESS
#   tween.tween_property(node, "modulate", lit, fade_time)
#
# and back to _base_modulate[node] when hiding.
#
# WHY MULTIPLY RATHER THAN Color.lightened(): I rendered both. lightened()
# blends toward white, so the brown signpost goes pale and dusty — it reads
# as "faded", the opposite of what you want. Multiplying past 1.0 raises
# brightness while keeping the hue, which reads as lit up. Godot is fine with
# modulate components above 1.0; it isn't clamped until the final draw.
#
# Note `_base_modulate[node] * PLACEHOLDER_BRIGHTNESS` multiplies alpha too,
# which is harmless at alpha 1.0 and wrong for a semi-transparent object. If
# you ever highlight one, build the Color channel by channel instead.
#
# HOW TO CHECK IT: walk up to the signpost. Post AND board brighten together,
# and go back to exactly their old colour when you leave. If one stays lit,
# your hide path is missing a node.
# =============================================================================


# =============================================================================
# TODO 6 — accessibility note, nothing to write yet.
#
# A steady outline is fine as-is and needs no special handling. But if you
# later add a pulse or shimmer, it MUST hold still when Settings.reduced_sensory
# is on — that flag exists exactly for things that catch the eye by moving.
# Pip's glow already reads it (scenes/pip/pip.gd, _update_glow) if you want
# the pattern to copy.
# =============================================================================


## True while the outline is showing. Handy in tests.
func is_shown() -> bool:
	return _shown