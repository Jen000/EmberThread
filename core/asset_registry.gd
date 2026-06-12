extends Node
## The single seam between art and code (docs/art-pipeline.md §4).
##
## Systems request art by logical key — the filename stem, minus the
## two-digit animation-frame suffix — and never touch file paths:
##
##     AssetRegistry.get_sprite("pip_idle")      # first frame
##     AssetRegistry.get_frames("pip_idle")      # every frame, in order
##     AssetRegistry.get_portrait("sable")       # npc_sable_portrait
##
## The registry scans res://assets/ once at startup and maps keys to
## paths via the locked naming convention (§3). Lookups always resolve to
## whatever file currently sits at the final path, so real art overwrites
## a stand-in with zero code edits (§10).
##
## It also owns temp-art tracking (§6, §8):
## - block placeholders are listed with content hashes in
##   assets/stand_ins.json (written by tools/make_placeholders.py); once
##   real art overwrites a file the hash stops matching and it drops off
##   the report automatically;
## - sourced gap-filler is listed in assets/temp_assets.md;
## - debug builds print every stand-in and gap-filler still in use at
##   startup, plus a one-line summary warning. Ship gate: both lists empty.

const ASSETS_ROOT := "res://assets"
const STAND_INS_MANIFEST := "res://assets/stand_ins.json"
const TEMP_ASSETS_MANIFEST := "res://assets/temp_assets.md"

var _paths_by_key: Dictionary = {}     # key -> Array[String], frame order
var _stand_in_hashes: Dictionary = {}  # path -> sha256 at generation time
var _temp_paths: Array[String] = []    # sourced gap-filler paths
var _warned_keys: Dictionary = {}
var _frame_suffix: RegEx


func _ready() -> void:
	_frame_suffix = RegEx.new()
	_frame_suffix.compile("^(.+)_\\d{2}$")
	_scan_dir(ASSETS_ROOT)
	for key in _paths_by_key:
		_paths_by_key[key].sort()  # zero-padded _NN sorts lexically
	_load_manifests()
	if OS.is_debug_build():
		_report_temp_art()


## First (or only) frame registered under `key`, or null.
func get_sprite(key: String) -> Texture2D:
	var frames := get_frames(key)
	return frames[0] if not frames.is_empty() else null


## Every frame registered under `key`, in _NN order. A key with no frame
## suffix ("npc_sable_portrait") yields a single-element array.
func get_frames(key: String) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	if not _paths_by_key.has(key):
		_warn_missing(key)
		return textures
	for path in _paths_by_key[key]:
		var texture := load(path) as Texture2D
		if texture != null:
			textures.append(texture)
	return textures


## Dialogue portrait for a character, e.g. get_portrait("sable").
func get_portrait(character: String) -> Texture2D:
	return get_sprite("npc_%s_portrait" % character)


func has_asset(key: String) -> bool:
	return _paths_by_key.has(key)


func frame_count(key: String) -> int:
	return _paths_by_key[key].size() if _paths_by_key.has(key) else 0


## Block-placeholder files still byte-identical to their generated form.
func stand_ins_in_use() -> Array[String]:
	var remaining: Array[String] = []
	for path in _stand_in_hashes:
		if FileAccess.file_exists(path) \
				and FileAccess.get_sha256(path) == _stand_in_hashes[path]:
			remaining.append(path)
	remaining.sort()
	return remaining


## Sourced gap-filler (assets/temp_assets.md) still present in the project.
func temp_art_in_use() -> Array[String]:
	var remaining: Array[String] = []
	for path in _temp_paths:
		if _registered(path):
			remaining.append(path)
	remaining.sort()
	return remaining


# --- internals --------------------------------------------------------------

func _scan_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scan_dir(path)
		else:
			_register_file(path)
		entry = dir.get_next()
	dir.list_dir_end()


func _register_file(path: String) -> void:
	# Exported builds list imported textures as <name>.png.import/.remap.
	if path.ends_with(".import") or path.ends_with(".remap"):
		path = path.get_basename()
	if not path.ends_with(".png"):
		return
	var key := path.get_file().get_basename()
	var match_result := _frame_suffix.search(key)
	if match_result != null:
		key = match_result.get_string(1)
	if not _paths_by_key.has(key):
		_paths_by_key[key] = []
	if not _paths_by_key[key].has(path):
		_paths_by_key[key].append(path)


func _registered(path: String) -> bool:
	for key in _paths_by_key:
		if _paths_by_key[key].has(path):
			return true
	return false


func _load_manifests() -> void:
	if FileAccess.file_exists(STAND_INS_MANIFEST):
		var parsed = JSON.parse_string(
				FileAccess.get_file_as_string(STAND_INS_MANIFEST))
		if typeof(parsed) == TYPE_DICTIONARY:
			_stand_in_hashes = parsed
	if FileAccess.file_exists(TEMP_ASSETS_MANIFEST):
		for line in FileAccess.get_file_as_string(TEMP_ASSETS_MANIFEST).split("\n"):
			var trimmed := line.strip_edges()
			if trimmed.begins_with("| res://"):
				_temp_paths.append(trimmed.split("|")[1].strip_edges())


func _report_temp_art() -> void:
	var blocks := stand_ins_in_use()
	var sourced := temp_art_in_use()
	if blocks.is_empty() and sourced.is_empty():
		print("AssetRegistry: no temp art in use - art pass complete.")
		return
	for path in blocks:
		print("  [stand-in]   ", path)
	for path in sourced:
		print("  [gap-filler] ", path)
	push_warning("AssetRegistry: %d block stand-in(s) and %d gap-filler asset(s) still in use (listed above). Ship gate: zero of each."
			% [blocks.size(), sourced.size()])


func _warn_missing(key: String) -> void:
	if OS.is_debug_build() and not _warned_keys.has(key):
		_warned_keys[key] = true
		push_warning("AssetRegistry: no asset registered for key \"%s\"." % key)
