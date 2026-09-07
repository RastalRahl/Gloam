extends RefCounted
class_name GloamTinySwordsAssetConfig

## Single source of truth for the authored Tiny Swords sheets used by Gloam.
##
## The pack is authored at native pixel scale.  Every animated sheet below is
## recorded from its actual PNG dimensions; no frame is inferred by dividing a
## texture at the call site.  Keep gameplay scale decisions separate from
## these authored dimensions.

const NATIVE_SCALE: float = 1.0

const TEXTURES: Dictionary = {
    "warrior_idle": preload("res://assets/generated/tiny_swords/units/black/warrior/warrior_idle.png"),
    "warrior_run": preload("res://assets/generated/tiny_swords/units/black/warrior/warrior_run.png"),
    "warrior_attack": preload("res://assets/generated/tiny_swords/units/black/warrior/warrior_attack_1.png"),
    "archer_idle": preload("res://assets/generated/tiny_swords/units/black/archer/archer_idle.png"),
    "archer_run": preload("res://assets/generated/tiny_swords/units/black/archer/archer_run.png"),
    "archer_shoot": preload("res://assets/generated/tiny_swords/units/black/archer/archer_shoot.png"),
    "lancer_idle": preload("res://assets/generated/tiny_swords/units/black/lancer/lancer_idle.png"),
    "lancer_run": preload("res://assets/generated/tiny_swords/units/black/lancer/lancer_run.png"),
    "lancer_attack_down": preload("res://assets/generated/tiny_swords/units/black/lancer/lancer_down_attack.png"),
    "lancer_attack_right": preload("res://assets/generated/tiny_swords/units/black/lancer/lancer_right_attack.png"),
    "lancer_attack_up": preload("res://assets/generated/tiny_swords/units/black/lancer/lancer_up_attack.png"),
    "pawn_idle": preload("res://assets/generated/tiny_swords/units/black/pawn/pawn_idle.png"),
    "skull_idle": preload("res://assets/generated/tiny_swords/enemies/skull/skull_idle.png"),
    "skull_run": preload("res://assets/generated/tiny_swords/enemies/skull/skull_run.png"),
    "skull_attack": preload("res://assets/generated/tiny_swords/enemies/skull/skull_attack.png"),
    "spider_idle": preload("res://assets/generated/tiny_swords/enemies/spider/spider_idle.png"),
    "spider_run": preload("res://assets/generated/tiny_swords/enemies/spider/spider_run.png"),
    "spider_attack": preload("res://assets/generated/tiny_swords/enemies/spider/spider_attack.png"),
    "troll_idle": preload("res://assets/generated/tiny_swords/enemies/troll/troll_idle.png"),
    "troll_walk": preload("res://assets/generated/tiny_swords/enemies/troll/troll_walk.png"),
    "troll_windup": preload("res://assets/generated/tiny_swords/enemies/troll/troll_windup.png"),
    "troll_attack": preload("res://assets/generated/tiny_swords/enemies/troll/troll_attack.png"),
    "gnoll_idle": preload("res://assets/generated/tiny_swords/enemies/gnoll/gnoll_idle.png"),
    "gnoll_walk": preload("res://assets/generated/tiny_swords/enemies/gnoll/gnoll_walk.png"),
    "gnoll_throw": preload("res://assets/generated/tiny_swords/enemies/gnoll/gnoll_throw.png"),
    "gnoll_bone": preload("res://assets/generated/tiny_swords/enemies/gnoll/gnoll_bone.png"),
    "giant_bat_idle": preload("res://assets/generated/tiny_swords/enemies/giant_bat/giant_bat_idle.png"),
    "giant_bat_move": preload("res://assets/generated/tiny_swords/enemies/giant_bat/giant_bat_move.png"),
    "giant_bat_attack": preload("res://assets/generated/tiny_swords/enemies/giant_bat/giant_bat_attack.png"),
    "dust_01": preload("res://assets/generated/tiny_swords/effects/dust_01.png"),
    "explosion_01": preload("res://assets/generated/tiny_swords/effects/explosion_01.png"),
    "fire_01": preload("res://assets/generated/tiny_swords/effects/fire_01.png"),
    "water_splash": preload("res://assets/generated/tiny_swords/effects/water_splash.png"),
    "tree_1": preload("res://assets/generated/tiny_swords/terrain/resources/wood/trees/tree_1.png"),
    "tree_2": preload("res://assets/generated/tiny_swords/terrain/resources/wood/trees/tree_2.png"),
    "bush_1": preload("res://assets/generated/tiny_swords/terrain/decorations/bushes/bush_1.png"),
    "bush_2": preload("res://assets/generated/tiny_swords/terrain/decorations/bushes/bush_2.png"),
}

