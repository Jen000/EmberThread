class_name Highlight
extends Node
## STUB — you're building this one. See docs/build-plan-highlight-dialogue.md
## step 3 for the walkthrough.
##
## Turns an outline on and off around whatever visual its parent owns, so the
## player can see that something is interactable before pressing anything.
##
## It is a separate Node rather than code inside Interactable for one reason:
## highlighting isn't only an interaction thing. A quest marker, a tutorial
## pointer or Pip drawing your eye to something will all want the same
## outline, on objects that can't be pressed at all.
##
## TWO PATHS, and this is the part worth understanding before you write it:
##
##   Real art (Sprite2D / AnimatedSprite2D)
##     -> shaders/outline.gdshader traces the sprite's silhouette. This is
##        the real thing, the one the game ships with.
##
##   Block placeholders (Polygon2D)
##     -> a Polygon2D has no texture, so there is no alpha edge for the
##        shader to find and it will do precisely nothing. Brighten
##        `modulate` instead until real art lands. Temporary and honest,
##        exactly like the player's placeholder sprite.
##
## Deciding which path applies at runtime (rather than making yourself
## remember) means the day the artist's PNG replaces a block, the highlight
## quietly upgrades itself with no code edit. Same rule as everything else in
## art-pipeline.md.

## Which node gets outlined. Defaults to the parent's own visual children.
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


func _ready() -> void:
	# TODO 1. Collect the visual node(s) to highlight — the target_path node
	#         if set, otherwise every Sprite2D / AnimatedSprite2D / Polygon2D
	#         under get_parent(). Store them in an array.
	# TODO 2. For each textured one, build a ShaderMaterial from
	#         load("res://shaders/outline.gdshader") and assign it.
	#         IMPORTANT: give each node its OWN ShaderMaterial instance, or
	#         they share a `strength` and light up together. (Try sharing one
	#         on purpose at some point — the bug is very informative.)
	#         Set outline_color and thickness on it; leave strength at 0.
	# TODO 3. For each Polygon2D, remember its starting `modulate` so the
	#         fallback can restore it.
	pass


## Show or hide the highlight. Called by whatever decided this object matters
## right now — for interaction that's Interactable.focus_changed.
func set_shown(value: bool) -> void:
	if value == _shown:
		return
	_shown = value
	# TODO 4. Tween each shader material's "strength" parameter to
	#         1.0 or 0.0 over fade_time.
	#         create_tween().tween_method(...) or tween_property on the
	#         material with the property path "shader_parameter/strength".
	# TODO 5. For the Polygon2D fallback, tween `modulate` between the
	#         remembered colour and a brightened version of it.
	#         (Alternative worth trying: a second, slightly larger Polygon2D
	#         behind it in outline_color. Closer to a real outline, more
	#         fiddly to position. Your call.)
	# TODO 6. Settings.reduced_sensory: if you add any pulse or shimmer to
	#         the highlight later, it must not pulse in that mode. A steady
	#         outline is fine as-is — this is a note for when you're tempted.
	pass


## True while the outline is showing. Handy in tests.
func is_shown() -> bool:
	return _shown
