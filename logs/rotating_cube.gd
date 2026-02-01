extends MeshInstance3D

func _process(delta):
	rotate_y(delta)
	rotate_x(delta * 0.5)
