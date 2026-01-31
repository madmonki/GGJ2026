extends Node3D

@onready var colorless_char_scene = preload("res://colorless_char.tscn")
@onready var blue_char_scene = preload("res://blue_char.tscn")
@onready var red_char_scene = preload("res://red_char.tscn")
@onready var green_char_scene = preload("res://green_char.tscn")
@onready var white_matte = preload("res://material/white_matte.tres")
@onready var gold_accent = preload("res://material/gold_accent.tres")

func _ready():
	# Apply Minimalist Theme
	_apply_theme()
	
	# Create procedural level
	create_parkour_level()

func _apply_theme():
	for child in get_children():
		_recursive_apply_material(child)

func _recursive_apply_material(node: Node):
	# Determine material based on node name (if it's a root of an object)
	# Logic: If a node matches a pattern, apply material to ALL its mesh children
	var mat_to_apply = null
	
	# Check patterns on the Node itself if it's one of our main objects
	var name = node.name.to_lower()
	
	# Priority 1: Gold Accents
	if "rock_small" in name or "debris" in name:
		mat_to_apply = gold_accent
	# Priority 2: White Structure (Ruins, Temples, Big Rocks)
	elif "ruin" in name or "temple" in name or "rock" in name:
		mat_to_apply = white_matte
	
	if mat_to_apply:
		_set_material_recursive(node, mat_to_apply)
	
	# Note: We don't recurse into children here to check for *other* patterns 
	# because we assume the top-level node defines the object type. 
	# If we needed to find nested objects, we'd continue recursion.

func _set_material_recursive(node: Node, material: Material):
	if node is MeshInstance3D:
		# Override all surfaces
		for i in range(node.mesh.get_surface_count()):
			node.set_surface_override_material(i, material)
	
	for child in node.get_children():
		_set_material_recursive(child, material)

func create_parkour_level():
	# Base Floor (Y=0) is our starting area
	# STAGE 1: CLIMB TO RED
	# Small stepping stones -> Gold
	create_platform(Vector3(0, 1.5, 4.0), Vector3(3, 0.2, 3), gold_accent)
	create_platform(Vector3(2.5, 3.0, 1.0), Vector3(3, 0.2, 3), gold_accent)
	create_platform(Vector3(0, 4.5, -2.0), Vector3(3, 0.2, 3), gold_accent)
	
	# PLATFORM: RED NPC (High Jump) -> White
	create_platform(Vector3(5, 6.0, -5.0), Vector3(4, 0.5, 4), white_matte)
	spawn_npc(Vector3(5, 6.2, -5.0), red_char_scene)
	
	# STAGE 2: RED JUMP TO GREEN
	# High gaps -> Gold
	create_platform(Vector3(5, 10.5, -12.0), Vector3(4, 0.2, 4), gold_accent)
	
	# PLATFORM: GREEN NPC (Dash) -> White
	create_platform(Vector3(-5, 13.0, -15.0), Vector3(4, 0.5, 4), white_matte)
	spawn_npc(Vector3(-5, 13.2, -15.0), green_char_scene)
	
	# STAGE 3: GREEN DASH TO BLUE
	# Large horizontal gap -> White (Structure)
	create_platform(Vector3(-15, 13.0, 0), Vector3(4, 0.5, 4), white_matte)
	
	# PLATFORM: BLUE NPC (Speed) -> White
	create_platform(Vector3(-15, 13.0, 10), Vector3(3, 0.5, 10), white_matte) # A long runway
	spawn_npc(Vector3(-15, 13.2, 10), blue_char_scene)
	
	# FINAL STAGE: LONG SPEED RUN + JUMP -> White
	create_platform(Vector3(0, 18.0, 15), Vector3(6, 1.0, 6), white_matte)

func create_platform(pos: Vector3, size: Vector3, material: Material = null):
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
	if material:
		mesh_instance.set_surface_override_material(0, material)
	else:
		# Fallback to white matte if none provided
		mesh_instance.set_surface_override_material(0, white_matte)

func spawn_npc(pos: Vector3, scene: PackedScene):
	var npc = scene.instantiate()
	npc.position = pos
	npc.is_stationary = true
	add_child(npc)
