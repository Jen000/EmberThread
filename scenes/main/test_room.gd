extends Node2D
## Pip playground (debug builds only): number keys drive Pip's states so
## the movement and glow language can be felt and tuned — design principle
## 9 says the three states must read distinctly without a tutorial, and
## that is a feel target you can only verify by playing.
##
##   1  calm follow          2  distressed
##   3  cycle emotion        4  shimmer preview (final-moment glow)
##   9  toggle reduced sensory mode
##   0  reset (calm follow + golden)
##
## The ground is a hand-painted TileMapLayer (Jen's map-making experiment,
## merged in from tilesets/testlevel.tscn). It spans 0,0 to 352,304; the
## `Walls` StaticBody2D is an invisible ring at that edge so you can't walk
## off into nothing while tile collision is still being sorted out. Paint
## straight onto the TileMapLayer node here — it isn't an instanced scene.
##
## Walk near the faint trinket up near the top to see the region-1 sensing
## arc: notice (glow pulse, green) -> lead -> hover.
##
## The Signpost is the worked example for interaction triggers
## (scenes/interactable/README.md): walk up to it and press E.
##
## Signpost and Lantern each carry a Highlight, and they exercise its two
## different paths — see docs/build-plan-highlight-dialogue.md step 3:
##   Signpost  Polygon2D blocks -> the `modulate` brightening fallback
##   Lantern   a real texture   -> the outline shader
## Both follow the player now that step 4 has wired Highlight to
## Interactable.focus_changed.

@onready var _signpost: Interactable = $Signpost
@onready var _lantern_sprite: Sprite2D = $Lantern/Sprite2D
@onready var _fisherman: Interactable = $Fisherman
@onready var _fisherman_sprite: Sprite2D = $Fisherman/Sprite2D


func _ready() -> void:

	_fisherman.interacted.connect(_on_fisherman_talk)


	# This is the whole pattern: the Interactable announces that it was
	# pressed, and the scene that owns the object decides what that means.
	# Nothing about signs, trees or NPCs lives inside the component.
	_signpost.interacted.connect(_on_signpost_read)

	# Texture resolved by logical key, never by path — art-pipeline.md §4.
	# Real lantern art overwriting the block stand-in appears here with no
	# code change.
	_fisherman_sprite.texture = AssetRegistry.get_sprite("npc_fisherman_sprite")
	_lantern_sprite.texture = AssetRegistry.get_sprite("object_lantern_broken")

func _on_signpost_read(_interactor: Node2D) -> void:
	Dialogue.say("signpost", ["Harbour, down the hill.", "Mind the fog."])

func _on_fisherman_talk(_interactor: Node2D) -> void:
	Dialogue.say("fisherman", ["Hmph,That light of yours is a bit much for my eyes.", "I can't see the fish with it on.", "Turn that damn thing off!"])

func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return


	var pip: Pip = get_tree().get_first_node_in_group("pip")
	if pip == null:
		return
	match key.physical_keycode:
		KEY_1:
			pip.set_move_state(Pip.MoveState.FOLLOW)
		KEY_2:
			pip.set_move_state(Pip.MoveState.DISTRESSED)
		KEY_3:
			pip.set_emotion(((pip.emotion + 1) % Pip.Emotion.SHIMMER) as Pip.Emotion)
		KEY_4:
			pip.play_shimmer()
		KEY_9:
			Settings.reduced_sensory = not Settings.reduced_sensory
			print("reduced sensory mode: ", "on" if Settings.reduced_sensory else "off")
		KEY_0:
			pip.set_move_state(Pip.MoveState.FOLLOW)
			pip.set_emotion(Pip.Emotion.GOLDEN)
