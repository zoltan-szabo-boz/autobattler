extends BaseUnit
class_name FlyerUnit

var altitude: float = 4.0
var is_landed: bool = false  # Track if we're on the ground attacking
const LANDING_HEIGHT: float = 0.5  # Height when landed (slightly off ground)
const ALTITUDE_LERP_SPEED: float = 8.0  # How fast to transition between flying/landed

func _ready() -> void:
	unit_type = "flyer"
	targeting_mode = TargetingMode.CLOSEST
	super._ready()

	# Load altitude from stats
	var stats = GameConfig.get_unit_stats(unit_type)
	altitude = stats.altitude

	# Add to flyers group for targeting
	add_to_group("flyers")
	add_to_group("team_%d_flyers" % team)

	# Set initial altitude
	global_position.y = altitude

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	# Smoothly transition altitude based on state
	var target_y: float
	if is_landed:
		target_y = LANDING_HEIGHT
	else:
		target_y = altitude

	global_position.y = lerpf(global_position.y, target_y, ALTITUDE_LERP_SPEED * delta)

func is_flying() -> bool:
	# Consider flying if above a threshold (used for targeting by melee units)
	return global_position.y > 1.5

func _find_target() -> void:
	var enemy_group = "team_2" if team == 1 else "team_1"
	var enemies = get_tree().get_nodes_in_group(enemy_group)

	if enemies.is_empty():
		target = null
		return

	# Air priority targeting:
	# 1. First, target enemy flyers (air superiority)
	# 2. Then, target enemy archers (they can shoot us)
	# 3. Finally, other ground units

	var enemy_flyers: Array[BaseUnit] = []
	var enemy_archers: Array[BaseUnit] = []
	var other_enemies: Array[BaseUnit] = []

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.unit_type == "flyer":
			enemy_flyers.append(enemy)
		elif enemy.unit_type == "archer":
			enemy_archers.append(enemy)
		else:
			other_enemies.append(enemy)

	# Priority 1: Enemy flyers
	if not enemy_flyers.is_empty():
		target = _get_closest_enemy(enemy_flyers)
		return

	# Priority 2: Enemy archers
	if not enemy_archers.is_empty():
		target = _get_closest_enemy(enemy_archers)
		return

	# Priority 3: Any other enemy
	if not other_enemies.is_empty():
		target = _get_closest_enemy(other_enemies)
		return

	target = null

func _move_towards_target(delta: float) -> void:
	if not is_instance_valid(target):
		state = UnitState.IDLE
		target = null
		return

	# When moving, fly up to altitude (safe from melee)
	is_landed = false

	# Calculate horizontal distance to target
	var target_pos = target.global_position
	var horizontal_dist = Vector2(global_position.x - target_pos.x, global_position.z - target_pos.z).length()

	if horizontal_dist <= attack_range:
		state = UnitState.ATTACKING
		return

	# Move horizontally at flying altitude
	var direction = Vector3(target_pos.x - global_position.x, 0, target_pos.z - global_position.z).normalized()

	# Apply friendly avoidance steering (3D for flyers)
	var avoidance = _get_friendly_avoidance_3d()
	direction = (direction + avoidance).normalized()

	velocity = direction * speed
	move_and_slide()

	# Face target (in horizontal plane)
	if direction.length() > 0.01:
		look_at(global_position + direction, Vector3.UP)

func _get_friendly_avoidance_3d() -> Vector3:
	var avoidance := Vector3.ZERO
	var avoidance_radius: float = 2.5  # Slightly larger for air units
	var avoidance_strength: float = 1.5

	# Only avoid other flyers
	var friendly_flyers_group = "team_%d_flyers" % team
	var friendly_flyers = get_tree().get_nodes_in_group(friendly_flyers_group)

	for friendly in friendly_flyers:
		if friendly == self or not is_instance_valid(friendly):
			continue

		var to_friendly = friendly.global_position - global_position
		var dist = to_friendly.length()

		if dist < avoidance_radius and dist > 0.01:
			var push_strength = (avoidance_radius - dist) / avoidance_radius
			avoidance -= to_friendly.normalized() * push_strength * avoidance_strength

	return avoidance

func _attack_target() -> void:
	velocity = Vector3.ZERO

	if not is_instance_valid(target):
		target = null
		is_landed = false  # Fly back up when searching for new target
		_find_target()
		if target:
			state = UnitState.MOVING
		else:
			state = UnitState.IDLE
		return

	# Land when attacking ground targets, stay airborne vs flyers
	is_landed = target.unit_type != "flyer"

	# Check horizontal distance
	var target_pos = target.global_position
	var horizontal_dist = Vector2(global_position.x - target_pos.x, global_position.z - target_pos.z).length()

	if horizontal_dist > attack_range * 1.5:
		state = UnitState.MOVING
		return

	# Face target
	var direction = Vector3(target_pos.x - global_position.x, 0, target_pos.z - global_position.z)
	if direction.length() > 0.01:
		look_at(global_position + direction, Vector3.UP)

	if attack_timer <= 0:
		_perform_attack()
		attack_timer = attack_delay

func _check_collision_engagement() -> void:
	# Flyers don't engage via collision like ground units
	# They swoop in and attack from range
	pass
