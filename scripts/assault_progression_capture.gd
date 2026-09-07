extends SceneTree

## Deterministic gameplay-scale evidence for early, middle, and late pressure.
## Enemies are created through the production lane spawner, then posed at
## distinct points on their own authored paths so density can be reviewed in a
## single frame without waiting through several real-time waves.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CAPTURES: Array[Dictionary] = [
	{"night": 1, "per_lane": 6, "path": "res://visual_comparison/assault_night_01_early.png"},
	{"night": 5, "per_lane": 12, "path": "res://visual_comparison/assault_night_05_mid.png"},
	{"night": 10, "per_lane": 20, "path": "res://visual_comparison/assault_night_10_late.png"},
]
const FAMILY_CYCLE: Array[String] = ["grunt", "runner", "ranged", "grunt", "runner", "brute"]

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
	for lane: String in ["north", "east"]:
		for index: int in range(per_lane):
			var family: String = "grunt" if int(spec["night"]) == 1 else FAMILY_CYCLE[index % FAMILY_CYCLE.size()]
			_check(main._spawn_enemy_in_lane(lane, family), "Night %d %s showcase hostile spawns" % [int(spec["night"]), lane])
			var enemy: GloamEnemy = main.get_node("Enemies").get_child(main.get_node("Enemies").get_child_count() - 1) as GloamEnemy
			_pose_on_route(enemy, index, per_lane, lane)

	main._on_wave_progress(2 if int(spec["night"]) == 1 else 4 if int(spec["night"]) == 5 else 7, main.wave_director.wave_plan.size(), "NORTH + EAST")
	main._on_night_hostile_count_changed(main.wave_director.required_alive_count(), main.wave_director.pending_spawn_count)
	await _frames(3)
	_check(main.get_node("Enemies").get_child_count() <= main.wave_director.active_enemy_cap, "Night %d staged density respects its active cap" % int(spec["night"]))
	_check(_all_hostiles_have_routes_and_targets(main), "Night %d staged hostiles retain routes and reachable targets" % int(spec["night"]))
	_check(_close_overlap_count(main) <= per_lane, "Night %d staged pressure avoids excessive close overlap" % int(spec["night"]))
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_check(image.get_size() == Vector2i(1280, 720), "Night %d capture uses gameplay scale" % int(spec["night"]))
	_check(image.save_png(str(spec["path"])) == OK, "Night %d capture is saved" % int(spec["night"]))
	print("Captured Night %d: %s (alive=%d cap=%d pending=%d close_pairs=%d)" % [int(spec["night"]), str(spec["path"]), main.wave_director.required_alive_count(), main.wave_director.active_enemy_cap, main.wave_director.pending_spawn_count, _close_overlap_count(main)])
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
	var offset: Vector2 = Vector2(float((index % 3) - 1) * 9.0, float((index % 2) * 2 - 1) * 7.0)
	if lane == "east":
		offset = Vector2(offset.y, offset.x)
	enemy.global_position = points[point_index] + offset
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


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: %s" % description)
