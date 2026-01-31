extends CharacterBody3D
class_name Player

@export var walk_speed = 5.0
@export var sprint_speed = 9.0
@export var jump_velocity = 9.0
@export var sensitivity = 0.003
@export var max_charge_time = 2.0
@export var min_throw_force = 5.0
@export var max_throw_force = 25.0
@export var is_controlled = false
@export var is_stationary = false

@export_group("Class Traits")
@export var char_color: Color = Color.WHITE
@export var can_sprint: bool = true
@export var can_ever_dash: bool = false
@export var starts_with_mask: bool = false

@onready var camera = $Camera3D
@onready var throw_point = $Camera3D/ThrowPoint
@onready var mask_scene = preload("res://mask.tscn")

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var charge_timer = 0.0
var is_charging = false
var wander_direction = Vector3.ZERO
var wander_timer = 0.0
var is_holding_mask = false
var is_transitioning = false

var can_dash = true
var is_dashing = false

@export var dash_force = 10.0
@export var dash_duration = 0.15

@onready var interaction_ray = $Camera3D/InteractionRay
@onready var held_mask_visual = $Camera3D/HeldMaskVisual
@onready var body_mesh = $BodyMesh
@onready var head_mesh = $HeadMesh


var doom_duration = 100
var doom_timer = 0.0
var doom_active = false
var is_dead = false

func _ready():
	add_to_group("characters")
	doom_timer = doom_duration
	
	if starts_with_mask:
		is_holding_mask = false
		_add_initial_mask()
	
	_apply_char_color()
	
	if is_controlled:
		possess()
	else:
		unpossess()

func _process(delta):
	# Doom timer logic
	if doom_active and not is_dead:
		doom_timer -= delta
		if doom_timer <= 0:
			die()

func _apply_char_color():
	var mat = StandardMaterial3D.new()
	mat.albedo_color = char_color
	mat.roughness = 0.8
	
	if body_mesh:
		body_mesh.set_surface_override_material(0, mat)
	if head_mesh:
		head_mesh.set_surface_override_material(0, mat)

func possess():
	is_controlled = true
	doom_active = true # Start the doom timer once possessed
	doom_timer = doom_duration # Reset timer on possession
	
	GameEvents.current_character = self
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Reset movement state
	velocity = Vector3.ZERO
	if held_mask_visual:
		held_mask_visual.visible = is_holding_mask
	
	# Set attached mask transparency if it exists
	for child in camera.get_children():
		if child.is_in_group("masks") and child.has_method("set_transparency"):
			child.set_transparency(0.8) # 80% transparent to not block view

func unpossess():
	is_controlled = false
	is_charging = false
	is_dashing = false
	charge_timer = 0.0
	if held_mask_visual:
		held_mask_visual.visible = false
	
	# Reset attached mask transparency
	for child in camera.get_children():
		if child.is_in_group("masks") and child.has_method("set_transparency"):
			child.set_transparency(0.0)
			
	# Start wandering
	_update_wander_direction()

func _update_wander_direction():
	var angle = randf_range(0, TAU)
	wander_direction = Vector3(cos(angle), 0, sin(angle))
	wander_timer = randf_range(2.0, 5.0)

func _add_initial_mask():
	var mask = mask_scene.instantiate()
	camera.add_child(mask)
	mask.attach_to(camera)

@export var cam_tilt_amount = 0.05 # Max tilt strength
@export var cam_tilt_speed = 5.0 # How fast it tilts/recovers
var mouse_input_x = 0.0

@export var base_fov = 75.0
@export var max_fov_change = 15.0 # How much it can zoom in/out
@export var fov_jitter_strength = 0.2 # How "jumpy" the FOV is

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	
	if event.is_action_pressed("reset"):
		get_tree().reload_current_scene()
	
	if not is_controlled: return
	
	if event is InputEventMouseMotion:
		mouse_input_x = event.relative.x
		rotate_y(-event.relative.x * sensitivity)
		
		# Modify Euler X directly (pitch) to stay aligned with horizon regardless of roll
		# Using local variable initialized from current rotation prevents snapping
		var pitch = camera.rotation.x
		pitch -= event.relative.y * sensitivity
		pitch = clamp(pitch, deg_to_rad(-89), deg_to_rad(89))
		camera.rotation.x = pitch

