extends Node

var current_character: CharacterBody3D = null
var transition_camera: Camera3D = null
var selected_doom_duration: float = 15.0
var session_start_time: float = 0.0
var is_victory: bool = false

signal game_over
signal victory(total_time: float)

func _ready():
	transition_camera = Camera3D.new()
	add_child(transition_camera)
	transition_camera.current = false

func trigger_game_over():
	game_over.emit()

func trigger_victory():
	if is_victory: return
	is_victory = true
	var total_time = (Time.get_ticks_msec() / 1000.0) - session_start_time
	victory.emit(total_time)

func start_session():
	print("[GameEvents] Session started at: ", Time.get_ticks_msec())
	session_start_time = Time.get_ticks_msec() / 1000.0
	is_victory = false

func possess_transition(from_char: CharacterBody3D, to_char: CharacterBody3D, hit_offset: Vector3 = Vector3.ZERO):
	if not from_char or not to_char:
		if to_char: to_char.possess()
		return

	# Camera transition
	transition_camera.global_transform = from_char.camera.global_transform
	transition_camera.make_current()
	
	var start_rotation = transition_camera.global_rotation
	
	from_char.unpossess()
	
	to_char.is_transitioning = true
	to_char.velocity = Vector3.ZERO
	current_character = to_char
	
	# 90-degree turning logic based on hit side
	var local_hit = to_char.global_transform.basis.inverse() * hit_offset
	if abs(local_hit.x) > abs(local_hit.z):
		# Hit from side
		if local_hit.x > 0: # Right
			to_char.rotate_y(deg_to_rad(90))
		else: # Left
			to_char.rotate_y(deg_to_rad(-90))
	
	var target_pos = to_char.camera.global_position
	
	# Tween transition
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUINT)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(transition_camera, "global_position", target_pos, 0.2)
	transition_camera.global_rotation = start_rotation
	
	await tween.finished
	
	# Finalize possession
	var target_world_rotation = transition_camera.global_rotation
	
	to_char.possess()
	to_char.possess()
	to_char.is_transitioning = false
	to_char.velocity = Vector3.ZERO
	
	to_char.rotation.y = target_world_rotation.y
	to_char.camera.rotation.x = target_world_rotation.x
	
	transition_camera.current = false
