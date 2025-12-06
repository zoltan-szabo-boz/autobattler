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

	var time_to_target = horizontal_dist / speed
	var vy = (vertical_dist + 0.5 * gravity * time_to_target * time_to_target) / time_to_target

	var horizontal_dir = Vector2(displacement.x, displacement.z).normalized()

	launch_velocity = Vector3(
		horizontal_dir.x * speed,
		vy,
		horizontal_dir.y * speed
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

	# Damage any unit hit (friendly fire enabled)
	if body is BaseUnit:
		var unit = body as BaseUnit
		# Pass shooter only if still valid, otherwise null
		var valid_shooter = shooter if is_instance_valid(shooter) else null
		unit.take_damage(damage, valid_shooter)

	_start_despawn()

func _start_despawn() -> void:
	freeze = true

	if mesh_instance and mesh_instance.material_override:
		var material = mesh_instance.material_override as StandardMaterial3D
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

		var tween = create_tween()
		tween.tween_property(material, "albedo_color:a", 0.0, GameConfig.projectile_despawn_delay)
		tween.tween_callback(queue_free)
