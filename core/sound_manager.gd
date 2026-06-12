extends Node
## Key-based SFX seam (docs/art-pipeline.md §9).
##
## Game systems trigger sound by logical key and never touch file paths:
##
##     SoundManager.play_sfx("mend_complete")
##
## Keys resolve to res://assets/audio/sfx/<key>.ogg (or .wav). A real clip
## dropped at that path plays with zero code edits; a missing clip is a
## one-time debug warning and silence — sound never gates anything.
##
## Owns the audio buses: Music, SFX and Ambient are created at startup so
## volume sliders and the reduced-sensory mode have stable targets.

const SFX_DIR := "res://assets/audio/sfx/"
const VOICE_COUNT := 8

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _streams: Dictionary = {}  # key -> AudioStream or null once resolved
var _warned_keys: Dictionary = {}


func _ready() -> void:
	for bus_name in ["Music", "SFX", "Ambient"]:
		_ensure_bus(bus_name)
	for i in VOICE_COUNT:
		var voice := AudioStreamPlayer.new()
		voice.bus = &"SFX"
		add_child(voice)
		_voices.append(voice)


func play_sfx(key: String, volume_db := 0.0, pitch_scale := 1.0) -> void:
	var stream := _resolve(key)
	if stream == null:
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICE_COUNT
	voice.stream = stream
	voice.volume_db = volume_db
	voice.pitch_scale = pitch_scale
	voice.play()


func stop_all() -> void:
	for voice in _voices:
		voice.stop()


func _resolve(key: String) -> AudioStream:
	if _streams.has(key):
		return _streams[key]
	var stream: AudioStream = null
	for extension in ["ogg", "wav"]:
		var path := "%s%s.%s" % [SFX_DIR, key, extension]
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
			break
	if stream == null and OS.is_debug_build() and not _warned_keys.has(key):
		_warned_keys[key] = true
		push_warning("SoundManager: no clip yet for sfx key \"%s\" (expected %s%s.ogg/.wav)."
				% [key, SFX_DIR, key])
	_streams[key] = stream
	return stream


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, bus_name)
