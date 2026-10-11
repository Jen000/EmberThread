extends CanvasLayer
## The save icon: appears in the lower right corner whenever the game saves,
## then fades away. Information only — nothing to press or dismiss.

## How long the icon stays fully visible, in seconds.
const SHOW_TIME := 1.0
## How long it takes to fade out, in seconds.
const FADE_TIME := 0.5

@onready var _icon: TextureRect = $Icon
var _tween: Tween


func _ready() -> void:
	_icon.texture = AssetRegistry.get_sprite("ui_save_icon")
	_icon.hide()
	SaveManager.about_to_save.connect(_show_icon)


func _show_icon() -> void:
	if _tween != null:
		_tween.kill()  # a second save while the icon is up starts it over
	_icon.modulate.a = 1.0
	_icon.show()
	_tween = create_tween()
	_tween.tween_interval(SHOW_TIME)
	if not Settings.reduced_sensory:
		_tween.tween_property(_icon, "modulate:a", 0.0, FADE_TIME)
	_tween.tween_callback(_icon.hide)