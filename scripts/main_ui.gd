extends CanvasLayer

@onready var spawn_button_1: Button = $HBoxContainer/LeftPanel/SpawnButton1
@onready var spawn_button_2: Button = $HBoxContainer/RightPanel/SpawnButton2
@onready var score_label_1: Label = $HBoxContainer/LeftPanel/Score1Label
@onready var score_label_2: Label = $HBoxContainer/RightPanel/Score2Label

func _ready() -> void:
	spawn_button_1.pressed.connect(_on_spawn_button_1_pressed)
	spawn_button_2.pressed.connect(_on_spawn_button_2_pressed)
	GameManager.score_changed.connect(_on_score_changed)

	# Spawn initial units for both teams
	_spawn_initial_units()

func _spawn_initial_units() -> void:
	for i in range(5):
		GameManager.spawn_random_unit(1)
		GameManager.spawn_random_unit(2)

func _unhandled_input(event: InputEvent) -> void:
	# Keyboard shortcuts for quick testing (1 and 2 keys)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			GameManager.spawn_random_unit(1)
		elif event.keycode == KEY_2:
			GameManager.spawn_random_unit(2)

func _on_spawn_button_1_pressed() -> void:
	GameManager.spawn_random_unit(1)

func _on_spawn_button_2_pressed() -> void:
	GameManager.spawn_random_unit(2)

func _on_score_changed(team: int, kills: int) -> void:
	if team == 1:
		score_label_1.text = "Kills: %d" % kills
	else:
		score_label_2.text = "Kills: %d" % kills