## source_size is the measured PNG size. frame_size, columns, rows, and
## frame_count describe the authored layout exactly. anchor_offset is the
## entity-foot point measured from the centre of an AnimatedSprite2D cell.
const SHEET_LAYOUTS: Dictionary = {
    "warrior_idle": {"source_size": Vector2i(1536, 192), "frame_size": Vector2i(192, 192), "columns": 8, "rows": 1, "frame_count": 8, "anchor_offset": Vector2(0, 40), "intended_scale": 1.0},
    "warrior_run": {"source_size": Vector2i(1152, 192), "frame_size": Vector2i(192, 192), "columns": 6, "rows": 1, "frame_count": 6, "anchor_offset": Vector2(0, 40), "intended_scale": 1.0},
    "warrior_attack": {"source_size": Vector2i(768, 192), "frame_size": Vector2i(192, 192), "columns": 4, "rows": 1, "frame_count": 4, "anchor_offset": Vector2(0, 40), "intended_scale": 1.0},
    "archer_idle": {"source_size": Vector2i(1152, 192), "frame_size": Vector2i(192, 192), "columns": 6, "rows": 1, "frame_count": 6, "anchor_offset": Vector2(0, 39), "intended_scale": 1.0},
    "archer_run": {"source_size": Vector2i(768, 192), "frame_size": Vector2i(192, 192), "columns": 4, "rows": 1, "frame_count": 4, "anchor_offset": Vector2(0, 39), "intended_scale": 1.0},
    "archer_shoot": {"source_size": Vector2i(1536, 192), "frame_size": Vector2i(192, 192), "columns": 8, "rows": 1, "frame_count": 8, "anchor_offset": Vector2(0, 39), "intended_scale": 1.0},
    "lancer_idle": {"source_size": Vector2i(3840, 320), "frame_size": Vector2i(320, 320), "columns": 12, "rows": 1, "frame_count": 12, "anchor_offset": Vector2(0, 38), "intended_scale": 1.0},
    "lancer_run": {"source_size": Vector2i(1920, 320), "frame_size": Vector2i(320, 320), "columns": 6, "rows": 1, "frame_count": 6, "anchor_offset": Vector2(0, 38), "intended_scale": 1.0},
    "lancer_attack_down": {"source_size": Vector2i(960, 320), "frame_size": Vector2i(320, 320), "columns": 3, "rows": 1, "frame_count": 3, "anchor_offset": Vector2(0, 38), "intended_scale": 1.0},
    "lancer_attack_right": {"source_size": Vector2i(960, 320), "frame_size": Vector2i(320, 320), "columns": 3, "rows": 1, "frame_count": 3, "anchor_offset": Vector2(0, 38), "intended_scale": 1.0},
    "lancer_attack_up": {"source_size": Vector2i(960, 320), "frame_size": Vector2i(320, 320), "columns": 3, "rows": 1, "frame_count": 3, "anchor_offset": Vector2(0, 38), "intended_scale": 1.0},
    "pawn_idle": {"source_size": Vector2i(1536, 192), "frame_size": Vector2i(192, 192), "columns": 8, "rows": 1, "frame_count": 8, "anchor_offset": Vector2(0, 38), "intended_scale": 1.0},
    "skull_idle": {"source_size": Vector2i(1536, 192), "frame_size": Vector2i(192, 192), "columns": 8, "rows": 1, "frame_count": 8, "anchor_offset": Vector2(0, 33), "intended_scale": 1.0},
    "skull_run": {"source_size": Vector2i(1152, 192), "frame_size": Vector2i(192, 192), "columns": 6, "rows": 1, "frame_count": 6, "anchor_offset": Vector2(0, 33), "intended_scale": 1.0},
    "skull_attack": {"source_size": Vector2i(1344, 192), "frame_size": Vector2i(192, 192), "columns": 7, "rows": 1, "frame_count": 7, "anchor_offset": Vector2(0, 33), "intended_scale": 1.0},
    "spider_idle": {"source_size": Vector2i(1536, 192), "frame_size": Vector2i(192, 192), "columns": 8, "rows": 1, "frame_count": 8, "anchor_offset": Vector2(0, 40), "intended_scale": 1.0},
    "spider_run": {"source_size": Vector2i(960, 192), "frame_size": Vector2i(192, 192), "columns": 5, "rows": 1, "frame_count": 5, "anchor_offset": Vector2(0, 40), "intended_scale": 1.0},
    "spider_attack": {"source_size": Vector2i(1536, 192), "frame_size": Vector2i(192, 192), "columns": 8, "rows": 1, "frame_count": 8, "anchor_offset": Vector2(0, 40), "intended_scale": 1.0},
    "troll_idle": {"source_size": Vector2i(4608, 384), "frame_size": Vector2i(384, 384), "columns": 12, "rows": 1, "frame_count": 12, "anchor_offset": Vector2(0, 104), "intended_scale": 1.0},
    "troll_walk": {"source_size": Vector2i(3840, 384), "frame_size": Vector2i(384, 384), "columns": 10, "rows": 1, "frame_count": 10, "anchor_offset": Vector2(0, 104), "intended_scale": 1.0},
    "troll_windup": {"source_size": Vector2i(1920, 384), "frame_size": Vector2i(384, 384), "columns": 5, "rows": 1, "frame_count": 5, "anchor_offset": Vector2(0, 104), "intended_scale": 1.0},
    "troll_attack": {"source_size": Vector2i(2304, 384), "frame_size": Vector2i(384, 384), "columns": 6, "rows": 1, "frame_count": 6, "anchor_offset": Vector2(0, 104), "intended_scale": 1.0},
    "gnoll_idle": {"source_size": Vector2i(1152, 192), "frame_size": Vector2i(192, 192), "columns": 6, "rows": 1, "frame_count": 6, "anchor_offset": Vector2(0, 38), "intended_scale": 1.0},
    "gnoll_walk": {"source_size": Vector2i(1536, 192), "frame_size": Vector2i(192, 192), "columns": 8, "rows": 1, "frame_count": 8, "anchor_offset": Vector2(0, 38), "intended_scale": 1.0},
    "gnoll_throw": {"source_size": Vector2i(1536, 192), "frame_size": Vector2i(192, 192), "columns": 8, "rows": 1, "frame_count": 8, "anchor_offset": Vector2(0, 38), "intended_scale": 1.0},
    "gnoll_bone": {"source_size": Vector2i(256, 64), "frame_size": Vector2i(64, 64), "columns": 4, "rows": 1, "frame_count": 4, "anchor_offset": Vector2.ZERO, "intended_scale": 1.0},
    "giant_bat_idle": {"source_size": Vector2i(1152, 192), "frame_size": Vector2i(192, 192), "columns": 6, "rows": 1, "frame_count": 6, "anchor_offset": Vector2(0, 46), "intended_scale": 1.0},
    "giant_bat_move": {"source_size": Vector2i(768, 192), "frame_size": Vector2i(192, 192), "columns": 4, "rows": 1, "frame_count": 4, "anchor_offset": Vector2(0, 46), "intended_scale": 1.0},
    "giant_bat_attack": {"source_size": Vector2i(1344, 192), "frame_size": Vector2i(192, 192), "columns": 7, "rows": 1, "frame_count": 7, "anchor_offset": Vector2(0, 46), "intended_scale": 1.0},
    "dust_01": {"source_size": Vector2i(512, 64), "frame_size": Vector2i(64, 64), "columns": 8, "rows": 1, "frame_count": 8, "anchor_offset": Vector2.ZERO, "intended_scale": 1.0},
    "explosion_01": {"source_size": Vector2i(1536, 192), "frame_size": Vector2i(192, 192), "columns": 8, "rows": 1, "frame_count": 8, "anchor_offset": Vector2.ZERO, "intended_scale": 1.0},
    "fire_01": {"source_size": Vector2i(512, 64), "frame_size": Vector2i(64, 64), "columns": 8, "rows": 1, "frame_count": 8, "anchor_offset": Vector2.ZERO, "intended_scale": 1.0},
    "water_splash": {"source_size": Vector2i(1728, 192), "frame_size": Vector2i(192, 192), "columns": 9, "rows": 1, "frame_count": 9, "anchor_offset": Vector2.ZERO, "intended_scale": 1.0},
    "tree_1": {"source_size": Vector2i(1536, 256), "frame_size": Vector2i(192, 256), "columns": 8, "rows": 1, "frame_count": 8, "anchor_offset": Vector2(0, 112), "intended_scale": 1.0},
    "tree_2": {"source_size": Vector2i(1536, 256), "frame_size": Vector2i(192, 256), "columns": 8, "rows": 1, "frame_count": 8, "anchor_offset": Vector2(0, 112), "intended_scale": 1.0},
    "bush_1": {"source_size": Vector2i(1024, 128), "frame_size": Vector2i(128, 128), "columns": 8, "rows": 1, "frame_count": 8, "anchor_offset": Vector2(0, 11), "intended_scale": 1.0},
    "bush_2": {"source_size": Vector2i(1024, 128), "frame_size": Vector2i(128, 128), "columns": 8, "rows": 1, "frame_count": 8, "anchor_offset": Vector2(0, 11), "intended_scale": 1.0},
}

