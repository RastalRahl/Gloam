extends SceneTree

## Final 1280 x 720 visual capture and live phase/combat verification.
## Uses the normal main scene, normal prop collisions, and a timer-driven
## day-to-night transition. The only frozen actors are the posed night combat
## participants immediately before the final night capture.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const DAY_LAYOUT := preload("res://scripts/day_exploration_layout.gd")

const DAY_CAPTURES: Dictionary = {
	"village": {"position": Vector2(320.0, 1190.0), "path": "res://visual_comparison/final_village_day.png"},
	"forest": {"position": Vector2(1040.0, 1080.0), "path": "res://visual_comparison/final_forest_day.png"},
	"mine": {"position": Vector2(1930.0, 1120.0), "path": "res://visual_comparison/final_mine_day.png"},
	"ruins": {"position": Vector2(1780.0, 360.0), "path": "res://visual_comparison/final_ruins_day.png"},
}

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var main: Node2D = MAIN_SCENE.instantiate() as Node2D
	main.day_duration = 999.0
	main.night_duration = 30.0
	main.final_boss_spawn_delay = 15.0
	main.exploration_debug_seed = 11
	root.add_child(main)
	current_scene = main
	await _frames(3)
	paused = false
	main._choose_starting_weapon("sword")
	await _frames(4)

	main.player.set_physics_process(false)
	main.world_camera.position_smoothing_enabled = false
	_check(main.world_visuals.are_prop_collisions_active(), "normal scenic prop collisions are active")
	_check(main.world_visuals.are_terrain_collisions_active(), "permanent terrain collision is active")
	_check(main.get_node("DayObstacles").get_child_count() == 0, "legacy day obstacle rectangles are absent")
	_check(_hud_chrome_ignores_world_input(main), "HUD chrome ignores gameplay input outside visible controls")

	for zone: String in ["village", "forest", "mine", "ruins"]:
		var capture: Dictionary = DAY_CAPTURES[zone]
		main.player.global_position = capture["position"]
		await _settle_camera()
		_check(DAY_LAYOUT.zone_for_position(main.player.global_position) == zone, "%s capture uses its gameplay zone" % zone)
		await _capture(capture["path"], zone)

	# Return to the authored courtyard, then let the real phase timer complete
	# the transition rather than calling _start_night directly.
	main.player.global_position = Vector2(320.0, 1190.0)
	await _settle_camera()
	main.phase_timer.start(0.65)
	for _frame: int in range(180):
		if main.current_phase == main.Phase.NIGHT:
			break
		await process_frame
	_check(main.current_phase == main.Phase.NIGHT, "phase timer completes a day-to-night transition")
	_check(main.world_visuals.are_terrain_collisions_active(), "night keeps terrain collision active")

	# Stop only the asynchronous remainder after the live wave warning has begun;
	# pose two normal enemies for a deterministic representative melee exchange.
	main._cancel_pending_wave_work("final visual verification poses representative combat")
	await create_timer(1.9).timeout
	main.player.global_position = Vector2(420.0, 1230.0)
	_check(main._spawn_enemy_in_lane("north"), "representative night enemy spawns through the normal lane path")
	_check(main._spawn_enemy_in_lane("east"), "second representative night enemy spawns through the normal lane path")
	await _frames(3)
	var enemies: Array[Node] = main.get_node("Enemies").get_children()
	_check(enemies.size() >= 2, "representative combat has live enemies")
	if enemies.size() >= 2:
		var target: Node2D = enemies[enemies.size() - 2] as Node2D
		var flank: Node2D = enemies[enemies.size() - 1] as Node2D
		target.global_position = main.player.global_position + Vector2(54.0, 0.0)
		flank.global_position = main.player.global_position + Vector2(118.0, 42.0)
		target.set_physics_process(false)
		flank.set_physics_process(false)
		await physics_frame
		var hp_before: int = int(target.get("hp"))
		main.player._perform_melee_attack(Vector2.RIGHT)
		main.player._play_attack_visual(Vector2.RIGHT)
		await _frames(2)
		_check(int(target.get("hp")) < hp_before, "representative melee combat deals damage")

	await _settle_camera()
	await _capture("res://visual_comparison/final_village_night.png", "village night")

	main._cancel_pending_wave_work("final visual verification cleanup")
	main.queue_free()
	await process_frame
	current_scene = null
	print("Final visual verification: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _hud_chrome_ignores_world_input(main: Node2D) -> bool:
	var passive_paths: Array[NodePath] = [
		NodePath("UI/StatsPanel"),
		NodePath("UI/ResourcePanel"),
		NodePath("UI/PopulationPanel"),
		NodePath("UI/BuildingsPanel"),
		NodePath("UI/PhasePanel"),
		NodePath("UI/AudioSettingsMenu"),
	]
	for path: NodePath in passive_paths:
		var control: Control = main.get_node_or_null(path) as Control
		if control == null or control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return false
	return true


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame


func _settle_camera() -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw


func _capture(path: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_check(image.get_width() == 1280 and image.get_height() == 720, "%s capture is 1280 x 720" % label)
	var result: Error = image.save_png(path)
	_check(result == OK, "%s screenshot saved" % label)
	print("Captured %s: %s" % [label, path])


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		print("FAIL: %s" % description)
