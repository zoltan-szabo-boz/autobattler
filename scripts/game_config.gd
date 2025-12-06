extends Node
## Game Configuration - All tweakable values in one place

# =============================================================================
# BATTLEFIELD
# =============================================================================
@export var battlefield_size: Vector2 = Vector2(80.0, 40.0)
@export var spawn_margin: float = 2.0  # Distance from edge where units spawn

# =============================================================================
# UNIT STATS - FOOTMAN
# =============================================================================
@export var footman_hp: float = 100.0
@export var footman_speed: float = 3.0
@export var footman_damage: float = 15.0
@export var footman_attack_delay: float = 1.0  # Seconds between attacks
@export var footman_attack_range: float = 1.5  # Distance to start attacking

# =============================================================================
# UNIT STATS - CAVALRY
# =============================================================================
@export var cavalry_hp: float = 80.0
@export var cavalry_speed: float = 7.0
@export var cavalry_damage: float = 25.0
@export var cavalry_attack_delay: float = 1.2
@export var cavalry_attack_range: float = 1.8

# =============================================================================
# UNIT STATS - ARCHER
# =============================================================================
@export var archer_hp: float = 50.0
@export var archer_speed: float = 2.0
@export var archer_damage: float = 20.0
@export var archer_attack_delay: float = 2.0

# =============================================================================
# UNIT STATS - FLYER (Eagle)
# =============================================================================
@export var flyer_hp: float = 60.0
@export var flyer_speed: float = 5.0
@export var flyer_damage: float = 18.0
@export var flyer_attack_delay: float = 1.5
@export var flyer_attack_range: float = 2.0  # Air-to-air/dive attack range
@export var flyer_altitude: float = 4.0  # Height above ground

# =============================================================================
# PROJECTILE
# =============================================================================
@export var projectile_speed: float = 22.0
@export var projectile_gravity: float = 10.0
@export var projectile_despawn_delay: float = 2.5  # Seconds after hitting something
@export_range(0.0, 45.0, 0.5) var archer_aim_deviation: float = 8.0  # Max random angle deviation in degrees (~30% miss rate)
@export var hit_stagger_duration: float = 0.5  # Seconds unit is stunned after being hit by arrow

# =============================================================================
# VISUAL - UNIT SIZES
# =============================================================================
@export var footman_size: Vector3 = Vector3(0.8, 1.6, 0.8)
@export var cavalry_size: Vector3 = Vector3(1.2, 1.4, 2.0)
@export var archer_size: Vector3 = Vector3(0.7, 1.8, 0.7)
@export var flyer_size: Vector3 = Vector3(1.0, 0.4, 1.2)  # Wide wingspan, flat body
@export var projectile_size: Vector3 = Vector3(0.2, 0.2, 0.8)

# =============================================================================
# VISUAL - TEAM COLORS
# =============================================================================
# Team 1 - Blue variants
@export var team1_footman_color: Color = Color(0.3, 0.5, 0.9)  # Light blue
@export var team1_cavalry_color: Color = Color(0.2, 0.3, 0.8)  # Blue
@export var team1_archer_color: Color = Color(0.1, 0.2, 0.6)   # Dark blue
@export var team1_flyer_color: Color = Color(0.5, 0.7, 1.0)    # Sky blue (eagle)
@export var team1_projectile_color: Color = Color(0.4, 0.6, 1.0)

# Team 2 - Red variants
@export var team2_footman_color: Color = Color(0.9, 0.3, 0.3)  # Light red
@export var team2_cavalry_color: Color = Color(0.8, 0.2, 0.2)  # Red
@export var team2_archer_color: Color = Color(0.6, 0.1, 0.1)   # Dark red
@export var team2_flyer_color: Color = Color(1.0, 0.6, 0.4)    # Orange-red (eagle)
@export var team2_projectile_color: Color = Color(1.0, 0.4, 0.4)

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
func get_unit_color(team: int, unit_type: String) -> Color:
	if team == 1:
		match unit_type:
			"footman": return team1_footman_color
			"cavalry": return team1_cavalry_color
			"archer": return team1_archer_color
			"flyer": return team1_flyer_color
			"projectile": return team1_projectile_color
	else:
		match unit_type:
			"footman": return team2_footman_color
			"cavalry": return team2_cavalry_color
			"archer": return team2_archer_color
			"flyer": return team2_flyer_color
			"projectile": return team2_projectile_color
	return Color.WHITE

func get_projectile_max_range() -> float:
	# Max range of a projectile at optimal 45° angle: range = v² / g
	# We use 90% of theoretical max to account for height differences and practical aiming
	return (projectile_speed * projectile_speed / projectile_gravity) * 0.5

func get_unit_stats(unit_type: String) -> Dictionary:
	match unit_type:
		"footman":
			return {
				"hp": footman_hp,
				"speed": footman_speed,
				"damage": footman_damage,
				"attack_delay": footman_attack_delay,
				"attack_range": footman_attack_range,
				"size": footman_size
			}
		"cavalry":
			return {
				"hp": cavalry_hp,
				"speed": cavalry_speed,
				"damage": cavalry_damage,
				"attack_delay": cavalry_attack_delay,
				"attack_range": cavalry_attack_range,
				"size": cavalry_size
			}
		"archer":
			return {
				"hp": archer_hp,
				"speed": archer_speed,
				"damage": archer_damage,
				"attack_delay": archer_attack_delay,
				"attack_range": get_projectile_max_range(),
				"size": archer_size
			}
		"flyer":
			return {
				"hp": flyer_hp,
				"speed": flyer_speed,
				"damage": flyer_damage,
				"attack_delay": flyer_attack_delay,
				"attack_range": flyer_attack_range,
				"size": flyer_size,
				"altitude": flyer_altitude
			}
	return {}
