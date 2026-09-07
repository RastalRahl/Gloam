extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const RESOURCE_PROFILES := preload("res://scripts/resource_profiles.gd")
const DAY_LAYOUT := preload("res://scripts/day_exploration_layout.gd")

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node2D = MAIN_SCENE.instantiate() as Node2D
	main.exploration_debug_seed = 11
	root.add_child(main)
	current_scene = main
	await process_frame
	paused = false
	var layout_a: Array[Dictionary] = main.world_visuals.get_resource_layout(11, 1)
	var layout_b: Array[Dictionary] = main.world_visuals.get_resource_layout(12, 1)
	_check(layout_a.size() == 22, "day layout keeps all planned pickups")
	_check(_layout_positions(layout_a) != _layout_positions(layout_b), "different seeds produce different resource routes")

	var counts: Dictionary = {}
	for entry: Dictionary in layout_a:
		var zone: String = str(entry.get("zone", ""))
		var resource_type: String = str(entry.get("type", ""))
		counts[resource_type] = int(counts.get(resource_type, 0)) + 1
		var bounds: Rect2 = DAY_LAYOUT.ZONE_BOUNDS[zone]
		var position: Vector2 = entry["position"]
		_check(bounds.grow(-28.0).has_point(position), "%s pickup remains inside its zone" % resource_type)
		_check(
			position.distance_to(Vector2(260.0, 1300.0)) / 260.0 < 45.0,
			"%s pickup is reachable within the day budget" % resource_type
		)

	_check(int(counts.get("wood", 0)) == 8, "Forest remains primarily Wood")
	_check(int(counts.get("stone", 0)) == 5 and int(counts.get("iron", 0)) == 3, "Mine remains Stone and Iron")
	_check(int(counts.get("essence", 0)) == 6, "Ruins provide Essence pickups")
	_check(_layouts_avoid_cliff_faces(main.world_visuals, 1, 32), "seeded pickup variation stays off visible cliff faces")

	var mine_positions_a: Array[Vector2] = main.world_visuals.get_day_enemy_spawn_positions("mine", 11, 1, 5)
	var mine_positions_b: Array[Vector2] = main.world_visuals.get_day_enemy_spawn_positions("mine", 12, 1, 5)
	_check(mine_positions_a != mine_positions_b, "different seeds vary day enemy placement")
	_check(
		main.world_visuals.get_day_enemy_spawn_positions("ruins", 11, 1, 2).size() == 2,
		"Ruins keeps its lower-count high-risk encounter")

	var obstacle_rects: Array[Dictionary] = DAY_LAYOUT.get_obstacle_rects()
	_check(obstacle_rects.is_empty(), "all 12 coarse landmark obstacle rectangles are removed")

	main._choose_starting_weapon("bow")
	await process_frame

	_check(main.exploration_seed == 11, "debug exploration seed is applied")
	_check(main.get_node("Resources").get_child_count() == 22, "runtime spawns the complete varied pickup layout")
	_check(main.get_node("DayEnemies").get_child_count() == 8, "runtime keeps the planned day enemy groups")
	_check(main.get_node("DayObstacles").get_child_count() == 0, "runtime keeps temporary blockers separate and empty")
	_check(_count_resources(main, "essence") == 6, "runtime Essence nodes use the Ruins reward identity")
	_check(_count_resources_with_risk(main, 3) == 6, "deep Ruins rewards are visibly risk-tiered")
	_check(_count_resources_with_risk(main, 1) == 8, "Forest rewards use the lower-risk tier")

	var first_essence: GloamResourceNode = _first_resource(main, "essence")
	var essence_before: int = main.essence
	_check(is_instance_valid(first_essence), "an Essence pickup is interactable")
	if is_instance_valid(first_essence):
		_check(main.try_collect_resource("essence", first_essence.amount), "Essence pickup can be collected")
		_check(main.essence == essence_before + first_essence.amount, "Essence collection updates the resource total")

	_check(main.world_visuals.are_terrain_collisions_active(), "semantic terrain collision is active during exploration")

	main._start_night()
	main._cancel_pending_wave_work("exploration verification cleanup")
	await process_frame
	await physics_frame
	_check(main.get_node("DayObstacles").get_child_count() == 0, "night has no legacy day-only terrain substitutes")
	_check(main.world_visuals.are_terrain_collisions_active(), "permanent terrain collision remains active at night")

	main._start_day()
	await process_frame
	_check(main.world_visuals.are_terrain_collisions_active(), "terrain collision remains active after dawn")

	main.queue_free()
	await process_frame
	main = null
	current_scene = null
	await process_frame
	await create_timer(0.1).timeout
	print("Day exploration verification: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _layout_positions(layout: Array[Dictionary]) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for entry: Dictionary in layout:
		positions.append(entry["position"])
	return positions


func _count_resources(main: Node2D, resource_type: String) -> int:
	var count: int = 0
	for child: Node in main.get_node("Resources").get_children():
		if (child as GloamResourceNode).resource_type == resource_type:
			count += 1
	return count


func _count_resources_with_risk(main: Node2D, risk_tier: int) -> int:
	var count: int = 0
	for child: Node in main.get_node("Resources").get_children():
		if (child as GloamResourceNode).risk_tier == risk_tier:
			count += 1
	return count


func _first_resource(main: Node2D, resource_type: String) -> GloamResourceNode:
	for child: Node in main.get_node("Resources").get_children():
		var resource: GloamResourceNode = child as GloamResourceNode
		if resource.resource_type == resource_type:
			return resource
	return null


func _layouts_avoid_cliff_faces(world: GloamWorldVisuals, first_seed: int, last_seed: int) -> bool:
	for seed: int in range(first_seed, last_seed + 1):
		for day: int in range(1, 4):
			for entry: Dictionary in world.get_resource_layout(seed, day):
				var position: Vector2 = entry["position"]
				var resource_profile := RESOURCE_PROFILES.profile(str(entry["type"]))
				if not world.is_walkable_ground_anchor(position, resource_profile["placement_footprint"]):
					print("Unsafe authored marker seed %d day %d: %s at %s" % [seed, day, str(entry["type"]), str(position)])
					return false
	return true


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		print("FAIL: %s" % description)
