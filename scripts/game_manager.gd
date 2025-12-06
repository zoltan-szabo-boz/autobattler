extends Node

signal score_changed(team: int, kills: int)

var team1_kills: int = 0
var team2_kills: int = 0

var unit_scenes: Dictionary = {}

func _ready() -> void:
	# Preload unit scenes
	unit_scenes = {
		"footman": preload("res://scenes/units/footman.tscn"),
		"cavalry": preload("res://scenes/units/cavalry.tscn"),
		"archer": preload("res://scenes/units/archer.tscn")
	}

func spawn_random_unit(team: int) -> void:
	var unit_types = ["footman", "cavalry", "archer"]
	var random_type = unit_types[randi() % unit_types.size()]
	spawn_unit(random_type, team)

func spawn_unit(unit_type: String, team: int) -> void:
	if not unit_scenes.has(unit_type):
		push_error("Unknown unit type: " + unit_type)
		return

	var unit = unit_scenes[unit_type].instantiate() as BaseUnit
	unit.team = team

	# Add to units container first (before setting global_position)
	var units_container = get_tree().root.get_node_or_null("Main/Units")
	if units_container:
		units_container.add_child(unit)
		# Set position after adding to tree
		unit.global_position = _get_spawn_position(team)
	else:
		push_error("Units container not found!")
		unit.queue_free()

func _get_spawn_position(team: int) -> Vector3:
	var half_size = GameConfig.battlefield_size / 2.0
	var margin = GameConfig.spawn_margin

	var x: float
	var z: float

	if team == 1:
		# Team 1 spawns on left edge (negative X)
		x = -half_size.x + margin
		z = randf_range(-half_size.y + margin, half_size.y - margin)
	else:
		# Team 2 spawns on right edge (positive X)
		x = half_size.x - margin
		z = randf_range(-half_size.y + margin, half_size.y - margin)

	return Vector3(x, 0, z)

func add_kill(team: int) -> void:
	if team == 1:
		team1_kills += 1
		score_changed.emit(1, team1_kills)
	else:
		team2_kills += 1
		score_changed.emit(2, team2_kills)

func get_kills(team: int) -> int:
	return team1_kills if team == 1 else team2_kills

func reset_scores() -> void:
	team1_kills = 0
	team2_kills = 0
	score_changed.emit(1, 0)
	score_changed.emit(2, 0)
