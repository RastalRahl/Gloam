extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node2D = MAIN_SCENE.instantiate() as Node2D
	root.add_child(main)
	current_scene = main
	await process_frame
	paused = false
	main._choose_starting_weapon("sword")
	await process_frame

	main.current_day = main.nights_to_survive
	main._start_night()
	var first_spawn: bool = main._spawn_grave_ox()
	var second_spawn: bool = main._spawn_grave_ox()
	var boss_nodes: int = 0
	for child: Node in main.get_node("Enemies").get_children():
		if child is GloamGraveOx:
			boss_nodes += 1

	_check(first_spawn, "final-night boss can spawn once")
	_check(not second_spawn, "duplicate boss spawn is rejected")
	_check(boss_nodes == 1 and main.final_boss_spawned and is_instance_valid(main.current_boss), "exactly one boss instance is active", "nodes=1 spawned=true active=true", "nodes=%d spawned=%s active=%s" % [boss_nodes, main.final_boss_spawned, is_instance_valid(main.current_boss)])

	var boss: GloamGraveOx = main.current_boss
	var north_spawn: Node2D = main.get_node("World/NightApproaches/SpawnMarkers/NorthBossSpawn") as Node2D
	var north_route: PackedVector2Array = main.world_visuals.get_approach_points("north_2")
	_check(boss.global_position == north_spawn.global_position, "boss uses the authored north-edge spawn marker")
	_check(boss.global_position.distance_to(main.north_gate.global_position) > 500.0, "boss does not spawn beside the village")
	_check(north_route.size() >= 2 and boss.approach_waypoints == north_route, "boss owns the complete authored north approach route")
	_check(boss._choose_target() == main.north_gate, "boss initially targets the closed north gate")
	var initial_route_index: int = boss.approach_index
	var initial_movement_target: Vector2 = boss._movement_target_for(main.north_gate)
	_check(initial_route_index == 0 and initial_movement_target.y > boss.global_position.y, "boss begins moving into the north approach")

	main.north_gate.take_damage(main.north_gate.max_hp)
	boss.global_position = main.north_gate.global_position
	_check(boss._choose_target() == main.north_breach_marker, "breached north gate sends the boss through the passage")
	boss.global_position = main.north_breach_marker.global_position
	_check(boss._choose_target() != main.north_gate, "boss clears the north gate route after reaching the passage")
	main._try_complete_victory()
	_check(main.current_phase != main.Phase.VICTORY, "final-night victory remains closed before the boss is killed")
	boss.take_damage(boss.max_hp)
	await process_frame
	_check(main.final_boss_defeated and not main.final_night_survival_complete, "boss kill is recorded without bypassing final-night survival")
	main.final_night_survival_complete = true
	main._try_complete_victory()
	_check(main.current_phase == main.Phase.VICTORY, "final-night victory opens after boss kill and survival completion")
	main._cancel_pending_wave_work("boss spawn verification cleanup")

	var audio_hooks: GloamAudioHooks = main.get_node_or_null("AudioHooks") as GloamAudioHooks
	if is_instance_valid(audio_hooks):
		audio_hooks.free()
	main.queue_free()
	await process_frame
	# Boss spawning emits its critical UI tone; allow that playback reference to
	# release before the smoke process exits. This is teardown-only.
	await create_timer(0.25, true).timeout
	print("Boss spawn verification: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, description: String, expected: Variant = null, actual: Variant = null) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		print("FAIL: %s | expected=%s actual=%s" % [description, str(expected), str(actual)])
