extends SceneTree

## Gameplay-zoom captures for the vegetation/resource pass.
##
## The four zone images use the normal camera and live placement.  The four
## interaction images place the player just inside each profile's proximity
## radius so the restrained focus cue can be inspected without collecting it.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const ZONE_OUTPUTS: Dictionary = {
	"village": "res://visual_comparison/vegetation_village_gameplay.png",
	"forest": "res://visual_comparison/vegetation_forest_gameplay.png",
	"mine": "res://visual_comparison/vegetation_mine_gameplay.png",
	"ruins": "res://visual_comparison/vegetation_ruins_gameplay.png",
}
const INTERACTION_OUTPUTS: Dictionary = {
	"wood": "res://visual_comparison/resource_interaction_wood.png",
	"stone": "res://visual_comparison/resource_interaction_stone.png",
	"iron": "res://visual_comparison/resource_interaction_iron.png",
	"essence": "res://visual_comparison/resource_interaction_essence.png",
}
const ZONE_POSITIONS: Dictionary = {
	"village": Vector2(320.0, 1190.0),
	"forest": Vector2(1040.0, 1080.0),
	"mine": Vector2(1930.0, 1120.0),
	"ruins": Vector2(1880.0, 630.0),
}

var failures: int = 0
var main: Node2D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	main = MAIN_SCENE.instantiate() as Node2D
	main.day_duration = 999.0
	main.night_duration = 999.0
	main.exploration_debug_seed = 11
	root.add_child(main)
	current_scene = main
	await _frames(4)
	paused = false
	main._choose_starting_weapon("bow")
	await _frames(5)
	main.player.set_physics_process(false)
	main.world_camera.position_smoothing_enabled = false
	for enemy: Node in main.get_node("DayEnemies").get_children():
		enemy.set_process(false)
		enemy.set_physics_process(false)

	for zone: String in ["village", "forest", "mine", "ruins"]:
		main.player.global_position = ZONE_POSITIONS[zone]
		await _settle()
		await _capture(ZONE_OUTPUTS[zone], zone)

	# Isolate the target pickup for the interaction-range evidence.  The actual
	# gameplay captures above retain every authored prop; these four images are
	# readability checks for the profile-specific silhouette and focus cue.
	main.world_visuals.decorations.hide()
	# The normal camera is intentionally clamped to the map.  Widen the limits
	# for these close-ups so a resource near a map edge cannot slide out of the
	# evidence frame while the player is positioned just inside its cue radius.
	main.world_camera.limit_left = -100000
	main.world_camera.limit_top = -100000
	main.world_camera.limit_right = 100000
	main.world_camera.limit_bottom = 100000
	for resource_type: String in ["wood", "stone", "iron", "essence"]:
		var resource: Node2D = _find_resource(resource_type)
		if not is_instance_valid(resource):
			failures += 1
			print("FAIL: missing %s interaction example" % resource_type)
			continue
		resource.show()
		for other_resource: Node in main.get_node("Resources").get_children():
			if other_resource != resource:
				other_resource.hide()
		for enemy: Node in main.get_node("DayEnemies").get_children():
			enemy.hide()
		main.player.global_position = resource.global_position + Vector2(-34.0, 0.0)
		await _settle()
		await _capture(INTERACTION_OUTPUTS[resource_type], "%s interaction range" % resource_type)

	main._cancel_pending_wave_work("vegetation/resource capture cleanup")
	main.queue_free()
	await _frames(3)
	current_scene = null
	print("Vegetation/resource capture: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _find_resource(resource_type: String) -> Node2D:
	var best: Node2D = null
	var best_clearance: float = -INF
	var world: GloamWorldVisuals = main.world_visuals
	for resource: Node in main.get_node("Resources").get_children():
		if str(resource.get("resource_type")) != resource_type:
			continue
		var candidate := resource as Node2D
		var clearance: float = INF
		for obstacle: Dictionary in world.get_placement_footprints():
			clearance = minf(clearance, candidate.global_position.distance_to((obstacle["rect"] as Rect2).get_center()))
		if clearance > best_clearance:
			best_clearance = clearance
			best = candidate
	return best


func _settle() -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw


func _capture(path: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image.get_width() != 1280 or image.get_height() != 720:
		failures += 1
		print("FAIL: %s capture dimensions are %s" % [label, str(image.get_size())])
		return
	var result: Error = image.save_png(path)
	if result != OK:
		failures += 1
		print("FAIL: could not save %s" % path)
	else:
		print("Captured %s: %s" % [label, path])


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame
