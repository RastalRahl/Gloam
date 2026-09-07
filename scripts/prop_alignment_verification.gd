extends Node2D

## Focused geometry and visual verification for reusable props and pickups.
## SpawnMarker crosshairs are intentionally not included: this board draws
## only the real GroundFootprint and ResourceNode collection shapes.

const WORLD_PROP_SCENE := preload("res://scenes/world/components/world_prop.tscn")
const RESOURCE_NODE_SCENE := preload("res://scenes/resource_node.tscn")
const ASSETS := preload("res://scripts/tiny_swords_asset_config.gd")
const RESOURCE_PROFILES := preload("res://scripts/resource_profiles.gd")

const OUTPUT_PATH := "res://visual_comparison/prop_alignment_verification.png"
const PROP_KEYS: Array[String] = [
	"tree_1", "tree_2", "bush_1", "bush_2", "rock_1", "rock_2",
	"gold_stone_1", "gold_resource", "stump_1", "wood_resource",
	"skull_spike_01", "skull_spike_02", "tower",
]
const RESOURCE_KEYS: Array[String] = ["wood", "stone", "iron", "essence"]
const VIEW_SIZE := Vector2(1280.0, 1400.0)
const PANEL_SIZE := Vector2(300.0, 260.0)
const GRID_ORIGIN := Vector2(8.0, 52.0)
const GRID_STEP := Vector2(318.0, 270.0)

var failures: int = 0
var entries: Array[Dictionary] = []


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(VIEW_SIZE))
	RenderingServer.set_default_clear_color(Color("0b1018"))
	call_deferred("_run")


