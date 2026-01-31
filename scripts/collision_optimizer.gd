extends Node

func _ready():
	print("Starting collision optimization...")
	
	# Load the source FBX scene
	var scene = load("res://models/SM_Ruins_01.fbx")
	if not scene:
		print("Error: Could not load FBX")
		get_tree().quit()
		return
		
	var instance = scene.instantiate()
	add_child(instance)
	
	# Find the first MeshInstance3D
	var mesh_instance = find_mesh_instance(instance)
	if not mesh_instance:
		print("Error: No MeshInstance3D found")
		get_tree().quit()
		return
		
	print("Found mesh: ", mesh_instance.name)
	
	# Generate Convex Shape
	# Note: creating convex shape allows much faster physics than concave "trimesh"
	var shape = mesh_instance.mesh.create_convex_shape(true, true)
	
	if shape:
		var err = ResourceSaver.save(shape, "res://material/sm_ruins_col.tres")
		if err == OK:
			print("Success: Saved sm_ruins_col.tres")
		else:
			print("Error saving resource: ", err)
	else:
		print("Error: Failed to create shape")
		
	get_tree().quit()

func find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	
	for child in node.get_children():
		var result = find_mesh_instance(child)
		if result:
			return result
			
	return null
