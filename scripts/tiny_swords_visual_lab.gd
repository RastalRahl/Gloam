extends Node2D

## Developer-only calibration board for the Tiny Swords runtime foundation.
## Everything is placed from the same authored family scales used by gameplay.

const ASSETS := preload("res://scripts/tiny_swords_asset_config.gd")
const VISUALS := preload("res://scripts/visual_constants.gd")
const OVERLAY_SCRIPT := preload("res://scripts/tiny_swords_visual_lab_overlay.gd")

const VIEW_SIZE := Vector2(1280, 720)
const PANEL_COLOR := Color("18202d")
const PANEL_EDGE := Color("42526a")
const TEXT_COLOR := Color("e9e1c9")
const MUTED_TEXT := Color("9ba9b6")
const ACCENT := Color("d7b56d")

@export var show_debug_footprints: bool = true
@export var capture_on_ready: bool = true

var _debug_marks: Array[Dictionary] = []


func _ready() -> void:
    RenderingServer.set_default_clear_color(Color("0b1018"))
    _build_board()
    if show_debug_footprints:
        var overlay := Node2D.new()
        overlay.name = "DebugFootprints"
        overlay.set_script(OVERLAY_SCRIPT)
        overlay.z_index = 100
        add_child(overlay)
        overlay.configure(_debug_marks)
    if capture_on_ready:
        RenderingServer.frame_post_draw.connect(_capture_screenshot, CONNECT_ONE_SHOT)


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("0b1018"))
    draw_rect(Rect2(0, 0, VIEW_SIZE.x, 52), Color("111a27"))
    draw_line(Vector2(0, 51), Vector2(VIEW_SIZE.x, 51), Color("5d7390"), 2.0)

    _panel(Rect2(20, 70, 605, 250))
    _panel(Rect2(645, 70, 615, 250))
    _panel(Rect2(20, 340, 380, 360))
    _panel(Rect2(410, 340, 610, 360))
    _panel(Rect2(1035, 340, 225, 360))


func _build_board() -> void:
    _label("TINY SWORDS  /  VISUAL LAB", Vector2(22, 12), 22, TEXT_COLOR)
    _label("calibrated gameplay scale  •  nearest neighbour  •  feet/foundation anchors", Vector2(510, 18), 13, MUTED_TEXT)

    _label("WARRIOR  ·  192 × 192 cells", Vector2(38, 82), 16, ACCENT)
    _add_animation("warrior_idle", "idle", Vector2(135, 285), "IDLE", 8.0, Color("6fb6a4"), Vector2(28, 18))
    _add_animation("warrior_run", "run", Vector2(330, 285), "RUN", 10.0, Color("6fa7d1"), Vector2(28, 18))
    _add_animation("warrior_attack", "attack", Vector2(525, 285), "ATTACK", 8.0, Color("d98e65"), Vector2(32, 20), false)

    _label("BUILDINGS  ·  static authored dimensions", Vector2(665, 82), 16, ACCENT)
    _add_building("castle", Vector2(805, 310), "CASTLE", Vector2(252, 44), Color("d7b56d"))
    _add_building("house_1", Vector2(1038, 310), "HOUSE", Vector2(92, 34), Color("8dbb7a"))
    _add_building("tower", Vector2(1180, 310), "TOWER", Vector2(86, 34), Color("8db4d0"))

    _label("NORMAL ENEMY", Vector2(38, 356), 14, ACCENT)
    _label("LARGE ENEMY", Vector2(250, 356), 14, ACCENT)
    _add_animation("skull_idle", "idle", Vector2(105, 635), "SKULL", 8.0, Color("d46c6c"), Vector2(30, 18))
    _add_animation("troll_idle", "idle", Vector2(300, 662), "TROLL", 7.0, Color("e3a464"), Vector2(64, 34))

    _label("TERRAIN MODULES  ·  64px grid atlas", Vector2(428, 344), 14, ACCENT)
    _add_terrain_module("wall", "WALL", Vector2(425, 355), ASSETS.terrain_module("cliff"), Color("b5b7cf"), Vector2(56, 20))
    _add_terrain_module("gate", "GATE", Vector2(625, 355), ASSETS.terrain_module("cliff"), Color("d7a66d"), Vector2(56, 20))
    _add_terrain_module("cliff", "CLIFF", Vector2(825, 355), ASSETS.terrain_module("cliff"), Color("91a9c1"), Vector2(56, 20))
    _add_terrain_module("grass_top", "GRASS TOP", Vector2(425, 495), ASSETS.terrain_module("grass_top"), Color("9fce68"), Vector2(152, 26))
    _add_terrain_module("narrow_grass", "NARROW", Vector2(630, 495), ASSETS.terrain_module("narrow_grass"), Color("9fce68"), Vector2(44, 20))
    _add_terrain_module("grass_edge", "EDGE", Vector2(710, 495), ASSETS.terrain_module("grass_edge"), Color("9fce68"), Vector2(152, 20))
    _add_terrain_module("grass_corner", "CORNER", Vector2(910, 495), ASSETS.terrain_module("grass_corner"), Color("9fce68"), Vector2(44, 20))
    _add_terrain_module("grass_bank", "BANK", Vector2(710, 555), ASSETS.terrain_module("grass_bank"), Color("9fce68"), Vector2(152, 28))

    _label("PROPS / DECORATIONS", Vector2(1053, 356), 14, ACCENT)
    _add_animation("tree_1", "idle", Vector2(1090, 690), "TREE", 5.0, Color("70bd8e"), Vector2(54, 28))
    _add_animation("bush_2", "idle", Vector2(1188, 508), "BUSH", 6.0, Color("70bd8e"), Vector2(46, 18))
    _add_static("rock_1", Vector2(1218, 572), "ROCK", Color("9fb8cb"))
    _add_static("gold_stone_1", Vector2(1158, 572), "GOLD", Color("e0bc61"))
    _add_static("stump_1", Vector2(1190, 684), "STUMP", Color("b78566"), Vector2(74, 18))
    _add_static("wood_resource", Vector2(1240, 650), "WOOD", Color("b78566"))



