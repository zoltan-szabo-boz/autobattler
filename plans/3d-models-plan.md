# Plan: Replace Box Meshes with Animated 3D Models

## Overview
Replace the procedural box meshes for units (footman, cavalry, archer) with animated 3D models using free CC0 assets. Include idle, walk, and attack animations.

## Recommended Free Asset Sources (CC0 License)

### Primary: Quaternius
- **Website:** https://quaternius.com/
- **LowPoly Animated Knight** - Perfect for footman (has idle, walk, attack animations)
- **LowPoly RPG Characters** - Includes warrior, ranger (archer), rogue variants
- **Format:** FBX, OBJ, Blend, GLTF
- **License:** CC0 (public domain)

### Alternative: Kenney Retro Medieval Kit
- **Website:** https://kenney.nl/ (also on OpenGameArt.org)
- 100+ retro-style medieval models
- **Format:** GLB, FBX, OBJ
- **License:** CC0

### For Cavalry: Quaternius Animals
- Has low-poly horses that could work for cavalry units

---

## Implementation Plan

### Step 1: Download Assets (Manual - User Action)
Download from Quaternius (https://quaternius.com/):
- **Ultimate Animated Characters** or **LowPoly Animated Knight** for footman
- **LowPoly RPG Characters** for archer (ranger character)
- **Ultimate Animated Animals** for cavalry (horse + rider combo)

Extract and place in project:
```
res://assets/models/
├── footman/
│   └── knight.glb
├── cavalry/
│   └── cavalry.glb (or horse.glb + rider)
├── archer/
│   └── ranger.glb
└── arrow.glb (simple cylinder or from Kenney)
```

### Step 2: Create Model Wrapper Scenes
For each model, create a `.tscn` scene that:
- Has correct scale (Quaternius models may need scaling)
- Has correct rotation (face +X direction to match unit movement)
- Names the main mesh "MeshInstance3D" for code compatibility

### Step 3: Modify `base_unit.gd` - Add Model & Animation Support
**File:** `scripts/units/base_unit.gd`

Add new variables:
```gdscript
var model_scenes: Dictionary = {
    "footman": preload("res://assets/models/footman/footman.tscn"),
    "cavalry": preload("res://assets/models/cavalry/cavalry.tscn"),
    "archer": preload("res://assets/models/archer/archer.tscn")
}
var animation_player: AnimationPlayer = null
var model_root: Node3D = null
```

Replace `_setup_visuals()`:
```gdscript
func _setup_visuals() -> void:
    var stats = GameConfig.get_unit_stats(unit_type)

    if model_scenes.has(unit_type):
        model_root = model_scenes[unit_type].instantiate()
        add_child(model_root)
        mesh_instance = _find_first_mesh(model_root)
        animation_player = _find_animation_player(model_root)
        if animation_player:
            _play_animation("idle")
    else:
        _setup_box_visual(stats)

    _apply_team_color()
```

Add animation helper functions:
```gdscript
func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node
    for child in node.get_children():
        var found = _find_animation_player(child)
        if found:
            return found
    return null

func _play_animation(anim_name: String) -> void:
    if animation_player and animation_player.has_animation(anim_name):
        animation_player.play(anim_name)
```

### Step 4: Integrate Animations with State Machine
**File:** `scripts/units/base_unit.gd` - `_physics_process()`

Update state transitions to trigger animations:
```gdscript
match state:
    UnitState.IDLE:
        _play_animation("idle")
        # ... existing code
    UnitState.MOVING:
        _play_animation("walk")  # or "run"
        _move_towards_target(delta)
    UnitState.ATTACKING:
        _play_animation("attack")
        _attack_target()
```

### Step 5: Update Damage Flash
**File:** `base_unit.gd` - `take_damage()`

Update to handle multiple meshes in model:
```gdscript
func _flash_all_meshes(color: Color) -> void:
    if model_root:
        for mesh in _find_all_meshes(model_root):
            if mesh.material_override:
                mesh.material_override.albedo_color = color
    elif mesh_instance and mesh_instance.material_override:
        mesh_instance.material_override.albedo_color = color
```

### Step 6: Update Projectile to Cylinder
**File:** `scripts/projectile.gd`

Replace BoxMesh with CylinderMesh for arrow-like appearance:
```gdscript
func _setup_visuals() -> void:
    mesh_instance = MeshInstance3D.new()
    var cylinder = CylinderMesh.new()
    cylinder.top_radius = 0.05
    cylinder.bottom_radius = 0.05
    cylinder.height = 0.6
    mesh_instance.mesh = cylinder
    mesh_instance.rotation.x = PI / 2  # Point forward
    # ... material setup
```

### Step 7: Keep Collision System
No changes needed - BoxShape3D collision works independently of visuals.

---

## Files to Modify
| File | Changes |
|------|---------|
| `scripts/units/base_unit.gd` | Model loading, animation player integration |
| `scripts/units/archer_unit.gd` | May need animation overrides for ranged attack |
| `scripts/projectile.gd` | Replace box with cylinder mesh |
| New: `assets/models/*/` | Downloaded .glb files + wrapper .tscn scenes |

## Asset Setup Notes
When importing .glb models in Godot:
1. Import settings: Enable "Import as Scene"
2. AnimationPlayer will be auto-created from embedded animations
3. Common animation names to look for: "Idle", "Walk", "Run", "Attack", "Death"
4. May need to rename animations to match our code expectations

## Complexity: Medium-High
- Code changes are straightforward
- Main effort is:
  - Downloading correct assets
  - Setting up .tscn wrapper scenes with correct scale/rotation
  - Mapping animation names to our state machine
