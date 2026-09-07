extends SceneTree

## End-to-end verification of the semantic elevation contract using the normal
## player collision mask, live props, day/night transitions, and authored paths.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const DAY_LAYOUT := preload("res://scripts/day_exploration_layout.gd")
const VISUALS := preload("res://scripts/visual_constants.gd")
const CELL_SIZE: int = 64

const ROUTE_ORDER: Array[String] = ["forest", "mine", "ruins"]
const VILLAGE_START := Vector2(320.0, 1190.0)
const CLIFF_PROBES: Array[Dictionary] = [
	{"region": "village_meadow", "cell": Vector2i(6, 14), "direction": Vector2i.UP},
	{"region": "forest_wayledge", "cell": Vector2i(10, 12), "direction": Vector2i.DOWN},
	{"region": "mine_upper_shelf", "cell": Vector2i(29, 12), "direction": Vector2i.DOWN},
	{"region": "mine_lower_shelf", "cell": Vector2i(30, 17), "direction": Vector2i.UP},
	{"region": "ruins_west_terrace", "cell": Vector2i(23, 6), "direction": Vector2i.DOWN},
	{"region": "ruins_east_terrace", "cell": Vector2i(30, 3), "direction": Vector2i.LEFT},
]

var failures: int = 0
var main: Node2D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	main = MAIN_SCENE.instantiate() as Node2D
	main.exploration_debug_seed = 11
	main.day_duration = 999.0
	main.night_duration = 999.0
	root.add_child(main)
	current_scene = main
	await process_frame
	paused = false
	main._choose_starting_weapon("bow")
	await _physics_frames(3)
	main.player.set_physics_process(false)

	_check(main.world_visuals.get_terrain_regions().size() == 6, "all six raised areas use the terrain contract")
	_check(main.world_visuals.get_terrain_passages().size() == 11, "all eleven gates/stairs/passages are authored")
	_check(main.world_visuals.are_terrain_collisions_active(), "permanent terrain collision is active during day")
	_check(main.world_visuals.are_prop_collisions_active(), "scenic prop footprints use their persistent layer")
	_check(main.get_node("DayObstacles").get_child_count() == 0, "no broad day-only landmark rectangles remain")
	_check(main.world_visuals.cliff_faces.get_used_cells().size() > 0, "cliff face tiles are authored in the terrain scene")

	for passage: Node in main.world_visuals.get_terrain_passages():
		var crossed: bool = await _cross_boundary(passage, false)
		_check(crossed, "%s crosses its authored %s" % [passage.get("passage_id"), passage.get("passage_kind")])

	for probe: Dictionary in CLIFF_PROBES:
		var crossed: bool = await _cross_boundary(probe, true)
		_check(not crossed, "%s blocks crossing away from a passage" % probe["region"])

	_check(await _walk_all_routes("day"), "village, forest, mine, and ruins routes work during day")

	main._start_night()
	main._cancel_pending_wave_work("terrain verification")
	await _physics_frames(3)
	_check(main.world_visuals.are_terrain_collisions_active(), "terrain collision remains active at night")
	_check(main.world_visuals.are_prop_collisions_active(), "prop collision remains active at night")
	_check(main.get_node("DayObstacles").get_child_count() == 0, "temporary blocker root remains independent at night")
	_check(await _walk_all_routes("night"), "all authored regional routes work at night")

	for probe: Dictionary in CLIFF_PROBES:
		var crossed: bool = await _cross_boundary(probe, true)
		_check(not crossed, "%s still blocks crossing at night" % probe["region"])

	var overlay := main.get_node("CollisionDebugOverlay") as GloamCollisionDebugOverlay
	_check(is_instance_valid(overlay) and not overlay.is_enabled(), "collision overlay starts disabled")
	_check(InputMap.has_action(&"toggle_collision_debug"), "F7 collision debug action is registered")
	var toggle_event := InputEventAction.new()
	toggle_event.action = &"toggle_collision_debug"
	toggle_event.pressed = true
	overlay._unhandled_input(toggle_event)
	_check(overlay.is_enabled(), "collision overlay toggles through its input action")
	overlay._unhandled_input(toggle_event)
	_check(not overlay.is_enabled(), "collision overlay toggles off again")

	main.queue_free()
	await process_frame
	current_scene = null
	print("Terrain collision verification: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _walk_all_routes(phase_name: String) -> bool:
	for route_name: String in ROUTE_ORDER:
		main.player.global_position = VILLAGE_START
		main.player.velocity = Vector2.ZERO
		await physics_frame
		var points: Array = DAY_LAYOUT.PATHS[route_name]
		if not await _walk_route(points):
			print("Route failed: %s %s outbound at %s" % [phase_name, route_name, main.player.global_position])
			return false
		if DAY_LAYOUT.zone_for_position(main.player.global_position) != route_name:
			return false
		if not await _walk_route(_reversed(points)):
			print("Route failed: %s %s return at %s" % [phase_name, route_name, main.player.global_position])
			return false
	return true


func _walk_route(points: Array) -> bool:
	for point: Vector2 in points:
		if not await _move_to(point, 600):
			return false
	return true


func _cross_boundary(entry: Variant, is_probe: bool) -> bool:
	var direction: Vector2 = Vector2(entry["direction"]) if is_probe else Vector2((entry as Node).get("direction"))
	var center: Vector2
	if is_probe:
		var cell: Vector2i = entry["cell"]
		center = Vector2(cell * CELL_SIZE) + Vector2.ONE * (CELL_SIZE * 0.5)
		center += direction * (CELL_SIZE * 0.5)
	else:
		center = (entry as Node2D).global_position
	main.player.global_position = center + Vector2(direction) * 48.0
	main.player.velocity = Vector2.ZERO
	await physics_frame
	var crossed: bool = await _move_to(center - Vector2(direction) * 48.0, 180)
	if not crossed and not is_probe:
		print("Passage failed: %s center=%s final=%s" % [(entry as Node).get("passage_id"), center, main.player.global_position])
		_print_slide_collisions()
	return crossed


func _move_to(target: Vector2, frame_limit: int) -> bool:
	var previous_distance: float = INF
	var stalled: int = 0
	for _frame: int in range(frame_limit):
		await physics_frame
		var delta: Vector2 = target - main.player.global_position
		if delta.length() <= 10.0:
			main.player.velocity = Vector2.ZERO
			return true
		main.player.velocity = delta.normalized() * 760.0
		main.player.move_and_slide()
		var distance: float = main.player.global_position.distance_to(target)
		stalled = stalled + 1 if distance >= previous_distance - 0.2 else 0
		previous_distance = distance
		if stalled > 35:
			main.player.velocity = Vector2.ZERO
			return false
	main.player.velocity = Vector2.ZERO
	return false


func _print_slide_collisions() -> void:
	for collision_index: int in range(main.player.get_slide_collision_count()):
		var collision: KinematicCollision2D = main.player.get_slide_collision(collision_index)
		var collider: Object = collision.get_collider()
		print("  collision=%s path=%s" % [collider, collider.get_path() if collider is Node else "<non-node>"])


func _physics_frames(count: int) -> void:
	for _index: int in range(count):
		await physics_frame


func _reversed(points: Array) -> Array:
	var result: Array = points.duplicate()
	result.reverse()
	return result


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		print("FAIL: %s" % description)
