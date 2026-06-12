extends Node2D
## Pip playground (debug builds only): number keys drive Pip's states so
## the movement and glow language can be felt and tuned — design principle
## 9 says the three states must read distinctly without a tutorial, and
## that is a feel target you can only verify by playing.
##
##   1  calm follow          2  distressed
##   3  cycle emotion        4  shimmer preview (final-moment glow)
##   9  toggle reduced sensory mode
##   0  reset (calm follow + golden)
##
## Walk near the faint trinket in the north-east corner to see the
## region-1 sensing arc: notice (glow pulse, green) -> lead -> hover.


func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var pip: Pip = get_tree().get_first_node_in_group("pip")
	if pip == null:
		return
	match key.physical_keycode:
		KEY_1:
			pip.set_move_state(Pip.MoveState.FOLLOW)
		KEY_2:
			pip.set_move_state(Pip.MoveState.DISTRESSED)
		KEY_3:
			pip.set_emotion(((pip.emotion + 1) % Pip.Emotion.SHIMMER) as Pip.Emotion)
		KEY_4:
			pip.play_shimmer()
		KEY_9:
			Settings.reduced_sensory = not Settings.reduced_sensory
			print("reduced sensory mode: ", "on" if Settings.reduced_sensory else "off")
		KEY_0:
			pip.set_move_state(Pip.MoveState.FOLLOW)
			pip.set_emotion(Pip.Emotion.GOLDEN)
