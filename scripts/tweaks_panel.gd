extends PanelContainer

var is_collapsed: bool = true

@onready var toggle_button: Button = $VBoxContainer/ToggleButton
@onready var content: VBoxContainer = $VBoxContainer/ScrollContainer/Content

# Store slider references for easy access
var sliders: Dictionary = {}

func _ready() -> void:
	toggle_button.pressed.connect(_on_toggle_pressed)
	_build_ui()
	_update_collapsed_state()

func _on_toggle_pressed() -> void:
	is_collapsed = !is_collapsed
	_update_collapsed_state()

func _update_collapsed_state() -> void:
	$VBoxContainer/ScrollContainer.visible = !is_collapsed
	toggle_button.text = "Tweaks [+]" if is_collapsed else "Tweaks [-]"

func _build_ui() -> void:
	# Clear existing content
	for child in content.get_children():
		child.queue_free()

	# Build sections
	_add_section("Battlefield", [
		{"name": "battlefield_size_x", "label": "Size X", "min": 20, "max": 100, "step": 5, "value": GameConfig.battlefield_size.x},
		{"name": "battlefield_size_y", "label": "Size Y", "min": 20, "max": 100, "step": 5, "value": GameConfig.battlefield_size.y},
	])

	_add_section("Footman", [
		{"name": "footman_hp", "label": "HP", "min": 10, "max": 500, "step": 10, "value": GameConfig.footman_hp},
		{"name": "footman_speed", "label": "Speed", "min": 0.5, "max": 15, "step": 0.5, "value": GameConfig.footman_speed},
		{"name": "footman_damage", "label": "Damage", "min": 1, "max": 100, "step": 1, "value": GameConfig.footman_damage},
		{"name": "footman_attack_delay", "label": "Attack Delay", "min": 0.1, "max": 5, "step": 0.1, "value": GameConfig.footman_attack_delay},
		{"name": "footman_attack_range", "label": "Attack Range", "min": 0.5, "max": 5, "step": 0.1, "value": GameConfig.footman_attack_range},
	])

	_add_section("Cavalry", [
		{"name": "cavalry_hp", "label": "HP", "min": 10, "max": 500, "step": 10, "value": GameConfig.cavalry_hp},
		{"name": "cavalry_speed", "label": "Speed", "min": 0.5, "max": 20, "step": 0.5, "value": GameConfig.cavalry_speed},
		{"name": "cavalry_damage", "label": "Damage", "min": 1, "max": 100, "step": 1, "value": GameConfig.cavalry_damage},
		{"name": "cavalry_attack_delay", "label": "Attack Delay", "min": 0.1, "max": 5, "step": 0.1, "value": GameConfig.cavalry_attack_delay},
		{"name": "cavalry_attack_range", "label": "Attack Range", "min": 0.5, "max": 5, "step": 0.1, "value": GameConfig.cavalry_attack_range},
	])

	_add_section("Archer", [
		{"name": "archer_hp", "label": "HP", "min": 10, "max": 500, "step": 10, "value": GameConfig.archer_hp},
		{"name": "archer_speed", "label": "Speed", "min": 0, "max": 10, "step": 0.5, "value": GameConfig.archer_speed},
		{"name": "archer_damage", "label": "Damage", "min": 1, "max": 100, "step": 1, "value": GameConfig.archer_damage},
		{"name": "archer_attack_delay", "label": "Attack Delay", "min": 0.1, "max": 5, "step": 0.1, "value": GameConfig.archer_attack_delay},
		{"name": "archer_aim_deviation", "label": "Aim Deviation", "min": 0, "max": 45, "step": 0.5, "value": GameConfig.archer_aim_deviation},
	])

	_add_section("Projectile", [
		{"name": "projectile_speed", "label": "Speed", "min": 5, "max": 60, "step": 1, "value": GameConfig.projectile_speed},
		{"name": "projectile_gravity", "label": "Gravity", "min": 1, "max": 30, "step": 0.5, "value": GameConfig.projectile_gravity},
		{"name": "hit_stagger_duration", "label": "Hit Stagger", "min": 0, "max": 2, "step": 0.1, "value": GameConfig.hit_stagger_duration},
	])

func _add_section(title: String, params: Array) -> void:
	# Section header
	var header = Label.new()
	header.text = "── " + title + " ──"
	header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))
	content.add_child(header)

	# Parameters
	for param in params:
		_add_slider(param)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 10
	content.add_child(spacer)

func _add_slider(param: Dictionary) -> void:
	var container = HBoxContainer.new()

	# Label
	var label = Label.new()
	label.text = param.label
	label.custom_minimum_size.x = 100
	container.add_child(label)

	# Slider
	var slider = HSlider.new()
	slider.min_value = param.min
	slider.max_value = param.max
	slider.step = param.step
	slider.value = param.value
	slider.custom_minimum_size.x = 120
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(slider)

	# Value label
	var value_label = Label.new()
	value_label.text = str(param.value)
	value_label.custom_minimum_size.x = 50
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	container.add_child(value_label)

	# Store reference
	sliders[param.name] = {"slider": slider, "value_label": value_label}

	# Connect signal
	slider.value_changed.connect(_on_slider_changed.bind(param.name, value_label))

	content.add_child(container)

