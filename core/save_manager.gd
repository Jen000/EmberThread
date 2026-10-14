extends Node
## Save slots: where each slot's files live, and what's in them.

const SLOT_COUNT := 3
const VERSION := 1
## A var, not a const, so the tests can point it at their own folder.
var save_dir := "user://saves/"

## Sent just before a save is written, so the world can put its live
## state (like where the player is standing) into GameState first.
signal about_to_save

## The progress file for a slot, e.g. user://saves/slot_0.json
func save_path(slot: int) -> String:
	return save_dir + "slot_%d.json" % slot


## The settings file for a slot, e.g. user://saves/slot_0.settings.cfg
func settings_path(slot: int) -> String:
	return save_dir + "slot_%d.settings.cfg" % slot


## What the slot screen shows. {} = empty slot; {"broken": true} = a file
## that exists but can't be read (shown, never hidden).
func slot_info(slot: int) -> Dictionary:
	if slot < 0 or slot >= SLOT_COUNT:
		return {}
	var path := save_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return {"broken": true}
	return {
		"region_id": data.get("region_id", ""),
		"playtime": data.get("playtime", 0.0),
		"saved_at": data.get("saved_at", 0),
	}


## Remove a slot completely: progress AND settings. That player is gone.
func delete_slot(slot: int) -> void:
	for path in [save_path(slot), settings_path(slot)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## Write the current settings to a slot's settings file.
## Always use this rather than Settings.save_to for a slot: on a fresh
## computer the saves folder doesn't exist yet, and without it the
## settings would silently never be written.
func save_settings(slot: int) -> void:
	DirAccess.make_dir_recursive_absolute(save_dir)
	Settings.save_to(settings_path(slot))

func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"region_id": String(GameState.region_id),
		"player_position": [GameState.player_position.x, GameState.player_position.y],
		"discovered": GameState.discovered,
		"appearance": GameState.appearance,
		"playtime": GameState.playtime,
		"saved_at": int(Time.get_unix_time_from_system()),
		}

func from_dict(data: Dictionary) -> void:
	GameState.region_id = StringName(data.get("region_id", "coastal"))
	var pos_array = data.get("player_position", [0, 0])
	if pos_array is Array and pos_array.size() == 2:
		GameState.player_position = Vector2(pos_array[0], pos_array[1])
	else:
		GameState.player_position = Vector2.ZERO
	GameState.discovered = data.get("discovered", {})
	GameState.appearance = data.get("appearance", {})
	GameState.playtime = float(data.get("playtime", 0.0))

## Write the current GameState to a slot's file. Returns false if it couldn't.
func save_game(slot: int) -> bool:
	about_to_save.emit()
	DirAccess.make_dir_recursive_absolute(save_dir)
	var path := save_path(slot)
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file for writing: %s" % tmp)
		return false
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
	# Swap the finished file in. Until this line, the old save is untouched.
	if DirAccess.rename_absolute(tmp, path) != OK:
		push_error("Failed to replace save file: %s" % path)
		return false
	return true

## Load a slot into GameState, and switch to that player's settings.
## Returns false, with nothing changed, if the file is missing or unreadable.
func load_game(slot: int) -> bool:
	var path := save_path(slot)
	if not FileAccess.file_exists(path):
		push_error("Save file does not exist: %s" % path)
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Save file is not a dictionary: %s" % path)
		return false
	if data.get("version", 0) > VERSION:
		push_error("Save file is from a newer version of the game: %s" % path)
		return false
	# Everything above only checks. From here on, the file is good.
	from_dict(data)
	GameState.slot = slot
	Settings.load_from(settings_path(slot))
	Settings.save_to(Settings.LAST_USED)
	return true

## Save automatically, if a playthrough is running.
## `reason` only goes in the Output panel, for testing.
func autosave(reason: String) -> void:
	if GameState.slot == -1:
		return
	print("autosave: ", reason)
	save_game(GameState.slot)