const STATIC_TEXTURES: Dictionary = {
    "castle": preload("res://assets/generated/tiny_swords/buildings/black/castle.png"),
    "house_1": preload("res://assets/generated/tiny_swords/buildings/black/house_1.png"),
    "house_2": preload("res://assets/generated/tiny_swords/buildings/black/house_2.png"),
    "house_3": preload("res://assets/generated/tiny_swords/buildings/black/house_3.png"),
    "barracks": preload("res://assets/generated/tiny_swords/buildings/black/barracks.png"),
    "tower": preload("res://assets/generated/tiny_swords/buildings/black/tower.png"),
    "archery": preload("res://assets/generated/tiny_swords/buildings/black/archery.png"),
    "monastery": preload("res://assets/generated/tiny_swords/buildings/black/monastery.png"),
    "rock_1": preload("res://assets/generated/tiny_swords/terrain/decorations/rocks/rock_1.png"),
    "rock_2": preload("res://assets/generated/tiny_swords/terrain/decorations/rocks/rock_2.png"),
    "gold_stone_1": preload("res://assets/generated/tiny_swords/terrain/resources/gold/gold_stone_1.png"),
    "gold_resource": preload("res://assets/generated/tiny_swords/terrain/resources/gold/gold_resource.png"),
    "stump_1": preload("res://assets/generated/tiny_swords/props/decorations/stump_1.png"),
	"wood_resource": preload("res://assets/generated/tiny_swords/props/decorations/wood_resource.png"),
	"icon_07": preload("res://assets/generated/tiny_swords/ui/icons/icon_07.png"),
	"skull_spike_01": preload("res://assets/generated/tiny_swords/props/decorations/skull_spike_01.png"),
	"skull_spike_02": preload("res://assets/generated/tiny_swords/props/decorations/skull_spike_02.png"),
}

