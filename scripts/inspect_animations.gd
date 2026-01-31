extends Node

func _ready():
	var models = [
		"res://models/Breathing Idle.fbx",
		"res://models/Walking.fbx",
		"res://models/Running.fbx"
	]
	
	for path in models:
		print("Inspecting: ", path)
		var scene = load(path)
		if not scene:
			print("  Failed to load")
			continue
			
		var instance = scene.instantiate()
		var anim_player = find_animation_player(instance)
		if anim_player:
			print("  Found AnimationPlayer")
			var list = anim_player.get_animation_list()
			for anim_name in list:
				var anim = anim_player.get_animation(anim_name)
				print("    Animation: '", anim_name, "' Duration: ", anim.length, " Loop: ", anim.loop_mode)
		else:
			print("  No AnimationPlayer found")
			
		instance.queue_free()
	
	get_tree().quit()

func find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var res = find_animation_player(child)
		if res:
			return res
	return null
