extends CharacterBody3D
class_name BaseUnit

signal unit_died(unit: BaseUnit)

enum UnitState { IDLE, MOVING, ATTACKING }
enum TargetingMode { CLOSEST, FARTHEST }

@export var unit_type: String = "footman"
@export var team: int = 1
@export var targeting_mode: TargetingMode = TargetingMode.CLOSEST

var current_hp: float
var max_hp: float
var speed: float
var damage: float
var attack_delay: float
var attack_range: float

var state: UnitState = UnitState.IDLE
var target: BaseUnit = null
var attack_timer: float = 0.0
var mesh_instance: MeshInstance3D

func _ready() -> void:
	_load_stats()
	_setup_visuals()
	_setup_collision()
	add_to_group("units")
	add_to_group("team_%d" % team)

func _load_stats() -> void:
	var stats = GameConfig.get_unit_stats(unit_type)
	max_hp = stats.hp
	current_hp = max_hp
	speed = stats.speed
	damage = stats.damage
	attack_delay = stats.attack_delay
	attack_range = stats.attack_range

func _setup_visuals() -> void:
	var stats = GameConfig.get_unit_stats(unit_type)
	var size: Vector3 = stats.size

	mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.position.y = size.y / 2.0

	var material = StandardMaterial3D.new()
	material.albedo_color = GameConfig.get_unit_color(team, unit_type)
	mesh_instance.material_override = material

	add_child(mesh_instance)

func _setup_collision() -> void:
	var stats = GameConfig.get_unit_stats(unit_type)
	var size: Vector3 = stats.size

	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	collision_shape.shape = box_shape
	collision_shape.position.y = size.y / 2.0
	add_child(collision_shape)

	# Set collision layer based on team
	if team == 1:
		collision_layer = 2  # Layer 2 = team1
		collision_mask = 4 | 8  # Collide with team2 and projectiles
	else:
		collision_layer = 4  # Layer 3 = team2
		collision_mask = 2 | 8  # Collide with team1 and projectiles

func _physics_process(delta: float) -> void:
	attack_timer -= delta

	# Check for nearby enemies we're colliding with (melee engagement)
	_check_collision_engagement()

	match state:
		UnitState.IDLE:
			_find_target()
			if target:
				state = UnitState.MOVING
		UnitState.MOVING:
			_move_towards_target(delta)
		UnitState.ATTACKING:
			_attack_target()

func _check_collision_engagement() -> void:
	# Skip for archers - they don't engage in melee
	if unit_type == "archer":
		return

	# Check if current target is still valid and in range
	if is_instance_valid(target) and global_position.distance_to(target.global_position) <= attack_range:
		return  # Already engaged with valid target

	# Look for enemies within melee range
	var enemy_group = "team_2" if team == 1 else "team_1"
	var enemies = get_tree().get_nodes_in_group(enemy_group)

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist <= attack_range * 1.5:  # Slightly larger than attack range for collision detection
			# Switch target to this nearby enemy
			target = enemy
			state = UnitState.ATTACKING
			return

func _find_target() -> void:
	var enemy_group = "team_2" if team == 1 else "team_1"
	var enemies = get_tree().get_nodes_in_group(enemy_group)

	if enemies.is_empty():
		target = null
		return

	match targeting_mode:
		TargetingMode.CLOSEST:
			target = _get_closest_enemy(enemies)
		TargetingMode.FARTHEST:
			target = _get_farthest_enemy(enemies)

func _get_closest_enemy(enemies: Array) -> BaseUnit:
	var closest: BaseUnit = null
	var closest_dist: float = INF

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = enemy

	return closest

func _get_farthest_enemy(enemies: Array) -> BaseUnit:
	var farthest: BaseUnit = null
	var farthest_dist: float = -INF

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist > farthest_dist:
			farthest_dist = dist
			farthest = enemy

	return farthest

func _move_towards_target(delta: float) -> void:
	if not is_instance_valid(target):
		state = UnitState.IDLE
		target = null
		return

	var dist = global_position.distance_to(target.global_position)

	if dist <= attack_range:
		state = UnitState.ATTACKING
		return

	var direction = (target.global_position - global_position).normalized()
	direction.y = 0  # Keep movement on ground plane

	velocity = direction * speed
	move_and_slide()

	# Check if we collided with an enemy - if so, start attacking them
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is BaseUnit and collider.team != team:
			target = collider
			state = UnitState.ATTACKING
			return

	# Face target
	if direction.length() > 0.01:
		look_at(global_position + direction, Vector3.UP)

func _attack_target() -> void:
	if not is_instance_valid(target):
		# Target died, find a new one immediately
		target = null
		_find_target()
		if target:
			state = UnitState.MOVING
		else:
			state = UnitState.IDLE
		return

	var dist = global_position.distance_to(target.global_position)

	# For melee units, use a more generous range check
	# This accounts for collision boxes stopping units before centers are close
	var effective_range = attack_range * 1.5 if unit_type != "archer" else attack_range * 1.2

	if dist > effective_range:
		state = UnitState.MOVING
		return

	# Face target while attacking
	var direction = (target.global_position - global_position).normalized()
	direction.y = 0
	if direction.length() > 0.01:
		look_at(global_position + direction, Vector3.UP)

	if attack_timer <= 0:
		_perform_attack()
		attack_timer = attack_delay

func _perform_attack() -> void:
	# Override in subclasses for different attack behaviors
	if is_instance_valid(target):
		target.take_damage(damage, self)

func take_damage(amount: float, attacker: BaseUnit) -> void:
	current_hp -= amount

	# Store attacker's team now in case they die during the await
	var attacker_team: int = attacker.team if is_instance_valid(attacker) else -1

	# Visual feedback - flash white briefly
	if mesh_instance and mesh_instance.material_override:
		var original_color = GameConfig.get_unit_color(team, unit_type)
		mesh_instance.material_override.albedo_color = Color.WHITE
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(self) and mesh_instance and mesh_instance.material_override:
			mesh_instance.material_override.albedo_color = original_color

	if current_hp <= 0:
		die(attacker_team)

func die(killer_team: int) -> void:
	unit_died.emit(self)
	if killer_team > 0:
		GameManager.add_kill(killer_team)
	queue_free()
