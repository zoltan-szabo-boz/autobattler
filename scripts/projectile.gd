extends RigidBody3D
class_name Projectile

var team: int = 1
var damage: float = 20.0
var shooter: BaseUnit = null
var has_hit: bool = false
var launched: bool = false
var launch_velocity: Vector3 = Vector3.ZERO

var mesh_instance: MeshInstance3D

func _ready() -> void:
	# Disable physics initially until we launch
	freeze = true

	_setup_visuals()
	_setup_collision()

	body_entered.connect(_on_body_entered)

	# Enable contact monitoring
	contact_monitor = true
	max_contacts_reported = 4

func _setup_visuals() -> void:
	mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = GameConfig.projectile_size
	mesh_instance.mesh = box_mesh

	var material = StandardMaterial3D.new()
	material.albedo_color = GameConfig.get_unit_color(team, "projectile")
	mesh_instance.material_override = material

	add_child(mesh_instance)

func _setup_collision() -> void:
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = GameConfig.projectile_size
	collision_shape.shape = box_shape
	add_child(collision_shape)

	# Projectiles are on layer 4
	collision_layer = 8  # Layer 4 = projectiles
	# Collide with both teams and ground (friendly fire possible)
	collision_mask = 2 | 4 | 1  # team1 + team2 + ground

func launch_at_target(from: Vector3, to: Vector3) -> void:
	var gravity = GameConfig.projectile_gravity
	var speed = GameConfig.projectile_speed

	var displacement = to - from
	var horizontal_dist = Vector2(displacement.x, displacement.z).length()
	var vertical_dist = displacement.y

	# Prevent division by zero
	if horizontal_dist < 0.1:
		horizontal_dist = 0.1

	var horizontal_dir = Vector2(displacement.x, displacement.z).normalized()

	# Solve ballistic trajectory equation to find launch angle
	# Using the formula for projectile motion to hit a target at (horizontal_dist, vertical_dist)
	var speed_sq = speed * speed
	var g = gravity
	var x = horizontal_dist
	var y = vertical_dist

	# Discriminant for the quadratic formula
	var discriminant = speed_sq * speed_sq - g * (g * x * x + 2.0 * y * speed_sq)

	var angle: float
	if discriminant < 0:
		# Target is out of range, use 45 degree angle (max range)
		angle = PI / 4.0
	else:
		# Two solutions exist - use the lower angle (flatter trajectory) for accuracy
		var sqrt_disc = sqrt(discriminant)
		angle = atan((speed_sq - sqrt_disc) / (g * x))

	# Calculate velocity components
	var v_horizontal = speed * cos(angle)
	var v_vertical = speed * sin(angle)

	launch_velocity = Vector3(
		horizontal_dir.x * v_horizontal,
		v_vertical,
		horizontal_dir.y * v_horizontal
	)

	# Set gravity scale
	gravity_scale = gravity / 9.8

	# Unfreeze and apply velocity after a short delay to avoid spawn collisions
	await get_tree().create_timer(0.05).timeout
	if is_instance_valid(self) and not has_hit:
		freeze = false
		linear_velocity = launch_velocity
		launched = true

func _physics_process(_delta: float) -> void:
	if not launched or has_hit:
		return

	# Rotate to face velocity direction
	if linear_velocity.length() > 0.1:
		look_at(global_position + linear_velocity.normalized(), Vector3.UP)

	# Despawn if fallen below ground
	if global_position.y < -5:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if has_hit or not launched:
		return

	# Ignore the shooter
	if body == shooter:
		return

	has_hit = true

	# Check what we hit
	var hit_unit = body is BaseUnit

	if hit_unit:
		var unit = body as BaseUnit
		# Pass shooter only if still valid, otherwise null
		var valid_shooter = shooter if is_instance_valid(shooter) else null
		unit.take_damage(damage, valid_shooter)
		unit.apply_hit_stagger()
		_attach_to_unit(unit)
	else:
		_start_ground_despawn()

func _attach_to_unit(unit: BaseUnit) -> void:
	freeze = true
	# Remove from collision immediately
	collision_layer = 0
	collision_mask = 0

	# Calculate offset from unit's position (in unit's local space)
	var offset = global_position - unit.global_position
	var unit_rotation = unit.global_transform.basis

	# Store the local offset relative to unit's rotation
	var local_offset = unit_rotation.inverse() * offset
	var local_rotation = global_transform.basis

	# Reparent to unit - must be deferred to avoid physics callback issues
	call_deferred("_deferred_reparent", unit, local_offset, unit_rotation.inverse() * local_rotation)

func _deferred_reparent(unit: BaseUnit, local_offset: Vector3, local_basis: Basis) -> void:
	if not is_instance_valid(unit):
		queue_free()
		return

	get_parent().remove_child(self)
	unit.add_child(self)

	# Set local position/rotation relative to unit
	transform.origin = local_offset
	transform.basis = local_basis

	# Connect to unit's death to clean up arrow
	unit.unit_died.connect(_on_attached_unit_died)

func _on_attached_unit_died(_unit: BaseUnit) -> void:
	queue_free()

func _start_ground_despawn() -> void:
	freeze = true
	# Remove from collision immediately so it doesn't block units
	collision_layer = 0
	collision_mask = 0

	# Fade out
	if mesh_instance and mesh_instance.material_override:
		var material = mesh_instance.material_override as StandardMaterial3D
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

		var tween = create_tween()
		tween.tween_property(material, "albedo_color:a", 0.0, GameConfig.projectile_despawn_delay)
		tween.tween_callback(queue_free)