func _physics_process(delta):
	# Camera Tilt Logic
	if is_controlled:
		# Target tilt based on mouse X input (banking)
		var target_tilt = - mouse_input_x * cam_tilt_amount
		target_tilt = clamp(target_tilt, -0.1, 0.1)
		camera.rotation.z = lerp(camera.rotation.z, target_tilt, delta * cam_tilt_speed)
		mouse_input_x = lerp(mouse_input_x, 0.0, delta * 10.0)
		
		# Dynamic Jumpy FOV Logic
		# Calculate speed along look direction
		var look_dir = - camera.global_transform.basis.z
		var speed_in_look_dir = velocity.dot(look_dir)
		speed_in_look_dir = max(0.0, speed_in_look_dir) # Only forward movement counts
		
		# Decrease FOV based on speed (Zoom in effect)
		# Max speed approx 25 (dash) -> Map to max_fov_change
		speed_in_look_dir -= walk_speed
		speed_in_look_dir = clamp(speed_in_look_dir, 0, speed_in_look_dir)
		var fov_offset = remap(speed_in_look_dir, 0, 20, 0, max_fov_change)
		fov_offset = clamp(fov_offset, 0, max_fov_change)
		
		# Add jitter if moving
		if speed_in_look_dir > 1.0:
			fov_offset += randf_range(-fov_jitter_strength, fov_jitter_strength)
			
		camera.fov = lerp(camera.fov, base_fov + fov_offset, delta * 5.0)
		
	else:
		camera.rotation.z = lerp(camera.rotation.z, 0.0, delta * 5.0)
		camera.fov = lerp(camera.fov, base_fov, delta * 5.0)

	if not is_on_floor():
		velocity.y -= gravity * delta

	if is_transitioning:
		velocity.x = 0
		velocity.z = 0
	elif is_controlled:
		if is_on_floor():
			can_dash = true
		_handle_controlled_movement(delta)
		_handle_interaction(delta)
	elif not is_stationary:
		_handle_wandering(delta)

	move_and_slide()

func _handle_controlled_movement(delta):
	if is_dashing: return
	
	var is_sprinting = Input.is_action_pressed("sprint") and can_sprint
	var current_speed = sprint_speed if is_sprinting else walk_speed
	
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		if Input.is_action_just_pressed("jump") and can_dash and can_ever_dash:
			_air_dash()

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Handle horizontal movement with "floating" support for high velocities (after dash)
	var target_vel = direction * current_speed
	var h_vel = Vector2(velocity.x, velocity.z)
	var target_h = Vector2(target_vel.x, target_vel.z)
	
	if direction:
		if h_vel.length() <= current_speed:
			# Normal snappy movement
			velocity.x = target_vel.x
			velocity.z = target_vel.z
		else:
			# Decelerate gradually back to normal speed (the "float" after dash)
			var new_h = h_vel.move_toward(target_h, delta * 20.0)
			velocity.x = new_h.x
			velocity.z = new_h.y
	else:
		# Fast deceleration when no input
		var new_h = h_vel.move_toward(Vector2.ZERO, delta * 30.0)
		velocity.x = new_h.x
		velocity.z = new_h.y

func _air_dash():
	if is_dashing: return
	can_dash = false
	is_dashing = true
	
	# Dash exactly where the camera is looking (includes pitch)
	var dash_dir = - camera.global_transform.basis.z.normalized()
	
	# Scale down if looking up. 1.0 (straight up) -> jump_velocity, 0.0 (horizontal) -> dash_force
	var current_dash_speed = dash_force
	if dash_dir.y > 0:
		current_dash_speed = lerp(dash_force, jump_velocity, dash_dir.y)
	
	# Set absolute velocity for constant dash distance
	velocity = dash_dir * current_dash_speed
	
	var timer = get_tree().create_timer(dash_duration)
	await timer.timeout
	
	if is_instance_valid(self):
		is_dashing = false
		# print("Dash finished")

func _handle_interaction(delta):
	if is_holding_mask:
		_handle_throwing(delta)
	else:
		if Input.is_action_just_pressed("fire"):
			if not _try_pickup_mask():
				_detach_own_mask()
				# Start charging immediately if we just detached
				if is_holding_mask:
					_handle_throwing(delta)

func _try_pickup_mask() -> bool:
	if interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		if collider.is_in_group("masks") and not collider.is_attached:
			# Pickup goes to face now instead of hand
			collider.attach_to(camera)
			is_holding_mask = false # Stays on face until detached
			if held_mask_visual:
				held_mask_visual.visible = false
			return true
	return false

func _update_held_mask_color():
	if held_mask_visual:
		var material = StandardMaterial3D.new()
		# Match the neutral mask look
		material.albedo_color = Color(0.9, 0.9, 0.9)
		material.emission_enabled = false
		# Unique instance for held visual
		held_mask_visual.set_surface_override_material(0, material)

var is_detaching_self = false
var current_detaching_mask: Node3D = null

func _detach_own_mask():
	if is_transitioning or is_detaching_self: return
	
	current_detaching_mask = null
	for child in camera.get_children():
		if child.is_in_group("masks") and child.has_method("set_transparency"):
			current_detaching_mask = child
			break
	
	if current_detaching_mask:
		is_detaching_self = true
		is_holding_mask = true
		charge_timer = 0.0
		if Input.is_action_pressed("fire"):
			is_charging = true
		
		# Reparent to camera for easier lerping in view space
		current_detaching_mask.reparent(camera)
		
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)
		
		# Lerp from face (0,0,-0.4) to hand position - faster 0.15s
		var hand_pos = Vector3(0.3, -0.2, -0.5)
		tween.tween_property(current_detaching_mask, "transform:origin", hand_pos, 0.15)
		tween.tween_property(current_detaching_mask, "scale", Vector3.ONE * 0.5, 0.15)
		
		await tween.finished
		
		if is_instance_valid(current_detaching_mask):
			current_detaching_mask.queue_free()
			current_detaching_mask = null
		
		# Only show visual if we haven't thrown it already
		if is_holding_mask and held_mask_visual:
			_update_held_mask_color()
			held_mask_visual.visible = true
		is_detaching_self = false

