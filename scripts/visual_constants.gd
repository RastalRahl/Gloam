extends RefCounted
class_name GloamVisualConstants

# TinySwords is authored in 64 px construction units.  These scales are the
# only gameplay-art scale decisions; callers select a source family instead of
# inventing a per-object multiplier.
#
# Calibration targets at the normal 1.0 camera zoom:
#   192 px unit cell x 0.90 -> ~80 px visible warrior/archer body
#   320 px lancer cell x 0.58 -> ~87 px visible lancer body
#   384 px troll cell x 0.65 -> ~137 px visible large enemy body
#   320 px castle x 0.90 -> ~281 px visible building width
const UNIT_SPRITE_SCALE: float = 0.90
const LANCER_SPRITE_SCALE: float = 0.58
const LARGE_ENEMY_SPRITE_SCALE: float = 0.65
const BUILDING_SPRITE_SCALE: float = 0.90
const SMALL_BUILDING_SPRITE_SCALE: float = 0.75
const DEFENSE_SPRITE_SCALE: float = 0.75
const SHRINE_SPRITE_SCALE: float = 0.75
const TREE_SPRITE_SCALE: float = 1.00
const BUSH_SPRITE_SCALE: float = 1.00
const PROP_SPRITE_SCALE: float = 1.00
const GOLD_RESOURCE_SPRITE_SCALE: float = 1.00
const FIELD_SPRITE_SCALE: float = 0.75
const PICKUP_ICON_SPRITE_SCALE: float = 0.75
const TERRAIN_SPRITE_SCALE: float = 1.00
const FORTIFICATION_SPRITE_SCALE: float = 0.50

const PROJECTILE_SPRITE_SCALE: float = 0.50
const EFFECT_SPRITE_SCALE: float = PROJECTILE_SPRITE_SCALE
const BALLISTA_PROJECTILE_SCALE: float = 1.65
const IMPACT_EFFECT_SCALE: float = 0.40
const ELEMENTAL_EFFECT_SCALE: float = 0.70
const DUST_EFFECT_SCALE: float = 0.75
const NIGHT_OUTLINE_SCALE: float = 1.07

# Physics layers are kept separate from combat hurtboxes. Terrain boundaries,
# persistent prop foundations, and temporary gameplay blockers have distinct
# ownership even though the player collides with all three.
const TERRAIN_OBSTACLE_LAYER: int = 4
const PROP_OBSTACLE_LAYER: int = 8
const TEMPORARY_OBSTACLE_LAYER: int = 16
const GATE_OBSTACLE_LAYER: int = 32
# Compatibility alias for callers that still mean permanent world geometry.
const MOVEMENT_OBSTACLE_LAYER: int = TERRAIN_OBSTACLE_LAYER
const CAMERA_ZOOM: Vector2 = Vector2.ONE

# Foundation footprints are intentionally much smaller than the visible roofs.
const ORDINARY_FOOTPRINT: Vector2 = Vector2(24.0, 10.0)
const LARGE_ENEMY_FOOTPRINT: Vector2 = Vector2(42.0, 18.0)
const BUILDING_FOOTPRINT: Vector2 = Vector2(72.0, 18.0)
const DEFENSE_FOOTPRINT: Vector2 = Vector2(64.0, 16.0)

# These tints keep the bright source pack in Gloam's darker fantasy world.
const WORLD_GRADE: Color = Color(0.025, 0.045, 0.065, 0.06)
const NIGHT_GRADE: Color = Color(0.030, 0.055, 0.115, 0.09)


static func prepare_depth_sorted_layer(layer: Node2D) -> void:
    layer.y_sort_enabled = true
