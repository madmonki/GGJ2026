extends Node

var current_character: CharacterBody3D = null
var transition_camera: Camera3D = null

signal game_over

func _ready():
	transition_camera = Camera3D.new()
	add_child(transition_camera)
	transition_camera.current = false

func trigger_game_over():
	game_over.emit()

func possess_transition(from_char: CharacterBody3D, to_char: CharacterBody3D, hit_offset: Vector3 = Vector3.ZERO):
	if not from_char or not to_char:
		if to_char: to_char.possess()
		return

	# Set transition camera to start at 'from' position
	transition_camera.global_transform = from_char.camera.global_transform
	transition_camera.make_current()
	
	# Maintain rotation throughout lerp
	var start_rotation = transition_camera.global_rotation
	
	# Disable old control
	from_char.unpossess()
	
	# Stop new character from moving
	to_char.is_transitioning = true
	to_char.velocity = Vector3.ZERO
	current_character = to_char
	
	# Target 90-degree turning logic
	# If hit from the right side, person turns left 90 degrees.
	# "Hit from right" means hit_offset.x is positive in target local space?
	# Or simpler: hit_offset vector in world space, project onto target's local X axis.
	var local_hit = to_char.global_transform.basis.inverse() * hit_offset
	if abs(local_hit.x) > abs(local_hit.z):
		# Hit from side
		if local_hit.x > 0: # Hit from right
			to_char.rotate_y(deg_to_rad(90)) # Turn left 90? Rotation is CCW, so +90 is turn left.
		else: # Hit from left
			to_char.rotate_y(deg_to_rad(-90)) # Turn right 90
	
	# Target position (where the camera will end up)
	# We need to calculate it BEFORE we finish, but let it be dynamic if needed.
	# But for simplicity, we use the value at this moment.
	var target_pos = to_char.camera.global_position
	
	# Tween the transition position only
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUINT)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(transition_camera, "global_position", target_pos, 0.2)
	# Ensure rotation stays exactly same during tween (just in case)
	transition_camera.global_rotation = start_rotation
	
	await tween.finished
	
	# Finalize possession
	# Important: Adjust to_char's rotation and camera rotation to match the current transition camera's rotation
	# so there is no jump when switching to to_char.camera.
	
	# Current world rotation we want to keep
	var target_world_rotation = transition_camera.global_rotation
	
	to_char.possess()
	to_char.possess()
	to_char.is_transitioning = false
	to_char.velocity = Vector3.ZERO
	
	# Apply final rotation to new character
	# First, set the body rotation (Y)
	to_char.rotation.y = target_world_rotation.y
	# Then set the camera's local X rotation (pitch)
	to_char.camera.rotation.x = target_world_rotation.x
	
	transition_camera.current = false
