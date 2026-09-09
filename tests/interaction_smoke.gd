extends Node
## Headless smoke test for interaction triggers:
##
##     godot --headless --path . res://tests/interaction_smoke.tscn
##
## Drives the real main scene: walks the player up to the test-room signpost,
## verifies it takes focus, fires the [interact] action and verifies the
## `interacted` signal arrives, then turns the player away and verifies focus
## clears (facing matters — you can't read a sign with your back to it).
## Exits 0 on pass, 1 on fail — wire into CI whenever that exists.

var _player: Node2D
var _sensor: InteractionSensor
var _signpost: Interactable
var _frame := 0
var _phase := 0
var _deadline := 0
var _interacted := false


func _ready() -> void:
	# The signpost now opens the dialogue box, which pauses the tree. A pausable
	# test node would stop right there and never reach its own quit() — the run
	# hangs forever. ALWAYS keeps this harness running either way. (Different
	# from the box's own "When Paused", which runs ONLY while paused.)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	_player = main.get_node("Player")
	_sensor = main.get_node("Player/InteractionSensor")
	_signpost = main.get_node("TestRoom/Signpost")
	_signpost.interacted.connect(func(_who): _interacted = true)
	_set_phase(0, 20)


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame > 600:
		_fail("global timeout")
		return
	match _phase:
		0:  # stand just south of the signpost, looking at it
			if _frame >= _deadline:
				if _sensor.focused != null:
					_fail("focused on something from across the room")
					return
				_player.global_position = _signpost.global_position + Vector2(0, 18)
				_player.facing = Vector2.UP
				_set_phase(1, 60)
		1:  # in range and facing it -> it takes focus
			if _sensor.focused == _signpost:
				print("ok: signpost takes focus when approached")
				Input.parse_input_event(_action_event(true))
				Input.parse_input_event(_action_event(false))
				_set_phase(2, 60)
			elif _frame >= _deadline:
				_fail("signpost never took focus (focused=%s)" % _sensor.focused)
		2:  # pressing [interact] reaches the object's listener
			if _interacted:
				print("ok: interacted signal emitted on press")
				if not Dialogue.is_open:
					_fail("dialogue did not open")
					return
				if not get_tree().paused:
					_fail("dialogue did not pause the world")
					return
				print("ok: dialogue opened and paused the world")
				_set_phase(3, 120)
			elif _frame >= _deadline:
				_fail("interacted never emitted")
		3:  # click through the lines; the world must be running again after
			if Dialogue.is_open:
				Dialogue.advance()
			elif not get_tree().paused:
				print("ok: dialogue closed and the world resumed")
				_player.facing = Vector2.DOWN
				_set_phase(4, 60)
			elif _frame >= _deadline:
				_fail("dialogue never closed")
		4:  # facing away drops it, even though it is still in range
			if _sensor.focused == null:
				print("ok: focus clears when facing away")
				print("PASS: interaction smoke test")
				get_tree().quit(0)
			elif _frame >= _deadline:
				_fail("still focused while facing away")


func _action_event(pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = pressed
	return event


func _set_phase(phase: int, frames: int) -> void:
	_phase = phase
	_deadline = _frame + frames


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	print("  player=", _player.global_position, " facing=", _player.facing,
			" signpost=", _signpost.global_position,
			" focused=", _sensor.focused,
			" overlapping=", _sensor.get_overlapping_areas())
	get_tree().quit(1)
