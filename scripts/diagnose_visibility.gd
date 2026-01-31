extends Node

func _ready():
	print("Diagnosing Player Character Visibility...")
	diagnose("res://player.tscn")
	get_tree().quit()

func diagnose(path: String):
	print("Loading: ", path)
	var scene = load(path)
	var instance = scene.instantiate()
	
	var mesh = instance.get_node_or_null("CharacterModel/Skeleton3D/Cube")
	if not mesh:
		print("  'CharacterModel/Skeleton3D/Cube' not found, searching recursively...")
		mesh = find_character_mesh(instance)
	
	if not mesh:
		print("ERROR: No Character Mesh found!")
	else:
		print("MeshInstance3D found: ", mesh.name)
		print("  Path: ", mesh.get_path())
		print("  Visible: ", mesh.visible)
		print("  Scale: ", mesh.scale)
		print("  Global Transform: ", mesh.global_transform)
		if mesh.mesh:
			print("  Mesh Resource: ", mesh.mesh.resource_name)
			var aabb = mesh.mesh.get_aabb()
			print("  AABB: ", aabb)
			print("  AABB Size: ", aabb.size)
		else:
			print("  ERROR: Mesh resource is null")
			
		print("  Skin: ", mesh.skin)
		print("  Skeleton Path: ", mesh.skeleton)
		var skel = mesh.get_node_or_null(mesh.skeleton)
		if skel:
			print("  Skeleton Node Found: ", skel.name)
			print("  Bone Count: ", skel.get_bone_count())
		else:
			print("  ERROR: Skeleton node not found at path")

	instance.queue_free()

func find_character_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node.name != "HeldMaskVisual":
		return node
	for child in node.get_children():
		var res = find_character_mesh(child)
		if res: return res
	return null