func _panel(rect: Rect2) -> void:
    draw_rect(rect, PANEL_COLOR)
    draw_rect(rect, PANEL_EDGE, false, 2.0)


func _label(text_value: String, position: Vector2, font_size: int, color: Color) -> void:
    var label := Label.new()
    label.text = text_value
    label.position = position
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
    label.add_theme_constant_override("shadow_offset_x", 2)
    label.add_theme_constant_override("shadow_offset_y", 2)
    label.z_index = 20
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(label)


func _add_animation(asset_key: String, animation_name: String, anchor: Vector2, caption: String, fps: float, color: Color, footprint: Vector2, looped: bool = true) -> void:
    var sprite := AnimatedSprite2D.new()
    sprite.name = caption
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.sprite_frames = ASSETS.build_sprite_frames([ASSETS.animation(animation_name, asset_key, fps, looped)])
    sprite.animation = animation_name
    sprite.autoplay = animation_name
    var layout: Dictionary = ASSETS.layout(asset_key)
    var visual_scale: float = VISUALS.UNIT_SPRITE_SCALE
    if asset_key.begins_with("lancer"):
        visual_scale = VISUALS.LANCER_SPRITE_SCALE
    elif asset_key.begins_with("troll"):
        visual_scale = VISUALS.LARGE_ENEMY_SPRITE_SCALE
    elif asset_key.begins_with("tree"):
        visual_scale = VISUALS.TREE_SPRITE_SCALE
    elif asset_key.begins_with("bush"):
        visual_scale = VISUALS.BUSH_SPRITE_SCALE
    sprite.scale = Vector2.ONE * visual_scale
    sprite.position = anchor - layout["anchor_offset"] * visual_scale
    add_child(sprite)
    _label(caption, anchor + Vector2(-32, 11), 12, color)
    _debug_marks.append({"anchor": anchor, "footprint": footprint, "color": color})


func _add_building(asset_key: String, anchor: Vector2, caption: String, footprint: Vector2, color: Color) -> void:
    var sprite := Sprite2D.new()
    sprite.name = caption
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.texture = ASSETS.texture(asset_key)
    sprite.centered = false
    var visual_scale: float = VISUALS.BUILDING_SPRITE_SCALE if asset_key == "castle" else VISUALS.SMALL_BUILDING_SPRITE_SCALE
    var layout: Dictionary = ASSETS.static_layout_for_texture(sprite.texture)
    var foundation_y: float = float(layout.get("foundation_y", sprite.texture.get_height()))
    sprite.scale = Vector2.ONE * visual_scale
    sprite.position = anchor - Vector2(sprite.texture.get_width() * visual_scale * 0.5, foundation_y * visual_scale)
    add_child(sprite)
    _label(caption, anchor + Vector2(-30, 5), 11, color)
    _debug_marks.append({"anchor": anchor, "footprint": footprint, "color": color})


func _add_terrain_module(caption: String, label_text: String, position: Vector2, region: Rect2, color: Color, footprint: Vector2) -> void:
    var sprite := Sprite2D.new()
    sprite.name = caption
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.texture = ASSETS.terrain_texture()
    sprite.region_enabled = true
    sprite.region_rect = region
    sprite.centered = false
    sprite.position = position
    add_child(sprite)
    _label(label_text, position + Vector2(0, region.size.y + 3), 11, color)
    var anchor := position + Vector2(region.size.x * 0.5, region.size.y)
    _debug_marks.append({"anchor": anchor, "footprint": footprint, "color": color})


func _add_static(asset_key: String, position: Vector2, caption: String, color: Color, footprint: Vector2 = Vector2(28, 16)) -> void:
    var sprite := Sprite2D.new()
    sprite.name = caption
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.texture = ASSETS.texture(asset_key)
    sprite.centered = false
    var visual_scale: float = VISUALS.GOLD_RESOURCE_SPRITE_SCALE if asset_key.begins_with("gold") else VISUALS.PROP_SPRITE_SCALE
    var layout: Dictionary = ASSETS.static_layout_for_texture(sprite.texture)
    var foundation_y: float = float(layout.get("foundation_y", sprite.texture.get_height()))
    sprite.scale = Vector2.ONE * visual_scale
    sprite.position = position - Vector2(sprite.texture.get_width() * visual_scale * 0.5, foundation_y * visual_scale)
    add_child(sprite)
    _label(caption, position + Vector2(-25, 15), 10, color)
    _debug_marks.append({"anchor": position, "footprint": footprint, "color": color})


func _capture_screenshot() -> void:
    var viewport_texture := get_viewport().get_texture()
    if viewport_texture == null:
        push_warning("Tiny Swords visual lab capture skipped: headless renderer has no viewport texture.")
        return
    var image := viewport_texture.get_image()
    var result := image.save_png("res://visual_comparison/task1_visual_lab.png")
    print("Tiny Swords visual lab screenshot: %s" % result)
