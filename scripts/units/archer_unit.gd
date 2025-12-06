extends BaseUnit
class_name ArcherUnit

var projectile_scene: PackedScene

func _ready() -> void:
	unit_type = "archer"
	targeting_mode = TargetingMode.CLOSEST
	projectile_scene = preload("res://scenes/projectile.tscn")
	super._ready()

var retarget_timer: float = 0.0
const RETARGET_INTERVAL: float = 0.5  # Check for new targets every 0.5 seconds

func _physics_process(delta: float) -> void:
	retarget_timer -= delta
	if retarget_timer <= 0:
		retarget_timer = RETARGET_INTERVAL
		_check_for_targets()
	super._physics_process(delta)

func _check_for_targets() -> void:
	# If no target or target out of range, find a new one
	if not is_instance_valid(target):
		_find_target()
	elif global_position.distance_to(target.global_position) > attack_range:
		# Current target out of range, look for closer one
		_find_target()

func _move_towards_target(delta: float) -> void:
	if not is_instance_valid(target):
		state = UnitState.IDLE
		target = null
		return

	var dist = global_position.distance_to(target.global_position)

	# If in attack range, try to attack
	if dist <= attack_range:
		state = UnitState.ATTACKING
		return

	# Move towards target (slowly)
	var direction = (target.global_position - global_position).normalized()
	direction.y = 0

	# Apply friendly avoidance steering
	var avoidance = _get_friendly_avoidance()
	direction = (direction + avoidance).normalized()

	velocity = direction * speed
	move_and_slide()

	# Face target
	if direction.length() > 0.01:
		look_at(global_position + direction, Vector3.UP)

func _perform_attack() -> void:
	if not is_instance_valid(target):
		return

	var spawn_pos = global_position + Vector3.UP * 1.5

	# Predict where the target will be when the projectile arrives
	var predicted_pos = _predict_target_position(spawn_pos)

	# Check if a friendly unit is in the way of the shot
	if _would_hit_friendly(spawn_pos, predicted_pos):
		# Try to find an alternative target
		var alt_target = _find_clear_target(spawn_pos)
		if alt_target:
			target = alt_target
			predicted_pos = _predict_target_position(spawn_pos)
		else:
			# No valid target, don't shoot
			return

	var projectile = projectile_scene.instantiate() as Projectile
	projectile.team = team
	projectile.damage = damage
	projectile.shooter = self

	# Add random deviation for imperfect aim
	var aim_pos = _apply_aim_deviation(spawn_pos, predicted_pos)

	var projectiles_container = get_tree().root.get_node("Main/Projectiles")
	projectiles_container.add_child(projectile)
	projectile.global_position = spawn_pos
	projectile.launch_at_target(spawn_pos, aim_pos)

func _find_clear_target(spawn_pos: Vector3) -> BaseUnit:
	# Find an enemy we can shoot without hitting friendlies
	var enemy_group = "team_2" if team == 1 else "team_1"
	var enemies = get_tree().get_nodes_in_group(enemy_group)

	var best_target: BaseUnit = null
	var best_dist: float = INF

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy == target:
			# Already checked this one
			continue

		var dist = global_position.distance_to(enemy.global_position)
		if dist > attack_range:
			continue

		var enemy_predicted_pos = enemy.global_position + Vector3.UP * 0.5
		if enemy is CharacterBody3D and enemy.velocity.length() > 0.1:
			# Simple prediction for moving targets
			var flight_time = dist / GameConfig.projectile_speed
			enemy_predicted_pos += Vector3(enemy.velocity.x * flight_time, 0, enemy.velocity.z * flight_time)

		if not _would_hit_friendly(spawn_pos, enemy_predicted_pos):
			if dist < best_dist:
				best_dist = dist
				best_target = enemy

	return best_target

func _predict_target_position(spawn_pos: Vector3) -> Vector3:
	var target_pos = target.global_position + Vector3.UP * 0.5
	var target_velocity = target.velocity if target is CharacterBody3D else Vector3.ZERO

	# If target is stationary, just aim directly at them
	if target_velocity.length() < 0.1:
		return target_pos

	# Calculate flight time using proper ballistics
	var displacement = target_pos - spawn_pos
	var horizontal_dist = Vector2(displacement.x, displacement.z).length()
	var speed = GameConfig.projectile_speed
	var gravity = GameConfig.projectile_gravity

	# Solve for launch angle
	var speed_sq = speed * speed
	var discriminant = speed_sq * speed_sq - gravity * (gravity * horizontal_dist * horizontal_dist + 2.0 * displacement.y * speed_sq)

	var flight_time: float
	if discriminant < 0:
		# Out of range, estimate
		flight_time = horizontal_dist / speed
	else:
		var sqrt_disc = sqrt(discriminant)
		var angle = atan((speed_sq - sqrt_disc) / (gravity * horizontal_dist))
		var v_horizontal = speed * cos(angle)
		flight_time = horizontal_dist / v_horizontal if v_horizontal > 0.1 else horizontal_dist / speed

	# Predict where target will be after flight_time
	var predicted_pos = target_pos + Vector3(
		target_velocity.x * flight_time,
		0,
		target_velocity.z * flight_time
	)

	return predicted_pos

func _would_hit_friendly(from_pos: Vector3, to_pos: Vector3) -> bool:
	# Check if any friendly unit is between archer and target
	var friendly_group = "team_%d" % team
	var friendlies = get_tree().get_nodes_in_group(friendly_group)

	var direction = (to_pos - from_pos).normalized()
	var distance_to_target = from_pos.distance_to(to_pos)

	for friendly in friendlies:
		if friendly == self:
			continue
		if not is_instance_valid(friendly):
			continue

		var friendly_pos = friendly.global_position + Vector3.UP * 0.5
		var to_friendly = friendly_pos - from_pos
		var distance_to_friendly = to_friendly.length()

		# Only check friendlies that are closer than the target
		if distance_to_friendly >= distance_to_target:
			continue

		# Project friendly position onto the shot direction
		var projection_length = to_friendly.dot(direction)

		# Skip if friendly is behind us
		if projection_length < 0:
			continue

		# Calculate perpendicular distance from shot line to friendly
		var closest_point = from_pos + direction * projection_length
		var perpendicular_dist = friendly_pos.distance_to(closest_point)

		# If friendly is within ~1.5 units of the shot line, don't shoot
		if perpendicular_dist < 1.5:
			return true

	return false

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
