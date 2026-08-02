extends Node
class_name DebrisSystem

static func spawn_rubble_explosion(parent_node: Node, pos: Vector3, count: int = 12) -> void:
	if not is_instance_valid(parent_node):
		return

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.42, 0.38, 1.0)
	mat.roughness = 0.8

	for i in range(count):
		var mesh_inst := MeshInstance3D.new()
		var box := BoxMesh.new()
		var sz := randf_range(0.25, 0.6)
		box.size = Vector3(sz, sz * randf_range(0.8, 1.4), sz)
		box.material = mat
		mesh_inst.mesh = box
		
		parent_node.add_child(mesh_inst)
		mesh_inst.global_position = pos + Vector3(randf_range(-0.5, 0.5), randf_range(0.2, 1.2), randf_range(-0.5, 0.5))
		
		var velocity := Vector3(
			randf_range(-6.0, 6.0),
			randf_range(4.0, 10.0),
			randf_range(-6.0, 6.0)
		)
		var rot_velocity := Vector3(
			randf_range(-8.0, 8.0),
			randf_range(-8.0, 8.0),
			randf_range(-8.0, 8.0)
		)
		
		_animate_debris(mesh_inst, velocity, rot_velocity)

static func _animate_debris(mesh_inst: MeshInstance3D, vel: Vector3, rot_vel: Vector3) -> void:
	var tween := mesh_inst.create_tween()
	var dur := 1.8
	var current_vel := vel
	
	# Interpolation physique manuelle fluide
	tween.tween_method(func(t: float):
		if is_instance_valid(mesh_inst):
			current_vel.y -= 18.0 * 0.016
			mesh_inst.global_position += current_vel * 0.016
			mesh_inst.rotation += rot_vel * 0.016
			if mesh_inst.global_position.y <= 0.1:
				mesh_inst.global_position.y = 0.1
				current_vel.y = -current_vel.y * 0.3
				current_vel.x *= 0.7
				current_vel.z *= 0.7
	, 0.0, 1.0, dur)

	tween.finished.connect(func():
		if is_instance_valid(mesh_inst):
			mesh_inst.queue_free()
	)
