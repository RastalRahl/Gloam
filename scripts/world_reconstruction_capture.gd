extends SceneTree

## Rendered world walkthrough used for Task 2 visual verification.
## Run with a windowed renderer (not --headless) so viewport images are valid.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const DAY_LAYOUT := preload("res://scripts/day_exploration_layout.gd")

const OUTPUTS: Dictionary = {
	"village": "res://visual_comparison/task2_village.png",
	"forest": "res://visual_comparison/task2_forest.png",
	"mine": "res://visual_comparison/task2_mine.png",
	"ruins": "res://visual_comparison/task2_ruins.png",
}

const FOLLOWUP_OUTPUTS: Dictionary = {
	"village": "res://visual_comparison/followup_village.png",
	"forest": "res://visual_comparison/followup_forest.png",
	"mine": "res://visual_comparison/followup_mine.png",
	"ruins": "res://visual_comparison/followup_ruins.png",
}

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var main: Node2D = MAIN_SCENE.instantiate() as Node2D
	main.day_duration = 999.0
	main.exploration_debug_seed = 11
	root.add_child(main)
	current_scene = main
	await process_frame
	paused = false
	main._choose_starting_weapon("bow")
	await process_frame

	main.player.set_physics_process(false)
	main.world_camera.position_smoothing_enabled = false
	_check(main.world_visuals.are_prop_collisions_active(), "walkthrough uses normal scenic prop collisions")

	main.player.global_position = Vector2(320.0, 1190.0)
	await _settle_camera()
	_check(DAY_LAYOUT.zone_for_position(main.player.global_position) == "village", "walkthrough begins inside the village compound")
	await _capture("village")

	main.player.hp = main.player.max_hp
	_check(await _walk_route(main, DAY_LAYOUT.PATHS["forest"], 760.0), "forest path is traversable")
	main.player.global_position = Vector2(1040.0, 1080.0)
	await _settle_camera()
	_check(DAY_LAYOUT.zone_for_position(main.player.global_position) == "forest", "walkthrough visits the forest")
	await _capture("forest")

	main.player.hp = main.player.max_hp
	main.player.global_position = DAY_LAYOUT.PATHS["forest"].back()
	_check(await _walk_route(main, _reversed(DAY_LAYOUT.PATHS["forest"]), 760.0), "forest return path is traversable")
	_check(await _walk_route(main, DAY_LAYOUT.PATHS["mine"], 760.0), "mine path is traversable")
	main.player.global_position = Vector2(1930.0, 1120.0)
	await _settle_camera()
	_check(DAY_LAYOUT.zone_for_position(main.player.global_position) == "mine", "walkthrough visits the mine")
	await _capture("mine")

	main.player.hp = main.player.max_hp
	main.player.global_position = DAY_LAYOUT.PATHS["mine"].back()
	_check(await _walk_route(main, _reversed(DAY_LAYOUT.PATHS["mine"]), 760.0), "mine return path is traversable")
	_check(await _walk_route(main, DAY_LAYOUT.PATHS["ruins"], 760.0), "ruins path is traversable")
	main.player.global_position = Vector2(1780.0, 360.0)
	await _settle_camera()
	_check(DAY_LAYOUT.zone_for_position(main.player.global_position) == "ruins", "walkthrough visits the ruins")
	await _capture("ruins")

	main.player.hp = main.player.max_hp
	main.night_presentation_controller.update_dusk_guidance(5.0)
	_check(main.return_panel.visible, "dusk guidance requests a return from the ruins")
	main.player.global_position = DAY_LAYOUT.PATHS["ruins"].back()
	var ruins_return: Array = DAY_LAYOUT.PATHS["ruins"]
	_check(await _walk_route(main, _reversed(ruins_return), 820.0), "ruins return path is traversable")
	_check(await _walk_to(main, Vector2(520.0, 1190.0), 820.0), "player can return through the east village gate")
	main.night_presentation_controller.update_dusk_guidance(5.0)
	_check(main._is_player_in_village(), "player returns to the village before night")
	_check(not main.return_panel.visible, "return guidance clears inside the village")

	main._start_night()
	main._cancel_pending_wave_work("world reconstruction capture cleanup")
	await process_frame
	_check(main.current_phase == main.Phase.NIGHT, "day transitions to night after the return")

	main.queue_free()
	await process_frame
	current_scene = null
	await process_frame
	await RenderingServer.frame_post_draw
	print("World reconstruction walkthrough: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _walk_route(main: Node2D, raw_points: Array, speed: float) -> bool:
	for point: Vector2 in raw_points:
		if not await _walk_to(main, point, speed):
			return false
	return true


func _walk_to(main: Node2D, target: Vector2, speed: float) -> bool:
	var frames: int = 0
	var previous_distance: float = INF
	var stalled_frames: int = 0
	while main.player.global_position.distance_to(target) > 12.0 and frames < 600:
		await physics_frame
		var delta: Vector2 = target - main.player.global_position
		main.player.velocity = delta.normalized() * speed
		main.player.move_and_slide()
		var distance: float = main.player.global_position.distance_to(target)
		if distance >= previous_distance - 0.2:
			stalled_frames += 1
		else:
			stalled_frames = 0
		previous_distance = distance
		frames += 1
		if stalled_frames > 45:
			main.player.velocity = Vector2.ZERO
			return false
	main.player.velocity = Vector2.ZERO
	return frames < 600


func _reversed(raw_points: Array) -> Array:
	var result: Array = raw_points.duplicate()
	result.reverse()
	return result


func _settle_camera() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw


func _capture(zone: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_check(image.get_width() == 1280 and image.get_height() == 720, "%s capture is 1280 x 720" % zone)
	var result: Error = image.save_png(OUTPUTS[zone])
	_check(result == OK, "%s screenshot saved" % zone)
	var followup_result: Error = image.save_png(FOLLOWUP_OUTPUTS[zone])
	_check(followup_result == OK, "%s follow-up screenshot saved" % zone)
	print("Captured %s: %s" % [zone, OUTPUTS[zone]])


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		print("FAIL: %s" % description)
