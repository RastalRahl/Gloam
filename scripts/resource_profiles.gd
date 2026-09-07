extends RefCounted
class_name GloamResourceProfiles

## Resource-specific presentation and interaction contract.
##
## `physical_footprint` is intentionally zero for ordinary pickups: their
## visual/validation footprint is separate from movement blocking.  This keeps
## collection readable without turning a log or ore node into a wall.

const PROFILES: Dictionary = {
	"wood": {
		"asset": "wood_resource",
		"sprite_anchor": Vector2(-32.0, -63.0),
		"visual_scale": 0.90,
		"interaction_radius": 40.0,
		"collection_radius": 16.0,
		"placement_footprint": Vector2(42.0, 24.0),
		"physical_footprint": Vector2.ZERO,
		"highlight_position": Vector2(0.0, -5.0),
		"highlight_radius": 25.0,
		"collection_effect_position": Vector2(0.0, -12.0),
		"highlight_color": Color(0.93, 0.70, 0.34, 0.82),
	},
	"stone": {
		"asset": "rock_1",
		"sprite_anchor": Vector2(-32.0, -63.0),
		"visual_scale": 1.10,
		"interaction_radius": 38.0,
		"collection_radius": 16.0,
		"placement_footprint": Vector2(42.0, 24.0),
		"physical_footprint": Vector2.ZERO,
		"highlight_position": Vector2(0.0, -4.0),
		"highlight_radius": 23.0,
		"collection_effect_position": Vector2(0.0, -10.0),
		"highlight_color": Color(0.68, 0.79, 0.84, 0.78),
	},
	"iron": {
		"asset": "gold_stone_1",
		"sprite_anchor": Vector2(-64.0, -127.0),
		"visual_scale": 0.72,
		"interaction_radius": 42.0,
		"collection_radius": 17.0,
		"placement_footprint": Vector2(52.0, 28.0),
		"physical_footprint": Vector2.ZERO,
		"highlight_position": Vector2(0.0, -7.0),
		"highlight_radius": 26.0,
		"collection_effect_position": Vector2(0.0, -18.0),
		"highlight_color": Color(0.93, 0.72, 0.35, 0.86),
	},
	"essence": {
		"asset": "icon_07",
		"sprite_anchor": Vector2(-16.0, -16.0),
		"visual_scale": 0.75,
		"interaction_radius": 36.0,
		"collection_radius": 15.0,
		"placement_footprint": Vector2(30.0, 24.0),
		"physical_footprint": Vector2.ZERO,
		"highlight_position": Vector2(0.0, -4.0),
		"highlight_radius": 21.0,
		"collection_effect_position": Vector2(0.0, -10.0),
		"highlight_color": Color(0.72, 0.58, 1.0, 0.82),
	},
}


static func profile(resource_type: String) -> Dictionary:
	return (PROFILES.get(resource_type, PROFILES["wood"]) as Dictionary).duplicate(true)


static func resource_types() -> Array[String]:
	return ["wood", "stone", "iron", "essence"]