## Static art is bottom-anchored at the visible foundation, not the PNG's
## transparent bottom edge.  foundation_y is measured in source pixels.
const STATIC_LAYOUTS: Dictionary = {
    "castle": {"source_size": Vector2i(320, 256), "foundation_y": 248},
    "house_1": {"source_size": Vector2i(128, 192), "foundation_y": 172},
    "house_2": {"source_size": Vector2i(128, 192), "foundation_y": 177},
    "house_3": {"source_size": Vector2i(128, 192), "foundation_y": 171},
    "barracks": {"source_size": Vector2i(192, 256), "foundation_y": 244},
    "tower": {"source_size": Vector2i(128, 256), "foundation_y": 230},
    "archery": {"source_size": Vector2i(192, 256), "foundation_y": 239},
    "monastery": {"source_size": Vector2i(192, 320), "foundation_y": 309},
    "rock_1": {"source_size": Vector2i(64, 64), "foundation_y": 51},
    "rock_2": {"source_size": Vector2i(64, 64), "foundation_y": 53},
    "gold_stone_1": {"source_size": Vector2i(128, 128), "foundation_y": 79},
    "gold_resource": {"source_size": Vector2i(128, 128), "foundation_y": 75},
    "stump_1": {"source_size": Vector2i(192, 256), "foundation_y": 240},
	"wood_resource": {"source_size": Vector2i(64, 64), "foundation_y": 46},
	"icon_07": {"source_size": Vector2i(64, 64), "foundation_y": 59},
	"skull_spike_01": {"source_size": Vector2i(64, 128), "foundation_y": 95},
	"skull_spike_02": {"source_size": Vector2i(64, 128), "foundation_y": 107},
}

