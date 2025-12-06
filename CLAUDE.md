# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A 3D real-time autobattler built in Godot 4.5 using GDScript. Two teams of units (footman, cavalry, archer) spawn on opposite sides of a battlefield and fight autonomously.

## Running the Game

- **In Editor:** Open project in Godot 4.5, press F5 (main scene: `scenes/main.tscn`)
- **Web Build:** Open `docs/index.html` in browser

## Architecture

### Autoload Singletons
- **GameConfig** (`scripts/game_config.gd`) - All tweakable parameters (unit stats, colors, battlefield size, projectile physics)
- **GameManager** (`scripts/game_manager.gd`) - Unit spawning, kill tracking, score signals

### Unit System
Units extend `CharacterBody3D` with a state machine:
```
enum UnitState { IDLE, MOVING, ATTACKING }
enum TargetingMode { CLOSEST, FARTHEST }
```

**Base Unit** (`scripts/units/base_unit.gd`):
- State machine in `_physics_process()`: IDLE → MOVING → ATTACKING
- `_find_target()` - Selects enemy based on targeting mode
- `_move_towards_target()` - Movement with friendly avoidance steering
- `_get_friendly_avoidance()` - Prevents unit clustering
- Collision layers: Team 1 = layer 2, Team 2 = layer 4, Projectiles = layer 8

**Archer Unit** (`scripts/units/archer_unit.gd`):
- Ballistic prediction system (`_predict_target_position()`)
- Friendly fire avoidance (`_would_hit_friendly()`)
- Aim deviation for imperfect accuracy

### Projectile System
`scripts/projectile.gd` - RigidBody3D with ballistic trajectory:
- Calculates launch angle for predicted target intercept
- Applies stagger to hit units
- Attaches to units on impact (sticks in them)

### Scene Hierarchy
```
Main (Node3D)
├── Battlefield/Ground - Static collision
├── Camera3D - Isometric camera with WASD/QE/ZC controls
├── Units - Spawned unit container
├── Projectiles - Arrow container
└── UI (CanvasLayer) - Spawn buttons, scores, tweaks panel
```

## Key Patterns

- **Groups:** Units join `"units"` and `"team_1"` or `"team_2"` groups for targeting
- **Signals:** `unit_died(unit)`, `score_changed(team, kills)`
- **Stats lookup:** `GameConfig.get_unit_stats(unit_type)` returns dictionary with hp, speed, damage, attack_delay, attack_range, size
- **Spawn:** `GameManager.spawn_unit(unit_type, team)` or `spawn_random_unit(team)`

## Unit Stats (from GameConfig)

| Type | HP | Speed | Damage | Range | Targeting |
|------|-----|-------|--------|-------|-----------|
| Footman | 100 | 3.0 | 15 | 1.5 | CLOSEST |
| Cavalry | 80 | 7.0 | 25 | 1.8 | FARTHEST |
| Archer | 50 | 2.0 | 20 | ~48 (ballistic) | CLOSEST |

## Adding New Unit Types

1. Add stats exports to `game_config.gd` and update `get_unit_stats()`
2. Add color exports and update `get_unit_color()`
3. Create scene in `scenes/units/` inheriting from base_unit.tscn
4. Add scene preload to `game_manager.gd` unit_scenes dictionary
5. (Optional) Create custom script extending BaseUnit for special behavior