func _handle_throwing(delta):
	if Input.is_action_just_pressed("fire"):
		is_charging = true
		charge_timer = 0.0
	
	if is_charging:
		charge_timer += delta
		# Pull back visual slightly as we charge
		var charge_pct = clamp(charge_timer / max_charge_time, 0.0, 1.0)
		if held_mask_visual:
			# Base hand_pos: Vector3(0.3, -0.2, -0.5)
			# Move back by 0.2m at max charge
			held_mask_visual.transform.origin = Vector3(0.3, -0.2, -0.5 + (charge_pct * 0.2))
		
		if charge_timer >= max_charge_time:
			throw_mask()
	
	if Input.is_action_just_released("fire") and is_charging:
		throw_mask()

func _handle_wandering(delta):
	wander_timer -= delta
	if wander_timer <= 0:
		_update_wander_direction()
	
	velocity.x = wander_direction.x * walk_speed * 0.5
	velocity.z = wander_direction.z * walk_speed * 0.5
	
	if velocity.length() > 0.1:
		var target_rotation = atan2(velocity.x, velocity.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, delta * 5.0)

func throw_mask():
	is_charging = false
	
	# If we are mid-detachment, cleanup the animated mask immediately
	if is_detaching_self and is_instance_valid(current_detaching_mask):
		current_detaching_mask.queue_free()
		current_detaching_mask = null
	
	var force_pct = clamp(charge_timer / max_charge_time, 0.0, 1.0)
	var final_force = lerp(min_throw_force, max_throw_force, force_pct)
	
	var mask = mask_scene.instantiate()
	get_parent().add_child(mask)
	mask.global_transform = throw_point.global_transform
	mask.thrower = self # Tell the mask who threw it
	mask.was_thrown = true
	
	var throw_dir = - camera.global_transform.basis.z
	mask.apply_central_impulse(throw_dir * final_force)
	
	is_holding_mask = false
	if held_mask_visual:
		held_mask_visual.visible = false
		held_mask_visual.transform.origin = Vector3(0.3, -0.2, -0.5) # Reset position
	charge_timer = 0.0

func has_attached_mask() -> bool:
	if is_holding_mask: return true # Holding it counts as having it safely
	
	for child in camera.get_children():
		if child.is_in_group("masks") and child.get("is_attached"):
			return true
	return false

@onready var corpse_scene = preload("res://corpse.tscn")

func die():
	# 1. Disable player node
	set_physics_process(false)
	
	# Capture state BEFORE resetting it
	var was_controlled_local = is_controlled
	
	# Only release mouse if WE were the one dying
	if was_controlled_local:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		GameEvents.trigger_game_over()
		
	is_controlled = false
	
	# 2. Spawn Corpse
	var corpse = corpse_scene.instantiate()
	get_parent().add_child(corpse)
	corpse.global_transform = global_transform
	
	# 3. Apply Color to Corpse
	var mat = StandardMaterial3D.new()
	mat.albedo_color = char_color
	mat.roughness = 0.8
	if corpse.has_node("BodyMesh"):
		corpse.get_node("BodyMesh").set_surface_override_material(0, mat)
	if corpse.has_node("HeadMesh"):
		corpse.get_node("HeadMesh").set_surface_override_material(0, mat)
		
	# 4. Transfer Camera to Corpse (so we see the fall)
	var cam_parent = corpse
	if corpse.has_node("CameraMount"):
		cam_parent = corpse.get_node("CameraMount")
	camera.reparent(cam_parent, true)
	
	# 5. Apply Death Physics
	if was_controlled_local:
		# Player Death: Guaranteed backward fall to see the sky
		# Push the HEAD (offset) BACKWARDS
		# Head is roughly at height 1.4
		var head_offset = Vector3(0, 1.4, 0)
		var backward_dir = global_transform.basis.z # basis.z is backward in Godot?
		# Wait, -basis.z is forward. basis.z is backward.
		# So to push backward, we push in direction basis.z
		
		# Let's verify direction:
		# -z is forward "look". We want to fall "on back".
		# So feet go forward, head goes backward.
		# Pushing head BACKWARD means pushing in +z (local). 
		# global_transform.basis.z points backward.
		
		var push_dir = global_transform.basis.z
		corpse.apply_impulse(push_dir * 30.0, head_offset) # Strong push at head height
		
	else:
		# Random NPC death
		var kick_dir = - global_transform.basis.z + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
		corpse.apply_central_impulse(kick_dir.normalized() * 5.0)
		corpse.apply_torque_impulse(Vector3(randf(), 0, randf()) * 2.0)
	
	# 6. Remove original player
	queue_free()