## Gameplay alignment contract for every reusable environmental prop.  The
## sprite position is derived from the imported PNG's meaningful opaque
## bounds, while category-specific scale and footprint stay here.  Scene
## instances may keep legacy exported values for editor compatibility, but
## this table is authoritative at runtime.
const PROP_ALIGNMENT: Dictionary = {
	"tree_1": {"category": "tree", "visual_scale": 1.0, "footprint_size": Vector2(30.0, 14.0), "collision_enabled": true},
	"tree_2": {"category": "tree", "visual_scale": 1.0, "footprint_size": Vector2(30.0, 14.0), "collision_enabled": true},
	"bush_1": {"category": "bush", "visual_scale": 1.0, "footprint_size": Vector2(24.0, 8.0), "collision_enabled": true},
	"bush_2": {"category": "bush", "visual_scale": 1.0, "footprint_size": Vector2(24.0, 8.0), "collision_enabled": true},
	"rock_1": {"category": "rock", "visual_scale": 1.0, "footprint_size": Vector2(28.0, 12.0), "collision_enabled": true},
	"rock_2": {"category": "rock", "visual_scale": 1.0, "footprint_size": Vector2(32.0, 14.0), "collision_enabled": true},
	"gold_stone_1": {"category": "ore", "visual_scale": 1.0, "footprint_size": Vector2(30.0, 14.0), "collision_enabled": true},
	"gold_resource": {"category": "ore", "visual_scale": 1.0, "footprint_size": Vector2(26.0, 12.0), "collision_enabled": true},
	"stump_1": {"category": "stump", "visual_scale": 1.0, "footprint_size": Vector2(32.0, 16.0), "collision_enabled": true},
	"wood_resource": {"category": "collectible", "visual_scale": 0.9, "footprint_size": Vector2.ZERO, "collision_enabled": false},
	"skull_spike_01": {"category": "rubble", "visual_scale": 1.0, "footprint_size": Vector2(20.0, 10.0), "collision_enabled": true},
	"skull_spike_02": {"category": "rubble", "visual_scale": 1.0, "footprint_size": Vector2(20.0, 10.0), "collision_enabled": true},
	"tower": {"category": "structure", "visual_scale": 0.75, "footprint_size": Vector2(64.0, 16.0), "collision_enabled": true},
}

const TERRAIN_TEXTURE: Texture2D = preload("res://assets/generated/tiny_swords/terrain/tileset/tilemap_color_1.png")

const TERRAIN_MODULES: Dictionary = {
    "grass_top": Rect2(0, 0, 192, 192),
    "narrow_grass": Rect2(192, 0, 64, 192),
    "narrow_grass_vertical": Rect2(192, 0, 64, 192),
    "grass_edge": Rect2(0, 192, 192, 64),
    "grass_edge_horizontal": Rect2(0, 192, 192, 64),
    "grass_corner": Rect2(192, 192, 64, 64),
    "detached_grass": Rect2(192, 192, 64, 64),
    "grass_bank": Rect2(0, 256, 256, 128),
    "inner_corner_transition": Rect2(0, 256, 256, 128),
    "cliff_top": Rect2(320, 0, 192, 192),
    "narrow_cliff_top": Rect2(512, 0, 64, 192),
    "cliff_edge_horizontal": Rect2(320, 192, 192, 64),
    "detached_cliff": Rect2(512, 192, 64, 64),
    "cliff": Rect2(320, 256, 192, 128),
    "cliff_face": Rect2(320, 256, 192, 128),
    "narrow_cliff_face": Rect2(512, 256, 64, 128),
}

static func texture(asset_key: String) -> Texture2D:
    if TEXTURES.has(asset_key):
        return TEXTURES[asset_key] as Texture2D
    return STATIC_TEXTURES.get(asset_key) as Texture2D


static func prop_profile(asset_key: String) -> Dictionary:
    return (PROP_ALIGNMENT.get(asset_key, PROP_ALIGNMENT["rock_1"]) as Dictionary).duplicate(true)


static func alignment_for_asset(asset_key: String, visual_scale: float = 1.0) -> Dictionary:
    var source_texture := texture(asset_key)
    return alignment_for_texture(source_texture, visual_scale, SHEET_LAYOUTS.has(asset_key))


