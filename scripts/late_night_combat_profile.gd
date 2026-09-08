extends SceneTree

## Repeatable late-night micro-profile. This is diagnostic rather than a fixed
## performance assertion because absolute timings vary by renderer and machine.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const SAMPLE_ITERATIONS: int = 400
const FAMILY_CYCLE: Array[String] = ["brute", "runner", "ranged", "grunt"]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node2D = MAIN_SCENE.instantiate() as Node2D
	main.checkpoint_enabled = false
	main.exploration_debug_seed = 1317
	main.final_boss_spawn_delay = 999.0
	root.add_child(main)
	current_scene = main
	await _frames(4)
	paused = false
	main._choose_starting_weapon("bow")
	await _frames(3)
	main.current_day = 10
	main._start_night()
	await _frames(2)

	var cap: int = main.wave_director.active_enemy_cap
	for index: int in range(cap):
		var lane: String = "north" if index % 2 == 0 else "east"
		main._spawn_enemy_in_lane(lane, FAMILY_CYCLE[index % FAMILY_CYCLE.size()])
	var enemies: Array[Node] = main.get_node("Enemies").get_children()
	for index: int in range(enemies.size()):
		var enemy := enemies[index] as GloamEnemy
		var lane_sign: float = -1.0 if enemy.primary_gate == main.north_gate else 1.0
		enemy.global_position = Vector2(760.0 + float(index % 9) * 42.0, 890.0 + lane_sign * 42.0 + float(index / 9) * 24.0)
		enemy.set_process(false)
		enemy.set_physics_process(false)
	main.north_gate.is_breached = true
	main.east_gate.is_breached = true
	main.north_breach_marker.global_position = main.north_gate.global_position
	main.east_breach_marker.global_position = main.east_gate.global_position
	_add_target_fixtures(main, "soldiers", 8, Vector2(960.0, 940.0))
	_add_target_fixtures(main, "village_buildings", 5, Vector2(1040.0, 980.0))
	_add_target_fixtures(main, "defenses", 7, Vector2(1120.0, 900.0))
	await _frames(2)

	var root_item_count: int = 0
	for root_name: String in main.DEPTH_SORT_ROOTS:
		var sort_root: Node = main.get_node_or_null(root_name)
		if is_instance_valid(sort_root):
			root_item_count += sort_root.get_child_count()
	print("LATE NIGHT COMBAT PROFILE cap=%d depth_items=%d enemies=%d" % [cap, root_item_count, enemies.size()])
	_profile("depth_sort", func() -> void: main._update_world_depth_sort())
	_profile("three_group_snapshots", func() -> void:
		main.get_tree().get_nodes_in_group("soldiers")
		main.get_tree().get_nodes_in_group("village_buildings")
		main.get_tree().get_nodes_in_group("defenses")
	)
	_profile("all_enemy_target_scans", func() -> void:
		for enemy: GloamEnemy in enemies:
			enemy._choose_target()
	)
	_profile("offscreen_lane_overlay", func() -> void: main.night_presentation_controller.update_night_readability())
	_profile("readability_60fps_amortized", func() -> void: main.night_presentation_controller._process(1.0 / 60.0))

	main._cancel_pending_wave_work("late-night profile complete")
	main.queue_free()
	await _frames(4)
	current_scene = null
	quit(0)


func _profile(label: String, callback: Callable) -> void:
	for _warmup: int in range(20):
		callback.call()
	var started_usec: int = Time.get_ticks_usec()
	for _sample: int in range(SAMPLE_ITERATIONS):
		callback.call()
	var elapsed_usec: int = Time.get_ticks_usec() - started_usec
	print("PROFILE %s iterations=%d total_usec=%d avg_usec=%.3f" % [label, SAMPLE_ITERATIONS, elapsed_usec, float(elapsed_usec) / float(SAMPLE_ITERATIONS)])


func _add_target_fixtures(main: Node2D, group_name: String, count: int, origin: Vector2) -> void:
	for index: int in range(count):
		var fixture := Node2D.new()
		fixture.name = "%sProfileFixture%d" % [group_name.capitalize().replace(" ", ""), index]
		fixture.global_position = origin + Vector2(float(index % 4) * 24.0, float(index / 4) * 24.0)
		fixture.add_to_group(group_name)
		main.add_child(fixture)


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame
