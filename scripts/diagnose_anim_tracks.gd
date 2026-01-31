extends Node

func _ready():
	print("Diagnosing Animation Tracks...")
	diagnose("res://blue_char.tscn")
	get_tree().quit()

func diagnose(path: String):
	print("Loading: ", path)
	var scene = load(path)
	var instance = scene.instantiate()
	get_tree().root.add_child(instance) # Add to tree to validate paths
	
	# Find AnimationTree
	var anim_tree = instance.get_node_or_null("AnimationTree")
	if anim_tree:
		print("AnimationTree found: ", anim_tree.name)
		print("  Active: ", anim_tree.active)
		print("  Tree Root: ", anim_tree.tree_root)
	else:
		print("ERROR: AnimationTree not found!")

	# Find AnimationPlayer
	var anim_player = instance.get_node_or_null("CharacterModel/AnimationPlayer")
	if not anim_player:
		# Maybe it's named differently or deeper
		anim_player = find_anim_player(instance)
		
	if not anim_player:
		print("ERROR: No AnimationPlayer found!")
		return
		
	print("AnimationPlayer found at: ", anim_player.get_path())
	print("Root Node Path: ", anim_player.root_node)
	
	var root_node = anim_player.get_node_or_null(anim_player.root_node)
	if not root_node:
		print("ERROR: AnimationPlayer root node not found!")
	else:
		print("Resolved Root Node: ", root_node.name, " (", root_node.get_path(), ")")

	if not anim_player.has_animation_library("motion"):
		print("ERROR: 'motion' library not found!")
		return
		
	var lib = anim_player.get_animation_library("motion")
	var anim_list = lib.get_animation_list()
	print("Animations: ", anim_list)
	
	if "idle" in anim_list:
		check_animation(lib.get_animation("idle"), root_node)
	elif "Idle" in anim_list:
		check_animation(lib.get_animation("Idle"), root_node)
	else:
		print("ERROR: Idle animation not found in motion library")

func check_animation(anim: Animation, root_node: Node):
	print("Checking Animation: ", anim.resource_name)
	print("  Loop Mode: ", anim.loop_mode, " (0=None, 1=Linear, 2=PingPong)")
	var track_count = anim.get_track_count()
	print("Track Count: ", track_count)
	
	for i in range(min(5, track_count)): # Check first 5 tracks
		var path = anim.track_get_path(i)
		print("  Track ", i, ": ", path)
		var target = root_node.get_node_or_null(path)
		if target:
			print("    -> FOUND: ", target.name)
		else:
			print("    -> NOT FOUND! (Relative to ", root_node.get_path(), ")")

func find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var res = find_anim_player(child)
		if res: return res
	return null
