extends SceneTree

## Deterministic gameplay-scale evidence for early, middle, and late pressure.
## Enemies are created through the production lane spawner, then posed at
## distinct points on their own authored paths so density can be reviewed in a
## single frame without waiting through several real-time waves.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const NIGHT_WAVE_SCHEDULE := preload("res://scripts/night_wave_schedule.gd")
const CAPTURES: Array[Dictionary] = [
	{"night": 1, "per_lane": 6, "north_wave": 2, "east_wave": 2, "display_wave": 3, "max_close_pairs": 0, "path": "res://visual_comparison/assault_night_01_early.png"},
	{"night": 6, "per_lane": 13, "north_wave": 0, "east_wave": 1, "display_wave": 2, "max_close_pairs": 8, "path": "res://visual_comparison/assault_night_06_mid.png"},
	{"night": 10, "per_lane": 18, "north_wave": 5, "east_wave": 5, "display_wave": 6, "max_close_pairs": 6, "path": "res://visual_comparison/assault_night_10_late.png"},
]

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for spec: Dictionary in CAPTURES:
		await _capture_night(spec)
	print("Assault progression captures: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _capture_night(spec: Dictionary) -> void:
	var main: Node2D = MAIN_SCENE.instantiate() as Node2D
	main.exploration_debug_seed = 1307 + int(spec["night"])
	main.final_boss_spawn_delay = 999.0
	root.add_child(main)
	current_scene = main
	await _frames(4)
	paused = false
	main._choose_starting_weapon("bow")
	await _frames(3)
	main.current_day = int(spec["night"])
	main.player.global_position = Vector2(390.0, 1080.0)
	main.player.set_physics_process(false)
	main._start_night()
	await _frames(2)

	var per_lane: int = int(spec["per_lane"])
	var plan: Array[Dictionary] = NIGHT_WAVE_SCHEDULE.for_night(int(spec["night"]), 15.0)
	for lane: String in ["north", "east"]:
		var wave_index: int = int(spec["north_wave"] if lane == "north" else spec["east_wave"])
		var wave: Dictionary = plan[wave_index]
		for index: int in range(per_lane):
			var entry: Dictionary = NIGHT_WAVE_SCHEDULE.spawn_entry(wave, index % int(wave["count"]))
			_check(main._spawn_enemy_in_lane(lane, str(entry["family"]), entry["behavior"]), "Night %d %s showcase hostile spawns" % [int(spec["night"]), lane])
			var enemy: GloamEnemy = main.get_node("Enemies").get_child(main.get_node("Enemies").get_child_count() - 1) as GloamEnemy
			_pose_on_route(enemy, index, per_lane, lane)

	var display_wave_index: int = int(spec["display_wave"])
	var warning: String = str(plan[mini(display_wave_index - 1, plan.size() - 1)].get("warning", "BOTH GATES UNDER ATTACK"))
	var separator_index: int = warning.find("  •")
	if separator_index >= 0:
		warning = "BOTH GATES" + warning.substr(separator_index)
	main._on_wave_warning(display_wave_index, main.wave_director.wave_plan.size(), "NORTH + EAST", warning, Vector2.ZERO)
	_check(_overlay_has_both_lanes(main), "Night %d split warning communicates both lanes" % int(spec["night"]))
	main._on_wave_progress(display_wave_index, main.wave_director.wave_plan.size(), "NORTH + EAST")
	main._on_night_hostile_count_changed(main.wave_director.required_alive_count(), main.wave_director.pending_spawn_count)
	main.night_presentation_controller.update_night_readability()
	await _frames(3)
	var legacy_close_pairs: int = _legacy_close_overlap_count(main, per_lane)
	var close_pairs: int = _close_overlap_count(main)
	_check(main.get_node("Enemies").get_child_count() <= main.wave_director.active_enemy_cap, "Night %d staged density respects its active cap" % int(spec["night"]))
	_check(_all_hostiles_have_routes_and_targets(main), "Night %d staged hostiles retain routes and reachable targets" % int(spec["night"]))
	_check(close_pairs <= int(spec["max_close_pairs"]), "Night %d staged pressure stays within its measured close-overlap budget" % int(spec["night"]))
	_check(close_pairs <= legacy_close_pairs, "Night %d deterministic formations do not increase close sprite pairs" % int(spec["night"]))
	if int(spec["night"]) >= 6:
		_check(_faded_foliage_count(main) > 0, "Night %d fades foreground foliage that covers a hostile" % int(spec["night"]))
		_check(_large_hostiles_have_persistent_health(main), "Night %d keeps large-hostile health visible" % int(spec["night"]))
		_check(_active_overlay_has_priority(main), "Night %d off-screen lane card reports count and priority" % int(spec["night"]))
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_check(image.get_size() == Vector2i(1280, 720), "Night %d capture uses gameplay scale" % int(spec["night"]))
	_check(image.save_png(str(spec["path"])) == OK, "Night %d capture is saved" % int(spec["night"]))
	print("Captured Night %d: %s (alive=%d cap=%d pending=%d close_pairs=%d legacy_close_pairs=%d)" % [int(spec["night"]), str(spec["path"]), main.wave_director.required_alive_count(), main.wave_director.active_enemy_cap, main.wave_director.pending_spawn_count, close_pairs, legacy_close_pairs])
	main._cancel_pending_wave_work("progression capture complete")
	main.queue_free()
	await _frames(3)
	current_scene = null


func _pose_on_route(enemy: GloamEnemy, index: int, count: int, lane: String) -> void:
	var points: PackedVector2Array = enemy.approach_waypoints
	if points.is_empty():
		return
	var progress: float = 0.28 + 0.64 * (float(index) / float(maxi(1, count - 1)))
	var point_index: int = clampi(int(round(progress * float(points.size() - 1))), 0, points.size() - 1)
	enemy.global_position = enemy.route_position_with_formation(point_index)
	enemy.approach_index = mini(point_index + 1, points.size())
	enemy.velocity = Vector2.ZERO
	enemy.set_process(false)
	enemy.set_physics_process(false)


func _all_hostiles_have_routes_and_targets(main: Node2D) -> bool:
	for node: Node in main.get_node("Enemies").get_children():
		if node is GloamEnemy:
			var enemy := node as GloamEnemy
			if enemy.approach_waypoints.size() < 2 or not is_instance_valid(enemy._choose_target()):
				return false
		elif node is GloamGraveOx:
			var boss := node as GloamGraveOx
			if boss.approach_waypoints.size() < 2 or not is_instance_valid(boss._choose_target()):
				return false
	return true


func _close_overlap_count(main: Node2D) -> int:
	var units: Array[Node] = main.get_node("Enemies").get_children()
	var count: int = 0
	for first_index: int in range(units.size()):
		for second_index: int in range(first_index + 1, units.size()):
			if (units[first_index] as Node2D).global_position.distance_to((units[second_index] as Node2D).global_position) < 22.0:
				count += 1
	return count


func _legacy_close_overlap_count(main: Node2D, per_lane: int) -> int:
	# Reconstructs the previous capture placement at the same enemy count, routes,
	# and progress points so formation readability has an apples-to-apples metric.
	var legacy_positions: Array[Vector2] = []
	var enemies: Array[Node] = main.get_node("Enemies").get_children()
	for enemy_index: int in range(enemies.size()):
		var enemy: GloamEnemy = enemies[enemy_index] as GloamEnemy
		var lane_index: int = enemy_index % per_lane
		var points: PackedVector2Array = enemy.approach_waypoints
		var progress: float = 0.28 + 0.64 * (float(lane_index) / float(maxi(1, per_lane - 1)))
		var point_index: int = clampi(int(round(progress * float(points.size() - 1))), 0, points.size() - 1)
		var offset: Vector2 = Vector2(float((lane_index % 3) - 1) * 9.0, float((lane_index % 2) * 2 - 1) * 7.0)
		if enemy_index >= per_lane:
			offset = Vector2(offset.y, offset.x)
		legacy_positions.append(points[point_index] + offset)
	var count: int = 0
	for first: int in range(legacy_positions.size()):
		for second: int in range(first + 1, legacy_positions.size()):
			if legacy_positions[first].distance_to(legacy_positions[second]) < 22.0:
				count += 1
	return count


func _overlay_has_both_lanes(main: Node2D) -> bool:
	var lanes: Array[String] = []
	for threat: Dictionary in main.night_threat_overlay.threats:
		lanes.append(str(threat.get("lane", "")))
	return lanes.has("NORTH") and lanes.has("EAST")


func _active_overlay_has_priority(main: Node2D) -> bool:
	for threat: Dictionary in main.night_threat_overlay.threats:
		if int(threat.get("count", 0)) > 0 and not str(threat.get("priority", "")).is_empty():
			return true
	return false


func _faded_foliage_count(main: Node2D) -> int:
	return main.night_presentation_controller.faded_combat_foliage.size()


func _large_hostiles_have_persistent_health(main: Node2D) -> bool:
	var found_large: bool = false
	for node: Node in main.get_node("Enemies").get_children():
		if node is GloamEnemy and (node as GloamEnemy).visual_profile == "troll":
			found_large = true
			if not (node as GloamEnemy).health_bar_bg.visible:
				return false
	return found_large


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: %s" % description)
