extends SceneTree

## Normal-runtime route verification. This probe keeps authored terrain and
## prop collision enabled, walks from the village through each route, and
## returns through the same corridor before reporting success.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const DAY_LAYOUT := preload("res://scripts/day_exploration_layout.gd")

const ROUTE_ORDER: Array[String] = ["forest", "mine", "ruins"]
const VILLAGE_START := Vector2(320.0, 1190.0)

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node2D = MAIN_SCENE.instantiate() as Node2D
	main.exploration_debug_seed = 11
	main.day_duration = 999.0
	main.night_duration = 999.0
	root.add_child(main)
	current_scene = main
	await process_frame
	paused = false
	main._choose_starting_weapon("bow")
	await process_frame
	main.player.set_physics_process(false)

	_check(is_instance_valid(main.player), "route probe has a live player")
	_check(main.world_visuals.are_prop_collisions_active(), "normal scenic prop collisions remain enabled")
	_check(main.world_visuals.are_terrain_collisions_active(), "permanent terrain collision remains enabled")
	_check(main.get_node("DayObstacles").get_child_count() == 0, "legacy day obstacle rectangles are absent")

	for route_name: String in ROUTE_ORDER:
		var points: Array = DAY_LAYOUT.PATHS.get(route_name, [])
		_check(not points.is_empty(), "%s route has authored waypoints" % route_name)
		if points.is_empty():
			continue

		# Every route starts from the same courtyard position.  In particular,
		# Ruins must pass the north gate rather than assuming a deep-zone start.
		main.player.global_position = VILLAGE_START
		main.player.velocity = Vector2.ZERO
		var outbound_ok: bool = await _walk_route(main, points, route_name)
		_check(outbound_ok, "%s route reaches its zone with collisions enabled" % route_name)
		_check(
			DAY_LAYOUT.zone_for_position(main.player.global_position) == route_name,
			"%s route ends inside its intended zone" % route_name
		)

		var return_ok: bool = await _walk_route(main, _reversed(points), "%s return" % route_name)
		_check(return_ok, "%s route returns to the village corridor" % route_name)
		_check(
			main.player.global_position.distance_to(VILLAGE_START) <= 24.0,
			"%s return reaches the village start" % route_name
		)

	main._cancel_pending_wave_work("route probe cleanup")
	main.queue_free()
	await process_frame
	current_scene = null
	print("Task3 route probe: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _walk_route(main: Node2D, raw_points: Array, route_name: String) -> bool:
	for point: Vector2 in raw_points:
		var ok: bool = await _walk_to(main, point)
		print("route=%s target=%s ok=%s position=%s" % [route_name, str(point), str(ok), str(main.player.global_position)])
		if not ok:
			return false
	return true


func _walk_to(main: Node2D, target: Vector2) -> bool:
	var previous_distance: float = INF
	var stalled: int = 0
	for _frame: int in range(600):
		await physics_frame
		if not is_instance_valid(main.player):
			return false
		var delta: Vector2 = target - main.player.global_position
		main.player.velocity = delta.normalized() * 760.0
		main.player.move_and_slide()
		var distance: float = main.player.global_position.distance_to(target)
		if distance >= previous_distance - 0.2:
			stalled += 1
		else:
			stalled = 0
		previous_distance = distance
		if distance <= 12.0:
			main.player.velocity = Vector2.ZERO
			return true
		if stalled > 45:
			for collision_index: int in range(main.player.get_slide_collision_count()):
				var collision: KinematicCollision2D = main.player.get_slide_collision(collision_index)
				var collider: Object = collision.get_collider()
				print("stalled collision=%s path=%s" % [str(collider), str(collider.get_path() if collider is Node else "<non-node>")])
			main.player.velocity = Vector2.ZERO
			return false
	main.player.velocity = Vector2.ZERO
	return false


func _reversed(raw_points: Array) -> Array:
	var result: Array = raw_points.duplicate()
	result.reverse()
	return result


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		print("FAIL: %s" % description)
