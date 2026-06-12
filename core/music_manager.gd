extends Node
## Key-based music seam, stubbed ahead of the composer
## (docs/art-pipeline.md §9).
##
##     MusicManager.play_music("coastal_town")
##
## Keys resolve to res://assets/audio/music/<key>.ogg (or .wav). Until a
## track exists the call is a silent no-op (plus a one-time debug warning),
## so region/scene code can wire music cues now and the composer's files
## slot in 1:1 later.

const MUSIC_DIR := "res://assets/audio/music/"

var current_key := ""

var _player: AudioStreamPlayer
var _warned_keys: Dictionary = {}


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = &"Music"
	add_child(_player)


func play_music(key: String) -> void:
	if key == current_key and _player.playing:
		return
	current_key = key
	var stream := _resolve(key)
	if stream == null:
		_player.stop()
		return
	_player.stream = stream
	_player.play()


func stop_music() -> void:
	current_key = ""
	_player.stop()


func _resolve(key: String) -> AudioStream:
	for extension in ["ogg", "wav"]:
		var path := "%s%s.%s" % [MUSIC_DIR, key, extension]
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	if OS.is_debug_build() and not _warned_keys.has(key):
		_warned_keys[key] = true
		push_warning("MusicManager: no track yet for music key \"%s\" (expected %s%s.ogg/.wav)."
				% [key, MUSIC_DIR, key])
	return null
