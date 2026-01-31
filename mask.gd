extends RigidBody3D

var thrower: Node3D = null
var is_active: bool = true
var is_attached: bool = false
var was_thrown: bool = false
var mask_color: Color = Color.WHITE

func _ready():
	add_to_group("masks")
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	$HitDetector.body_entered.connect(_on_character_hit)
	
	_apply_color(mask_color)
func _apply_color(_color: Color):
	if has_node("MeshInstance3D"):
		var mesh_instance = $MeshInstance3D
		var material = StandardMaterial3D.new()
		# Reverted to neutral white/grey as per user request
		material.albedo_color = Color(0.9, 0.9, 0.9)
		material.emission_enabled = false
		material.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
		mesh_instance.set_surface_override_material(0, material)

func _on_character_hit(body):
	if not is_active or is_attached or not was_thrown:
		return
		
	if body.has_method("possess") and body != thrower:
		attach_to(body)
		GameEvents.possess_transition(thrower, body, global_transform.origin - body.global_transform.origin)

func _on_body_entered(_body):
	if not is_active or is_attached:
		return
	
	# Only world hits here (ground/walls) since collision mask excludes characters
	is_active = false
	freeze = true
	# Keep it there indefinitely

func attach_to(target):
	is_attached = true
	is_active = false
	freeze = true
	
	if has_node("CollisionShape3D"):
		$CollisionShape3D.set_deferred("disabled", true)
	if has_node("HitDetector/CollisionShape3D"):
		$HitDetector/CollisionShape3D.set_deferred("disabled", true)
	
	# Prefer attaching to Camera3D if available (for look direction and Player logic)
	var parent_node = target
	if target.has_node("Camera3D"):
		parent_node = target.get_node("Camera3D")
	
	call_deferred("reparent", parent_node)
	
	# Position on face
	call_deferred("_finalize_attachment")

func _finalize_attachment():
	# Relative to Camera3D (which is at ~1.4 height)
	transform.origin = Vector3(0, 0, -0.55)
	rotation = Vector3.ZERO

func set_transparency(value: float):
	if has_node("MeshInstance3D"):
		$MeshInstance3D.transparency = value
