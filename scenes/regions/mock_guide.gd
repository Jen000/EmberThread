extends Sprite2D
## The region's map mock, laid over the scene as a tracing guide while you
## paint tiles. In the editor it floats faintly above the tiles (the scene
## sets z_index 100 and a see-through modulate) so you can see where things
## go. In the game it moves underneath everything, fully opaque, so any spot
## you haven't painted yet still shows the mock instead of a void.
##
## Untick `show_in_game` once the region is fully painted (or delete the
## node — nothing depends on it).

@export var show_in_game := true


func _ready() -> void:
	z_index = -20
	modulate.a = 1.0
	visible = show_in_game
