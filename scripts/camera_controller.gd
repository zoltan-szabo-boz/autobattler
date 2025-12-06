extends Camera3D

# Movement settings
@export var move_speed: float = 20.0
@export var zoom_speed: float = 5.0
@export var rotation_speed: float = 2.0
@export var vertical_speed: float = 15.0

# Limits
@export var min_height: float = 5.0
@export var max_height: float = 80.0
@export var min_zoom: float = 10.0
@export var max_zoom: float = 100.0
@export var boundary_margin: float = 20.0  # How far past battlefield edge camera can go

# Internal state
var camera_distance: float = 40.0
var camera_angle: float = 0.0  # Rotation around Y axis
var camera_pitch: float = -60.0  # Angle looking down (degrees)
var pivot_point: Vector3 = Vector3.ZERO

func _ready() -> void:
	# Initialize from current transform
	pivot_point = Vector3.ZERO
	camera_distance = 40.0
	camera_angle = 0.0
	_update_camera_transform()

func _process(delta: float) -> void:
	var moved = false

	# WASD movement (relative to camera facing direction)
	var input_dir = Vector3.ZERO
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input_dir.z -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input_dir.z += 1
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1

	if input_dir.length() > 0:
		input_dir = input_dir.normalized()
		# Rotate input direction by camera angle
		var rotated_dir = Vector3(
			input_dir.x * cos(camera_angle) - input_dir.z * sin(camera_angle),
			0,
			input_dir.x * sin(camera_angle) + input_dir.z * cos(camera_angle)
		)
		pivot_point += rotated_dir * move_speed * delta
		moved = true

	# Q/E rotation
	if Input.is_key_pressed(KEY_Q):
		camera_angle += rotation_speed * delta
		moved = true
	if Input.is_key_pressed(KEY_E):
		camera_angle -= rotation_speed * delta
		moved = true

	# Z/C vertical movement
	if Input.is_key_pressed(KEY_Z):
		pivot_point.y -= vertical_speed * delta
		moved = true
	if Input.is_key_pressed(KEY_C):
		pivot_point.y += vertical_speed * delta
		moved = true

	if moved:
		_clamp_position()
		_update_camera_transform()

func _unhandled_input(event: InputEvent) -> void:
	# Mouse wheel zoom
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				camera_distance -= zoom_speed
				camera_distance = clamp(camera_distance, min_zoom, max_zoom)
				_update_camera_transform()
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				camera_distance += zoom_speed
				camera_distance = clamp(camera_distance, min_zoom, max_zoom)
				_update_camera_transform()

func _clamp_position() -> void:
	# Get battlefield bounds
	var half_size_x = GameConfig.battlefield_size.x / 2.0 + boundary_margin
	var half_size_y = GameConfig.battlefield_size.y / 2.0 + boundary_margin

	# Clamp horizontal position
	pivot_point.x = clamp(pivot_point.x, -half_size_x, half_size_x)
	pivot_point.z = clamp(pivot_point.z, -half_size_y, half_size_y)

	# Clamp vertical position
	pivot_point.y = clamp(pivot_point.y, 0, max_height - min_height)

func _update_camera_transform() -> void:
	# Calculate camera position based on pivot, distance, and angles
	var pitch_rad = deg_to_rad(camera_pitch)

	var offset = Vector3(
		sin(camera_angle) * cos(pitch_rad) * camera_distance,
		-sin(pitch_rad) * camera_distance,
		cos(camera_angle) * cos(pitch_rad) * camera_distance
	)

	var new_position = pivot_point + offset

	# Ensure camera doesn't go below minimum height
	new_position.y = max(new_position.y, min_height)

	global_position = new_position
	look_at(pivot_point, Vector3.UP)
