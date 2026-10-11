extends Node
## Everything about the current playthrough: the one thing that gets saved
## as progress. Systems store what they need remembered here; SaveManager
## turns it into a save file and back. Nothing else writes save files.

## Which save slot this playthrough uses. -1 = no slot (e.g. main.tscn run
## on its own for testing), which means nothing gets saved.
var slot := -1
## The region the player is in.
var region_id: StringName = &"coastal"
## Where the player is standing. ZERO means "use the region's spawn point".
var player_position := Vector2.ZERO
## Places found, one list per region: { region_id: { location_id: true } }
var discovered: Dictionary = {}
## The player's chosen look.
var appearance: Dictionary = {}
## Seconds played, shown on the slot screen.
var playtime := 0.0


func _process(delta: float) -> void:
	# Only count time during a real playthrough, and not while paused.
	if slot != -1 and not get_tree().paused:
		playtime += delta


## Back to a fresh new game. Leaves `slot` alone: New Game sets that.
func reset() -> void:
	region_id = &"coastal"
	player_position = Vector2.ZERO
	discovered = {}
	appearance = {}
	playtime = 0.0