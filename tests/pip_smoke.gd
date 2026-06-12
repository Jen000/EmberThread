extends Node
## Headless smoke test for Pip's state machine and sensing arc:
##
##     godot --headless --path . res://tests/pip_smoke.tscn
##
## Drives the real main scene: verifies following, the notice->lead arc on
## the test-room trinket (with curious green), reached_object on arrival,
## the distressed retreat, and the return to calm golden. Exits 0 on pass,
## 1 on fail — wire into CI whenever that exists.

var _pip: Pip
var _player: Node2D
var _trinket: Node2D
var _frame := 0
var _phase := 0
var _deadline := 0
var _reached := false


func _ready() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	_pip = main.get_node("Pip")
	_player = main.get_node("Player")
	_trinket = main.get_node("TestRoom/HiddenTrinket")
	_pip.reached_object.connect(func(_object): _reached = true)
	_set_phase(0, 40)


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame > 1200:
		_fail("global timeout")
		return
	match _phase:
		0:  # settle into following
			if _frame >= _deadline:
				if _pip.move_state != Pip.MoveState.FOLLOW:
					_fail("expected FOLLOW after settling")
					return
				if _pip.global_position.distance_to(_player.global_position) > 80.0:
					_fail("Pip is not near the player while following")
					return
				print("ok: follows near the player")
				_player.global_position = _trinket.global_position + Vector2(40, 30)
				_set_phase(1, 300)
		1:  # sense the trinket, lead toward it
			if _pip.move_state == Pip.MoveState.LEADING:
				if _pip.emotion != Pip.Emotion.GREEN:
					_fail("expected curious green while leading")
					return
				print("ok: sensed the trinket and leads, curious green")
				_player.global_position = _trinket.global_position + Vector2(8, 10)
				_set_phase(2, 300)
			elif _frame >= _deadline:
				_fail("never entered LEADING near the trinket")
		2:  # arrive together -> reached_object
			if _reached:
				print("ok: reached_object emitted at the trinket")
				_pip.set_move_state(Pip.MoveState.DISTRESSED)
				_set_phase(3, 120)
			elif _frame >= _deadline:
				_fail("reached_object never emitted")
		3:  # distressed retreat, then back to calm
			if _frame >= _deadline:
				var distance := _pip.global_position.distance_to(_player.global_position)
				if distance < 30.0:
					_fail("expected a retreat while distressed (distance %.1f)" % distance)
					return
				print("ok: distressed retreat (distance %.1f)" % distance)
				_pip.set_move_state(Pip.MoveState.FOLLOW)
				if _pip.emotion != Pip.Emotion.GOLDEN:
					_fail("expected golden after returning to follow")
					return
				print("ok: returns to follow, golden")
				print("PASS: pip smoke test")
				get_tree().quit(0)


func _set_phase(phase: int, frames: int) -> void:
	_phase = phase
	_deadline = _frame + frames


func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	print("  pip=", _pip.global_position, " state=", _pip.move_state,
			" emotion=", _pip.emotion, " target=", _pip.follow_target,
			" player=", _player.global_position,
			" trinket=", _trinket.global_position,
			" sensables=", get_tree().get_nodes_in_group("pip_sensable"))
	get_tree().quit(1)
