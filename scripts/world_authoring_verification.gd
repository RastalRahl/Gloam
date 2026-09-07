extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

var failures: int = 0
var main: Node2D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	main = MAIN_SCENE.instantiate() as Node2D
	main.day_duration = 999.0
	main.night_duration = 999.0
	main.exploration_debug_seed = 31
	root.add_child(main)
	current_scene = main
	await _physics_frames(3)
	paused = false
	main._choose_starting_weapon("sword")
	await _physics_frames(3)
	main.player.set_physics_process(false)

	var world: GloamWorldVisuals = main.world_visuals
	for path: String in [
		"Terrain", "Regions/Village", "Regions/Forest", "Regions/Mine", "Regions/Ruins",
		"Regions/Village/Gates", "Regions/Village/DefenseBuildSpots",
		"Regions/Village/VillageBuildSpots", "NightApproaches/SpawnMarkers",
		"NightApproaches/ApproachPaths",
	]:
		_check(world.has_node(path), "World scene authors %s" % path)

	_check(main.get_node("Enemies").get_child_count() == 0, "night monsters are not pre-placed")
	_check(_marker_count(world, "night_enemy", "north") == 3, "three editor-authored north night spawns exist")
	_check(_marker_count(world, "night_enemy", "east") == 3, "three editor-authored east night spawns exist")
	_check(world.get_node("NightApproaches/ApproachPaths").get_child_count() == 6, "each night spawn has an authored approach path")
	_check(_approach_paths_are_valid(world), "approach paths remain on walkable terrain and avoid permanent prop footprints")

	var north_passage: Node2D = world.get_passage("village_north_gate")
	var east_passage: Node2D = world.get_passage("village_east_gate")
	_check(is_instance_valid(north_passage) and north_passage.global_position == main.north_gate.global_position, "north gate is aligned to the authored northern passage")
	_check(is_instance_valid(east_passage) and east_passage.global_position.distance_to(main.east_gate.global_position) <= 12.0, "east gate is aligned within its authored eastern passage")
	_check(await _player_crosses(Vector2(256, 850), Vector2(256, 930)), "player can use the northern passage during day")
	_check(await _player_crosses(Vector2(560, 1184), Vector2(470, 1184)), "player can use the eastern passage during day")

	_check(not await _monster_crosses(Vector2(96, 850), Vector2(96, 930)), "monsters cannot cross the village cliff away from a passage")
	_check(not await _monster_crosses(Vector2(256, 850), Vector2(256, 930)), "intact north gate physically blocks monsters")
	main.north_gate.take_damage(main.north_gate.max_hp)
	await _physics_frames(2)
	_check(main.north_gate.is_breached and not main.north_gate.blocks_monsters(), "destroyed north gate disables its physical blocker")
	_check(await _monster_crosses(Vector2(256, 850), Vector2(256, 930)), "destroyed north gate opens the northern passage")

	_check(not await _monster_crosses(Vector2(560, 1184), Vector2(470, 1184)), "intact east gate physically blocks monsters")
	main.east_gate.take_damage(main.east_gate.max_hp)
	await _physics_frames(2)
	_check(main.east_gate.is_breached and not main.east_gate.blocks_monsters(), "destroyed east gate disables its physical blocker")
	_check(await _monster_crosses(Vector2(560, 1184), Vector2(470, 1184)), "destroyed east gate opens the eastern passage")

	main._start_night()
	main._cancel_pending_wave_work("world authoring verification")
	await _physics_frames(2)
	_check(world.are_terrain_collisions_active(), "authored cliffs remain active at night")
	_check(_approach_paths_are_valid(world), "night routes remain valid with permanent collision active")

	main.queue_free()
	await process_frame
	current_scene = null
	print("World authoring verification: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _marker_count(world: Node, kind: String, lane: String) -> int:
	var count: int = 0
	for marker: Node in world.get_tree().get_nodes_in_group("world_spawn_markers"):
		if world.is_ancestor_of(marker) and str(marker.get("marker_kind")) == kind and str(marker.get("lane_or_zone")) == lane:
			count += 1
	return count


func _approach_paths_are_valid(world: GloamWorldVisuals) -> bool:
	var props: Array[Dictionary] = world.get_placement_footprints()
	for path: Path2D in world.get_node("NightApproaches/ApproachPaths").get_children():
		var points: PackedVector2Array = world.get_approach_points(str(path.get_meta("route_id")))
		if points.size() < 2:
			return false
		for index: int in range(points.size() - 1):
			var point: Vector2 = points[index]
			if not world.is_walkable_ground_anchor(point, Vector2(18, 8)):
				print("Approach point leaves walkable ground: %s at %s" % [path.name, point])
				return false
			for prop: Dictionary in props:
				if (prop["rect"] as Rect2).grow(3.0).has_point(point):
					print("Approach point overlaps prop: %s at %s with %s" % [path.name, point, prop["id"]])
					return false
	return true


func _player_crosses(start: Vector2, target: Vector2) -> bool:
	main.player.global_position = start
	main.player.velocity = Vector2.ZERO
	await physics_frame
	return await _move_body(main.player, target)


func _monster_crosses(start: Vector2, target: Vector2) -> bool:
	var enemy: GloamEnemy = ENEMY_SCENE.instantiate() as GloamEnemy
	main.get_node("Enemies").add_child(enemy)
	await physics_frame
	enemy.set_physics_process(false)
	enemy.global_position = start
	enemy.velocity = Vector2.ZERO
	await physics_frame
	var crossed: bool = await _move_body(enemy, target)
	enemy.queue_free()
	await physics_frame
	return crossed


func _move_body(body: CharacterBody2D, target: Vector2) -> bool:
	for _frame: int in range(180):
		await physics_frame
		var delta: Vector2 = target - body.global_position
		if delta.length() <= 8.0:
			body.velocity = Vector2.ZERO
			return true
		body.velocity = delta.normalized() * 420.0
		body.move_and_slide()
	body.velocity = Vector2.ZERO
	return false


func _physics_frames(count: int) -> void:
	for _index: int in range(count):
		await physics_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		print("FAIL: %s" % description)
