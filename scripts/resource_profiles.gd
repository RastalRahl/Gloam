extends RefCounted
class_name GloamResourceProfiles

## Resource-specific gameplay contract. Art placement, collection shape,
## highlight origin, effect origin, and placement footprint all resolve from
## the same opaque-bounds alignment returned by the asset registry.

const ASSETS := preload("res://scripts/tiny_swords_asset_config.gd")

const PROFILES: Dictionary = {
	"wood": {
		"asset_key": "wood_resource",
		"visual_scale": 0.90,
		"interaction_radius": 40.0,
		"collection_radius": 16.0,
		"placement_footprint": Vector2(32.0, 12.0),
		"physical_footprint": Vector2.ZERO,
		"highlight_radius": 25.0,
		"highlight_color": Color(0.93, 0.70, 0.34, 0.82),
	},
	"stone": {
		"asset_key": "rock_1",
		"visual_scale": 1.10,
		"interaction_radius": 38.0,
		"collection_radius": 16.0,
		"placement_footprint": Vector2(24.0, 10.0),
		"physical_footprint": Vector2.ZERO,
		"highlight_radius": 23.0,
		"highlight_color": Color(0.68, 0.79, 0.84, 0.78),
	},
	"iron": {
		"asset_key": "gold_stone_1",
		"visual_scale": 0.72,
		"interaction_radius": 42.0,
		"collection_radius": 17.0,
		"placement_footprint": Vector2(20.0, 10.0),
		"physical_footprint": Vector2.ZERO,
		"highlight_radius": 26.0,
		"highlight_color": Color(0.93, 0.72, 0.35, 0.86),
	},
	"essence": {
		"asset_key": "icon_07",
		"visual_scale": 0.75,
		"interaction_radius": 36.0,
		"collection_radius": 15.0,
		"placement_footprint": Vector2(20.0, 12.0),
		"physical_footprint": Vector2.ZERO,
		"highlight_radius": 21.0,
		"highlight_color": Color(0.72, 0.58, 1.0, 0.82),
	},
}


static func profile(resource_type: String) -> Dictionary:
	var result := (PROFILES.get(resource_type, PROFILES["wood"]) as Dictionary).duplicate(true)
	var asset_key: String = str(result["asset_key"])
	var alignment := ASSETS.alignment_for_asset(asset_key, float(result["visual_scale"]))
	var visible_rect: Rect2 = alignment["visible_rect"]
	result["sprite_anchor"] = alignment["sprite_position"]
	result["visible_rect"] = visible_rect
	result["collection_position"] = visible_rect.get_center()
	result["highlight_position"] = visible_rect.get_center()
	result["collection_effect_position"] = visible_rect.get_center()
	result["asset"] = asset_key
	return result


static func resource_types() -> Array[String]:
	return ["wood", "stone", "iron", "essence"]