static func alignment_for_texture(source_texture: Texture2D, visual_scale: float = 1.0, animated: bool = false) -> Dictionary:
    if source_texture == null:
        return {"sprite_position": Vector2.ZERO, "visible_rect": Rect2(), "opaque_bounds": Rect2i()}
    var image := source_texture.get_image()
    var frame_size := Vector2i(image.get_width(), image.get_height())
    if animated:
        var layout := layout_for_texture(source_texture)
        frame_size = layout.get("frame_size", frame_size)
    var frame_rect := Rect2i(Vector2i.ZERO, frame_size)
    var opaque_bounds := image.get_region(frame_rect).get_used_rect()
    if opaque_bounds.size == Vector2i.ZERO:
        opaque_bounds = frame_rect
    var sprite_position: Vector2
    if animated:
        var frame_center := Vector2(frame_size) * 0.5
        sprite_position = Vector2(
            -(float(opaque_bounds.get_center().x) - frame_center.x),
            -(float(opaque_bounds.end.y) - frame_center.y)
        ) * visual_scale
    else:
        sprite_position = Vector2(-float(opaque_bounds.get_center().x), -float(opaque_bounds.end.y)) * visual_scale
    var visible_rect := Rect2(
        Vector2(-Vector2(opaque_bounds.size).x * 0.5 * visual_scale, -Vector2(opaque_bounds.size).y * visual_scale),
        Vector2(opaque_bounds.size) * visual_scale
    )
    return {
        "sprite_position": sprite_position,
        "visible_rect": visible_rect,
        "opaque_bounds": opaque_bounds,
        "frame_size": frame_size,
        "visual_scale": visual_scale,
    }


static func terrain_texture() -> Texture2D:
    return TERRAIN_TEXTURE


static func terrain_module(module_key: String) -> Rect2:
    return TERRAIN_MODULES[module_key] as Rect2


static func layout(asset_key: String) -> Dictionary:
    return SHEET_LAYOUTS[asset_key] as Dictionary


static func layout_for_texture(source_texture: Texture2D) -> Dictionary:
    for asset_key: String in SHEET_LAYOUTS:
        if TEXTURES.get(asset_key) == source_texture:
            var layout: Dictionary = SHEET_LAYOUTS[asset_key].duplicate()
            layout["asset_key"] = asset_key
            return layout
    return {}


static func static_layout_for_texture(source_texture: Texture2D) -> Dictionary:
    for asset_key: String in STATIC_TEXTURES:
        if STATIC_TEXTURES[asset_key] == source_texture:
            var static_layout: Dictionary = STATIC_LAYOUTS.get(asset_key, {}).duplicate()
            static_layout["asset_key"] = asset_key
            return static_layout
    return {}


static func animation(animation_name: String, asset_key: String, fps: float, loop: bool = true) -> Dictionary:
    var layout: Dictionary = SHEET_LAYOUTS.get(asset_key, {})
    var definition: Dictionary = layout.duplicate()
    definition["name"] = animation_name
    definition["texture"] = texture(asset_key)
    definition["fps"] = fps
    definition["loop"] = loop
    return definition


static func animation_for_texture(animation_name: String, source_texture: Texture2D, fps: float, loop: bool = true) -> Dictionary:
    for asset_key: String in TEXTURES:
        if TEXTURES[asset_key] == source_texture:
            return animation(animation_name, asset_key, fps, loop)
    push_error("Tiny Swords texture is missing from the centralized frame registry.")
    return {}


static func build_sprite_frames(definitions: Array[Dictionary]) -> SpriteFrames:
    var frames := SpriteFrames.new()
    for definition: Dictionary in definitions:
        var animation_name: String = str(definition.get("name", ""))
        var source_texture: Texture2D = definition.get("texture") as Texture2D
        var frame_size: Vector2i = definition.get("frame_size", Vector2i.ZERO)
        var columns: int = int(definition.get("columns", 0))
        var rows: int = int(definition.get("rows", 0))
        var frame_count: int = int(definition.get("frame_count", 0))
        if animation_name.is_empty() or source_texture == null or frame_size == Vector2i.ZERO or columns <= 0 or rows <= 0 or frame_count <= 0:
            push_error("Invalid Tiny Swords frame definition: %s" % animation_name)
            continue
        var expected_size := Vector2i(frame_size.x * columns, frame_size.y * rows)
        var actual_size := Vector2i(source_texture.get_width(), source_texture.get_height())
        if actual_size != definition.get("source_size", actual_size) or actual_size != expected_size or frame_count > columns * rows:
            push_error("Tiny Swords sheet layout mismatch for %s: expected %s, got %s" % [animation_name, expected_size, actual_size])
            continue
        frames.add_animation(animation_name)
        frames.set_animation_speed(animation_name, float(definition.get("fps", 8.0)))
        frames.set_animation_loop(animation_name, bool(definition.get("loop", true)))
        for frame_index: int in range(frame_count):
            var atlas := AtlasTexture.new()
            atlas.atlas = source_texture
            atlas.region = Rect2(
                (frame_index % columns) * frame_size.x,
                (frame_index / columns) * frame_size.y,
                frame_size.x,
                frame_size.y
            )
            frames.add_frame(animation_name, atlas)
    return frames
