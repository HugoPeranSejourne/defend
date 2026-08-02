extends EnemyUnit
class_name EnemyShield

@export var shield_mesh: MeshInstance3D

func _ready() -> void:
	super._ready()
	max_health = 180.0
	health = 180.0
	base_move_speed = 5.0
	attack_range = 2.0
	attack_damage = 22.0
	is_melee = true

func take_damage(amount: float, bullet_dir: Vector3 = Vector3.ZERO, body_part: String = "") -> void:
	if _is_dying:
		return
		
	var is_frontal := false
	if bullet_dir != Vector3.ZERO:
		var face_dir := -transform.basis.z
		var dot := face_dir.dot(-bullet_dir.normalized())
		if dot > 0.3:
			is_frontal = true

	var final_amt := amount * 0.25 if is_frontal else amount
	super.take_damage(final_amt, bullet_dir, body_part)
