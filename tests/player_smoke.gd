extends Node
## Headless check for the player's modular sheet slicing:
##
##     godot --headless --path . res://tests/player_smoke.tscn
##
## Verifies all four layers exist, each layer's sheet slices into the
## locked frame set (idle 2, walk per direction 4), and the AssetRegistry
## seam resolves a real sheet per layer. Exits 0 on pass, 1 on fail.

const EXPECTED := {"idle": 2, "walk_down": 4, "walk_up": 4, "walk_left": 4, "walk_right": 4}
const LAYER_NODES := {"body": "Body", "clothes": "Clothes", "face": "Face", "hair": "Hair"}


func _ready() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	var player: Player = main.get_node("Player")

	for layer in LAYER_NODES:
		var sprite := player.get_node("Visual/" + LAYER_NODES[layer]) as AnimatedSprite2D
		var frames := sprite.sprite_frames
		for anim in EXPECTED:
			if not frames.has_animation(anim):
				_fail("%s sheet missing animation %s" % [layer, anim])
				return
			var got := frames.get_frame_count(anim)
			if got != EXPECTED[anim]:
				_fail("%s/%s has %d frames, expected %d" % [layer, anim, got, EXPECTED[anim]])
				return
		if AssetRegistry.get_sprite("player_" + layer) == null:
			_fail("AssetRegistry has no sheet for player_" + layer)
			return
		print("ok: %s sliced into the full frame set" % layer)

	print("PASS: player sheet test")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	get_tree().quit(1)
