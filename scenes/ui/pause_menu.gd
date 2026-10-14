extends CanvasLayer
## The pause screen: Esc / Start in the world. Stops the world while open.
## Resume, Save, Load, Settings, Quit to Title. Load and Settings are
## switched on by later steps.

@onready var _menu: Control = $Menu


func _ready() -> void:
	_menu.hide()
	%Resume.pressed.connect(close)
	%Save.pressed.connect(_on_save_pressed)
	%Quit.pressed.connect(_on_quit_pressed)
	%QuitYes.pressed.connect(_on_quit_confirmed)
	%QuitNo.pressed.connect(_show_buttons)
	_set_enabled(%Load, false)      # step 9 switches this on
	_set_enabled(%Settings, false)  # step 10 switches this on
	# Mouse and keyboard share one highlight: pointing at a button moves the
	# keyboard focus there too, so there's never a second, confusing one.
	for button in [%Resume, %Save, %Load, %Settings, %Quit, %QuitYes, %QuitNo]:
		button.mouse_entered.connect(_focus_if_enabled.bind(button))


func _unhandled_input(event: InputEvent) -> void:
	if _menu.visible:
		# Esc / Start / B while open: step back (confirm -> menu -> game).
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			if %ConfirmQuit.visible:
				_show_buttons()
			else:
				close()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") and not get_tree().paused:
		# Only when nothing else (dialogue, mending) has already paused.
		open()
		get_viewport().set_input_as_handled()


func open() -> void:
	get_tree().paused = true
	_set_enabled(%Save, GameState.slot != -1)  # nowhere to save without a slot
	%Message.text = ""
	_menu.show()
	_show_buttons()
	%Resume.grab_focus()


func close() -> void:
	_menu.hide()
	get_tree().paused = false


func _show_buttons() -> void:
	%ConfirmQuit.hide()
	%Buttons.show()
	%Quit.grab_focus()


func _on_save_pressed() -> void:
	if SaveManager.save_game(GameState.slot):
		%Message.text = "Saved."
	else:
		%Message.text = "Couldn't save. Your last save is still safe."


func _on_quit_pressed() -> void:
	%Buttons.hide()
	%ConfirmQuit.show()
	%QuitNo.grab_focus()  # the safe answer is the one already selected


func _on_quit_confirmed() -> void:
	get_tree().paused = false
	# TODO(step 11): go to the title screen instead of closing the game:
	# get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
	get_tree().quit()


## Grey a button out AND take it out of keyboard/controller navigation.
## (Godot still lets arrow keys land on a disabled button otherwise.)
func _set_enabled(button: Button, enabled: bool) -> void:
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


func _focus_if_enabled(button: Button) -> void:
	if not button.disabled:
		button.grab_focus()