func _on_slider_changed(value: float, param_name: String, value_label: Label) -> void:
	# Update label
	if value == int(value):
		value_label.text = str(int(value))
	else:
		value_label.text = "%.1f" % value

	# Update GameConfig
	match param_name:
		"battlefield_size_x":
			GameConfig.battlefield_size.x = value
			_update_battlefield_size()
		"battlefield_size_y":
			GameConfig.battlefield_size.y = value
			_update_battlefield_size()
		"footman_hp":
			_update_unit_hp("footman", GameConfig.footman_hp, value)
			GameConfig.footman_hp = value
		"footman_speed":
			GameConfig.footman_speed = value
			_update_existing_units("footman", "speed", value)
		"footman_damage":
			GameConfig.footman_damage = value
			_update_existing_units("footman", "damage", value)
		"footman_attack_delay":
			GameConfig.footman_attack_delay = value
			_update_existing_units("footman", "attack_delay", value)
		"footman_attack_range":
			GameConfig.footman_attack_range = value
			_update_existing_units("footman", "attack_range", value)
		"cavalry_hp":
			_update_unit_hp("cavalry", GameConfig.cavalry_hp, value)
			GameConfig.cavalry_hp = value
		"cavalry_speed":
			GameConfig.cavalry_speed = value
			_update_existing_units("cavalry", "speed", value)
		"cavalry_damage":
			GameConfig.cavalry_damage = value
			_update_existing_units("cavalry", "damage", value)
		"cavalry_attack_delay":
			GameConfig.cavalry_attack_delay = value
			_update_existing_units("cavalry", "attack_delay", value)
		"cavalry_attack_range":
			GameConfig.cavalry_attack_range = value
			_update_existing_units("cavalry", "attack_range", value)
		"archer_hp":
			_update_unit_hp("archer", GameConfig.archer_hp, value)
			GameConfig.archer_hp = value
		"archer_damage":
			GameConfig.archer_damage = value
			_update_existing_units("archer", "damage", value)
		"archer_speed":
			GameConfig.archer_speed = value
			_update_existing_units("archer", "speed", value)
		"archer_attack_delay":
			GameConfig.archer_attack_delay = value
			_update_existing_units("archer", "attack_delay", value)
		"archer_aim_deviation":
			GameConfig.archer_aim_deviation = value
		"projectile_speed":
			GameConfig.projectile_speed = value
			_update_archer_range()
		"projectile_gravity":
			GameConfig.projectile_gravity = value
			_update_archer_range()
		"hit_stagger_duration":
			GameConfig.hit_stagger_duration = value

func _update_unit_hp(unit_type: String, old_max: float, new_max: float) -> void:
	# Scale existing units' HP proportionally
	var units = get_tree().get_nodes_in_group("units")
	for unit in units:
		if unit is BaseUnit and unit.unit_type == unit_type:
			# Calculate HP ratio and apply to new max
			var hp_ratio = unit.current_hp / unit.max_hp
			unit.max_hp = new_max
			unit.current_hp = new_max * hp_ratio

func _update_existing_units(unit_type: String, stat: String, value: float) -> void:
	var units = get_tree().get_nodes_in_group("units")
	for unit in units:
		if unit is BaseUnit and unit.unit_type == unit_type:
			match stat:
				"speed":
					unit.speed = value
				"damage":
					unit.damage = value
				"attack_delay":
					unit.attack_delay = value
				"attack_range":
					unit.attack_range = value

func _update_archer_range() -> void:
	# Update all existing archers' attack range based on new projectile physics
	var new_range = GameConfig.get_projectile_max_range()
	var units = get_tree().get_nodes_in_group("units")
	for unit in units:
		if unit is BaseUnit and unit.unit_type == "archer":
			unit.attack_range = new_range

func _update_battlefield_size() -> void:
	var size_x = GameConfig.battlefield_size.x
	var size_y = GameConfig.battlefield_size.y

	var ground = get_tree().root.get_node_or_null("Main/Battlefield/Ground")
	if not ground:
		return

	# Update mesh
	var mesh_instance = ground.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_instance and mesh_instance.mesh is BoxMesh:
		var box_mesh = mesh_instance.mesh as BoxMesh
		box_mesh.size = Vector3(size_x, 0.2, size_y)

	# Update collision shape
	var collision_shape = ground.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape and collision_shape.shape is BoxShape3D:
		var box_shape = collision_shape.shape as BoxShape3D
		box_shape.size = Vector3(size_x, 0.2, size_y)