func _run() -> void:
	_build_board()
	await get_tree().process_frame
	_check_profile_geometry()
	_check_runtime_instances()
	queue_redraw()
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		print("Capture skipped: headless renderer has no default viewport texture")
	else:
		var viewport_texture := get_viewport().get_texture()
		if viewport_texture == null:
			print("Capture skipped: renderer has no default viewport texture")
			print("Prop alignment verification: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
			get_tree().quit(1 if failures > 0 else 0)
			return
		var image: Image = viewport_texture.get_image()
		if image == null:
			print("Capture skipped: headless renderer returned an empty viewport image")
		elif image.get_size() != Vector2i(VIEW_SIZE):
			_fail("alignment capture has unexpected size %s" % image.get_size())
		else:
			var result := image.save_png(OUTPUT_PATH)
			if result != OK:
				_fail("could not save %s" % OUTPUT_PATH)
			else:
				print("Captured prop alignment verification: %s" % OUTPUT_PATH)
	print("Prop alignment verification: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(1 if failures > 0 else 0)


func _build_board() -> void:
	_add_label("PROP / COLLECTIBLE ALIGNMENT  •  GAMEPLAY ZOOM 1.0", Vector2(16, 12), 20, Color("e9e1c9"))
	_add_label("green = ground root   cyan = opaque visual bounds   red = physical footprint   blue = collection area   gold = placement footprint", Vector2(16, 34), 11, Color("9ba9b6"))
	var index := 0
	for asset_key: String in PROP_KEYS:
		var prop := WORLD_PROP_SCENE.instantiate() as GloamWorldProp
		prop.asset_kind = asset_key
		var panel := _panel_position(index)
		prop.position = panel + Vector2(PANEL_SIZE.x * 0.5, 248.0)
		add_child(prop)
		var profile := ASSETS.prop_profile(asset_key)
		entries.append({"root": prop, "label": asset_key, "category": profile["category"], "panel": panel, "profile": profile, "is_resource": false})
		_add_label(asset_key.to_upper(), panel + Vector2(8, 8), 12, Color("d7b56d"))
		index += 1
	for resource_type: String in RESOURCE_KEYS:
		var resource := RESOURCE_NODE_SCENE.instantiate() as GloamResourceNode
		resource.resource_type = resource_type
		var panel := _panel_position(index)
		resource.position = panel + Vector2(PANEL_SIZE.x * 0.5, 248.0)
		add_child(resource)
		entries.append({"root": resource, "label": resource_type, "category": "collectible", "panel": panel, "profile": RESOURCE_PROFILES.profile(resource_type), "is_resource": true})
		_add_label("PICKUP / " + resource_type.to_upper(), panel + Vector2(8, 8), 12, Color("d7b56d"))
		index += 1


func _panel_position(index: int) -> Vector2:
	return GRID_ORIGIN + Vector2(index % 4, index / 4) * GRID_STEP


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("0b1018"))
	for entry: Dictionary in entries:
		var panel: Vector2 = entry["panel"]
		var root: Node2D = entry["root"]
		var profile: Dictionary = entry["profile"]
		draw_rect(Rect2(panel, PANEL_SIZE), Color("18202d"))
		draw_rect(Rect2(panel, PANEL_SIZE), Color("42526a"), false, 1.0)
		var anchor := root.position
		var alignment := ASSETS.alignment_for_asset(str(profile["asset"]), float(profile["visual_scale"])) if entry["is_resource"] else ASSETS.alignment_for_asset(entry["label"], float(profile["visual_scale"]))
		var visible_rect: Rect2 = alignment["visible_rect"]
		draw_rect(Rect2(anchor + visible_rect.position, visible_rect.size), Color(0.25, 0.85, 0.95, 0.68), false, 1.0)
		draw_line(anchor + Vector2(-6, 0), anchor + Vector2(6, 0), Color("70e0a0"), 1.5)
		draw_line(anchor + Vector2(0, -6), anchor + Vector2(0, 6), Color("70e0a0"), 1.5)
		if entry["is_resource"]:
			var shape := root.get_node("CollisionShape2D") as CollisionShape2D
			var circle := shape.shape as CircleShape2D
			draw_circle(anchor + shape.position, circle.radius, Color(0.25, 0.55, 1.0, 0.20))
			draw_arc(anchor + shape.position, circle.radius, 0.0, TAU, 48, Color("68a8ff"), 1.5)
			var placement: Vector2 = profile["placement_footprint"]
			draw_rect(Rect2(anchor + Vector2(-placement.x * 0.5, -placement.y), placement), Color("d7b56d"), false, 1.0)
			draw_line(anchor + visible_rect.get_center(), anchor + shape.position, Color(0.4, 0.65, 1.0, 0.8), 1.0)
		else:
			var footprint_shape := root.get_node("GroundFootprint/CollisionShape2D") as CollisionShape2D
			var rectangle := footprint_shape.shape as RectangleShape2D
			var footprint: Vector2 = rectangle.size
			if footprint != Vector2.ZERO:
				draw_rect(Rect2(anchor + Vector2(-footprint.x * 0.5, -footprint.y), footprint), Color(1.0, 0.3, 0.3, 0.25))
				draw_rect(Rect2(anchor + Vector2(-footprint.x * 0.5, -footprint.y), footprint), Color("ff7070"), false, 1.5)


func _check_profile_geometry() -> void:
	for asset_key: String in PROP_KEYS:
		var profile := ASSETS.prop_profile(asset_key)
		var alignment := ASSETS.alignment_for_asset(asset_key, float(profile["visual_scale"]))
		var visible_rect: Rect2 = alignment["visible_rect"]
		_check(visible_rect.has_area(), "%s has a measured opaque visual region" % asset_key)
		var footprint: Vector2 = profile["footprint_size"]
		if footprint != Vector2.ZERO:
			var physical_rect := Rect2(Vector2(-footprint.x * 0.5, -footprint.y), footprint)
			_check(physical_rect.intersects(visible_rect), "%s physical footprint overlaps visible art" % asset_key)
			var base_band := Rect2(visible_rect.position + Vector2(0.0, visible_rect.size.y * 0.55), Vector2(visible_rect.size.x, visible_rect.size.y * 0.45))
			_check(physical_rect.intersects(base_band), "%s physical footprint touches visible base" % asset_key)

	for resource_type: String in RESOURCE_KEYS:
		var profile := RESOURCE_PROFILES.profile(resource_type)
		var visible_rect: Rect2 = profile["visible_rect"]
		var center: Vector2 = profile["collection_position"]
		var radius: float = float(profile["collection_radius"])
		_check(_circle_overlaps_rect(center, radius, visible_rect), "%s collection area overlaps opaque art" % resource_type)
		_check(center.distance_to(visible_rect.get_center()) <= 0.01, "%s collection center follows visible center" % resource_type)
		_check(profile["highlight_position"].distance_to(center) <= 0.01, "%s highlight follows collection center" % resource_type)
		_check(profile["collection_effect_position"].distance_to(center) <= 0.01, "%s collection effect follows collection center" % resource_type)
		var placement: Vector2 = profile["placement_footprint"]
		var placement_rect := Rect2(Vector2(-placement.x * 0.5, -placement.y), placement)
		_check(placement_rect.intersects(visible_rect), "%s placement footprint overlaps visible base" % resource_type)
		_check(profile["physical_footprint"] == Vector2.ZERO, "%s remains non-blocking" % resource_type)


func _check_runtime_instances() -> void:
	for entry: Dictionary in entries:
		var root: Node2D = entry["root"]
		var profile: Dictionary = entry["profile"]
		if entry["is_resource"]:
			var resource_profile := RESOURCE_PROFILES.profile(entry["label"])
			var sprite_names := {"wood": "WoodArt", "stone": "StoneArt", "iron": "IronArt", "essence": "EssenceArt"}
			var sprite: Sprite2D = root.get_node(sprite_names[entry["label"]]) as Sprite2D
			var alignment := ASSETS.alignment_for_asset(str(resource_profile["asset"]), float(resource_profile["visual_scale"]))
			_check(sprite.position.is_equal_approx(alignment["sprite_position"]), "%s sprite and root share the profile coordinate system" % entry["label"])
			_check(sprite.scale.is_equal_approx(Vector2.ONE * float(resource_profile["visual_scale"])), "%s sprite uses profile scale" % entry["label"])
			var shape := root.get_node("CollisionShape2D") as CollisionShape2D
			_check(shape.position.is_equal_approx(resource_profile["collection_position"]), "%s collection shape uses profile center" % entry["label"])
			var cue := root.get_node("ProximityHighlight") as Node2D
			_check(cue.position.is_equal_approx(resource_profile["highlight_position"]), "%s highlight uses profile center" % entry["label"])
			_check_scaled_children_share_root(root, shape, cue, resource_profile["collection_position"])
		else:
			var alignment := ASSETS.alignment_for_asset(entry["label"], float(profile["visual_scale"]))
			var sprite: Node2D = root.get_node("AnimatedSprite") if str(profile["category"]) in ["tree", "bush"] else root.get_node("StaticSprite")
			_check(sprite.position.is_equal_approx(alignment["sprite_position"]), "%s sprite and root share the profile coordinate system" % entry["label"])
			_check(sprite.scale.is_equal_approx(Vector2.ONE * float(profile["visual_scale"])), "%s sprite uses profile scale" % entry["label"])
			var shape := root.get_node("GroundFootprint/CollisionShape2D") as CollisionShape2D
			_check((shape.shape as RectangleShape2D).size.is_equal_approx(profile["footprint_size"]), "%s uses profile physical footprint" % entry["label"])
			_check(shape.position.is_equal_approx(Vector2(0.0, -float(profile["footprint_size"].y) * 0.5)), "%s physical footprint is rooted at ground contact" % entry["label"])
			_check_scaled_children_share_root(root, shape, null, Vector2(0.0, -float(profile["footprint_size"].y) * 0.5))


func _check_scaled_children_share_root(root: Node2D, shape: CollisionShape2D, cue: Node2D, expected_shape_position: Vector2) -> void:
	var saved_scale := root.scale
	root.scale = Vector2.ONE * 1.25
	_check(shape.global_position.is_equal_approx(root.to_global(expected_shape_position)), "%s scaling preserves shape/root coordinates" % root.name)
	if is_instance_valid(cue):
		_check(cue.global_position.is_equal_approx(root.to_global(cue.position)), "%s scaling preserves highlight/root coordinates" % root.name)
	root.scale = saved_scale


func _circle_overlaps_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
	return closest.distance_squared_to(center) <= radius * radius


func _add_label(text_value: String, position: Vector2, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text_value
	label.position = position
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 20
	add_child(label)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		_fail(description)


func _fail(description: String) -> void:
	failures += 1
	print("FAIL: %s" % description)
