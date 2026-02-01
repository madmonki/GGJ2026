extends Node

func _ready():
	print("Starting Character Setup...")
	setup_characters()
	print("Character Setup complete.")
	get_tree().quit()

func setup_characters():
	var targets = [
		"res://player.tscn",
		"res://blue_char.tscn",
		"res://red_char.tscn",
		"res://green_char.tscn",
		"res://colorless_char.tscn"
	]
	
	# Load animation sources
	var idle_src = load("res://models/Breathing Idle.fbx")
	var walk_src = load("res://models/Walking.fbx")
	var run_src = load("res://models/Running.fbx")
	
	if not (idle_src and walk_src and run_src):
		print("Error: Could not load model FBXs")
		return
		
	# Extract animations (Duplicate them to make unique resources)
	var anim_idle = extract_animation(idle_src, "Idle")
	var anim_walk = extract_animation(walk_src, "Walk")
	var anim_run = extract_animation(run_src, "Run")
	
	if not (anim_idle and anim_walk and anim_run):
		print("Error: Could not extract animations")
		return

	# Setup AnimationLibrary
	var anim_lib = AnimationLibrary.new()
	anim_lib.add_animation("Idle", anim_idle)
	anim_lib.add_animation("Walk", anim_walk)
	anim_lib.add_animation("Run", anim_run)

	for path in targets:
		process_character(path, anim_lib)

func extract_animation(packed_scene: PackedScene, new_name: String) -> Animation:
	var instance = packed_scene.instantiate()
	var anim_player = find_animation_player(instance)
	var anim = null
	if anim_player and anim_player.has_animation("mixamo_com"):
		anim = anim_player.get_animation("mixamo_com").duplicate()
		anim.resource_name = new_name
		anim.loop_mode = Animation.LOOP_LINEAR
	instance.queue_free()
	return anim

func find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var res = find_animation_player(child)
		if res:
			return res
	return null

func process_character(path: String, anim_lib: AnimationLibrary):
	print("Processing: ", path)
	var packed_scene = load(path)
	if not packed_scene:
		print("  Error loading")
		return
		
	var instance = packed_scene.instantiate()
	
	# 1. Remove old meshes
	var body_mesh = instance.get_node_or_null("BodyMesh")
	if body_mesh:
		body_mesh.free()
		print("  Removed BodyMesh")
		
	var head_mesh = instance.get_node_or_null("HeadMesh")
	if head_mesh:
		head_mesh.free()
		print("  Removed HeadMesh")
		
	var existing_model = instance.get_node_or_null("CharacterModel")
	if existing_model:
		existing_model.free()
		print("  Removed existing CharacterModel")
		
	# Remove any existing AnimationTrees to prevent duplicates
	var old_trees = []
	for child in instance.get_children():
		if child is AnimationTree:
			old_trees.append(child)
	for tree in old_trees:
		tree.free()
		print("  Removed existing AnimationTree")

	# 2. Add New Model (Breathing Idle as base)
	var model_scene = load("res://models/Breathing Idle.fbx")
	var model_instance = model_scene.instantiate()
	model_instance.name = "CharacterModel"
	instance.add_child(model_instance)
	model_instance.owner = instance
	
	# Fix transform (FBX often needs scaling/rotation)
	# Confirmed microscopic (16cm), scaling by 10 to get ~1.6m
	model_instance.scale = Vector3(10, 10, 10)
	model_instance.transform.origin = Vector3(0, 0, 0)
	
	# 3. Setup AnimationPlayer
	# The instantiated model has its own AnimationPlayer internal to it usually.
	# We want to use THAT player or replace it.
	# Easiest: Use the internal player, add our library.
	var anim_player = find_animation_player(model_instance)
	if anim_player:
		# Add our library
		# Note: We can't easily replace the "Global" library of an imported scene instance at runtime persistently without making it local.
		# Best approach: Make dependencies local? Or just add a NEW AnimationPlayer at root.
		# But the tracks in Animation point to "RootNode/Skeleton...".
		# If we use the internal player, tracks are correct.
		# We'll add the library to the internal player.
		# But since it's an imported scene, we might need to "Editable Children" logic equivalent.
		# Actually, we can just add the library to the player instance.
		# But for saving to .tscn, the model_instance is a *reference* to .fbx.
		# We cannot Modify the internal nodes of an instance and save them unless we set owner?
		# Or we can make it local.
		# Let's try adding a NEW AnimationPlayer to the Character root, and retargeting animations?
		# No, Retargeting is hard.
		# Better: Just set the AnimationModel to be "Editable Children" effectively by tricking it? 
		# No, let's just use the internal player but we can't save modifications to it easily if it's a subscene.
		# WAIT. We can just injecting the library into the AnimationPlayer of the instantiated node,
		# AND make sure we set that player's owner to `instance` if we want to save it?
		# No, the player belongs to the FBX scene.
		# Standard Godot Workflow:
		# right click -> Editable Children.
		# In script: We can't toggle "editable children".
		# But we can iterate children of model_instance, set their owner to `instance`.
		# This effectively "Makes Local".
		make_children_local(model_instance, instance)
		
		# Now we can find the player again (it's now part of `instance` scene)
		anim_player = find_animation_player(model_instance) # It's still there
		if anim_player:
			var lib_name = "motion"
			if not anim_player.has_animation_library(lib_name):
				anim_player.add_animation_library(lib_name, anim_lib)
				print("  Added Animation Library")
				
			# Create AnimationTree
			var anim_tree = AnimationTree.new()
			anim_tree.name = "AnimationTree"
			anim_tree.tree_root = create_anim_machine(lib_name)
			# Force explicit path relative to the tree node
			# Structure: Root -> [AnimationTree, CharacterModel -> AnimationPlayer]
			# So path is ../CharacterModel/AnimationPlayer
			anim_tree.anim_player = NodePath("../CharacterModel/AnimationPlayer")
			anim_tree.active = true
			instance.add_child(anim_tree)
			anim_tree.owner = instance
			print("  Created AnimationTree")

	# Save
	var new_packed_scene = PackedScene.new()
	new_packed_scene.pack(instance)
	ResourceSaver.save(new_packed_scene, path)
	print("  Saved: ", path)
	instance.queue_free()

func make_children_local(node: Node, new_owner: Node):
	if node != new_owner:
		node.owner = new_owner
	for child in node.get_children():
		make_children_local(child, new_owner)

func create_anim_machine(lib_name: String) -> AnimationNodeBlendSpace1D:
	return create_blend_space(lib_name)

func create_blend_space(lib_name: String) -> AnimationNodeBlendSpace1D:
	var bs = AnimationNodeBlendSpace1D.new()
	bs.add_blend_point(create_anim_node(lib_name + "/Idle"), 0.0)
	bs.add_blend_point(create_anim_node(lib_name + "/Walk"), 2.0) # Assume walk speed ~2m/s
	bs.add_blend_point(create_anim_node(lib_name + "/Run"), 5.0) # Assume run speed ~5m/s
	return bs

func create_anim_node(anim_name: String) -> AnimationNodeAnimation:
	var n = AnimationNodeAnimation.new()
	n.animation = anim_name
	return n
