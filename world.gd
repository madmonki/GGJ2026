extends Node3D

@onready var colorless_char_scene = preload("res://colorless_char.tscn")
@onready var blue_char_scene = preload("res://blue_char.tscn")
@onready var red_char_scene = preload("res://red_char.tscn")
@onready var green_char_scene = preload("res://green_char.tscn")
func _ready():
	# Clear any residual children (walls, characters, stray masks)
	for child in get_children():
		if child is StaticBody3D and "Wall" in child.name:
			child.queue_free()
		if child.is_in_group("characters") and not child.is_controlled:
			child.queue_free()
		if child.is_in_group("masks"):
			# Only remove if it's not currently being thrown or attached to a character
			if not (child.get("is_attached") or child.get("was_thrown")):
				child.queue_free()

	create_parkour_level()

func create_parkour_level():
	# Base Floor (Y=0) is our starting area
	# STAGE 1: CLIMB TO RED
	# Small stepping stones
	create_platform(Vector3(0, 1.5, 4.0), Vector3(3, 0.2, 3))
	create_platform(Vector3(2.5, 3.0, 1.0), Vector3(3, 0.2, 3))
	create_platform(Vector3(0, 4.5, -2.0), Vector3(3, 0.2, 3))
	
	# PLATFORM: RED NPC (High Jump)
	create_platform(Vector3(5, 6.0, -5.0), Vector3(4, 0.5, 4))
	spawn_npc(Vector3(5, 6.2, -5.0), red_char_scene)
	
	# STAGE 2: RED JUMP TO GREEN
	# High gaps that only Red can reach
	create_platform(Vector3(5, 10.5, -12.0), Vector3(4, 0.2, 4))
	
	# PLATFORM: GREEN NPC (Dash)
	# Far horizontally + high
	create_platform(Vector3(-5, 13.0, -15.0), Vector3(4, 0.5, 4))
	spawn_npc(Vector3(-5, 13.2, -15.0), green_char_scene)
	
	# STAGE 3: GREEN DASH TO BLUE
	# Large horizontal gap (requires Air Dash)
	create_platform(Vector3(-15, 13.0, 0), Vector3(4, 0.5, 4))
	
	# PLATFORM: BLUE NPC (Speed)
	create_platform(Vector3(-15, 13.0, 10), Vector3(3, 0.5, 10)) # A long runway
	spawn_npc(Vector3(-15, 13.2, 10), blue_char_scene)
	
	# FINAL STAGE: LONG SPEED RUN + JUMP
	# Far platform that might need speed for momentum or just a final dash
	create_platform(Vector3(0, 18.0, 15), Vector3(6, 1.0, 6))

func create_platform(pos: Vector3, size: Vector3):
	var static_body = StaticBody3D.new()
	static_body.position = pos
	add_child(static_body)
	
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	static_body.add_child(mesh_instance)
	
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	collision_shape.shape = box_shape
	static_body.add_child(collision_shape)
	
	# Visual styling for platforms
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.35)
	mesh_instance.set_surface_override_material(0, mat)

func spawn_npc(pos: Vector3, scene: PackedScene):
	var npc = scene.instantiate()
	npc.position = pos
	npc.is_stationary = true
	add_child(npc)
