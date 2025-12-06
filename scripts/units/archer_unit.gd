extends BaseUnit
class_name ArcherUnit

var projectile_scene: PackedScene

func _ready() -> void:
	unit_type = "archer"
	targeting_mode = TargetingMode.CLOSEST
	projectile_scene = preload("res://scenes/projectile.tscn")
	super._ready()

func _move_towards_target(_delta: float) -> void:
	# Archers don't move, go straight to attacking if we have a target
	if is_instance_valid(target):
		state = UnitState.ATTACKING
	else:
		state = UnitState.IDLE

func _perform_attack() -> void:
	if not is_instance_valid(target):
		return

	var projectile = projectile_scene.instantiate() as Projectile
	projectile.team = team
	projectile.damage = damage
	projectile.shooter = self

	var spawn_pos = global_position + Vector3.UP * 1.5

	# Predict where the target will be when the projectile arrives
	var predicted_pos = _predict_target_position(spawn_pos)

	# Add random deviation for imperfect aim
	var aim_pos = _apply_aim_deviation(spawn_pos, predicted_pos)

	var projectiles_container = get_tree().root.get_node("Main/Projectiles")
	projectiles_container.add_child(projectile)
	projectile.global_position = spawn_pos
	projectile.launch_at_target(spawn_pos, aim_pos)

func _predict_target_position(spawn_pos: Vector3) -> Vector3:
	var target_pos = target.global_position + Vector3.UP * 0.5
	var target_velocity = target.velocity if target is CharacterBody3D else Vector3.ZERO

	# Estimate time for projectile to reach target (simplified - assumes straight line)
	var distance = spawn_pos.distance_to(target_pos)
	var flight_time = distance / GameConfig.projectile_speed

	# Predict where target will be after flight_time
	# Only predict horizontal movement (x, z), keep y the same
	var predicted_pos = target_pos + Vector3(
		target_velocity.x * flight_time,
		0,
		target_velocity.z * flight_time
	)

	return predicted_pos

func _apply_aim_deviation(from_pos: Vector3, to_pos: Vector3) -> Vector3:
	var deviation_degrees = GameConfig.archer_aim_deviation

	if deviation_degrees <= 0:
		return to_pos

	# Get direction to target
	var direction = (to_pos - from_pos).normalized()
	var distance = from_pos.distance_to(to_pos)

	# Random deviation angle (using normal-ish distribution for more shots near center)
	var random_angle = randf_range(-deviation_degrees, deviation_degrees)
	# Add second random for more center-weighted distribution
	random_angle = (random_angle + randf_range(-deviation_degrees, deviation_degrees)) / 2.0
	var angle_rad = deg_to_rad(random_angle)

	# Rotate direction around Y axis (horizontal deviation)
	var rotated_direction = Vector3(
		direction.x * cos(angle_rad) - direction.z * sin(angle_rad),
		direction.y,
		direction.x * sin(angle_rad) + direction.z * cos(angle_rad)
	)

	# Also add small vertical deviation
	var vertical_deviation = randf_range(-deviation_degrees * 0.3, deviation_degrees * 0.3)
	rotated_direction.y += deg_to_rad(vertical_deviation)
	rotated_direction = rotated_direction.normalized()

	return from_pos + rotated_direction * distance
