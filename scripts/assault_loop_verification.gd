extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const DAY_LAYOUT := preload("res://scripts/day_exploration_layout.gd")

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node2D = MAIN_SCENE.instantiate() as Node2D
	main.exploration_debug_seed = 71
	root.add_child(main)
	current_scene = main
	await process_frame
	paused = false
	main._choose_starting_weapon("sword")
	await process_frame

	_check(is_equal_approx(main.day_duration, 180.0), "normal day configuration is 180 seconds")
	_check(main.nights_to_survive == 10, "run configuration contains ten nights")
	_check(main.skip_to_night_button.visible and not main.skip_to_night_button.disabled, "Skip to Night is visible and enabled during a safe village day")

	main.player.global_position = Vector2(1780.0, 360.0)
	main._refresh_skip_to_night_control()
	_check(main.skip_to_night_button.visible and main.skip_to_night_button.disabled, "Skip to Night is disabled outside the village")
	_check(not main._on_skip_to_night_pressed() and main.current_phase == main.Phase.DAY, "outside skip attempt is rejected")

	main.player.global_position = Vector2(320.0, 1190.0)
	main.village_management_open = true
	main._refresh_skip_to_night_control()
	_check(main.skip_to_night_button.disabled and not main._on_skip_to_night_pressed(), "menu-open skip attempt is disabled and rejected")
	main.village_management_open = false
	main._refresh_skip_to_night_control()
	_check(not main._on_skip_to_night_pressed() and main.current_phase == main.Phase.DAY and main.skip_confirmation_time_left > 0.0, "first safe skip request asks for confirmation")
	_check(main._on_skip_to_night_pressed() and main.current_phase == main.Phase.NIGHT, "confirmed skip uses the normal night transition")
	_check(not main.skip_to_night_button.visible and main.phase_timer.is_stopped(), "Skip to Night disappears immediately and the day timer stops")

	main._start_day()
	main.player.global_position = Vector2(1780.0, 360.0)
	main._on_phase_timer_timeout()
	_check(main.current_phase == main.Phase.DAY and main.dusk_return_pending, "natural expiry outside enters dusk return instead of stranding the player")
	_check(main.return_panel.visible, "dusk return guidance remains visible after natural expiry")
	main.player.global_position = Vector2(320.0, 1190.0)
	await process_frame
	_check(main.current_phase == main.Phase.NIGHT and not main.dusk_return_pending, "natural transition completes after the player safely returns")

	for lane: String in ["north", "east"]:
		var candidates: Array[Node] = main.world_visuals.valid_night_spawn_markers(lane)
		_check(candidates.size() == 3, "%s lane selects all three valid authored edge markers" % lane)
		for marker: Node in candidates:
			var gate: Node2D = main.north_gate if lane == "north" else main.east_gate
			_check((marker as Node2D).global_position.distance_to(gate.global_position) > 500.0, "%s spawn marker remains at the outer map edge" % lane)

	_check(main._spawn_enemy_in_lane("north", "grunt"), "required hostile spawns through an authored north marker")
	await physics_frame
	var hostile: GloamEnemy = main.get_node("Enemies").get_child(0) as GloamEnemy
	_check(is_equal_approx(hostile.move_speed, 78.0 * 0.85), "ordinary night movement uses the 0.85 multiplier")
	_check(hostile.primary_gate == main.north_gate and hostile.approach_waypoints.size() >= 2, "north hostile owns the authored passage route and corresponding gate")
	_check(hostile._choose_target() == main.north_gate, "closed north gate is the lane hostile's mandatory target")
	main.north_gate.take_damage(main.north_gate.max_hp)
	await physics_frame
	_check(hostile._choose_target() == main.north_breach_marker, "breached gate retargets through the open passage without terrain targeting")

	main._cancel_pending_wave_work("assault verification cancellation")
	_check(not main.night_schedule_active and main.wave_director.pending_spawn_count == 0, "cancellation invalidates all pending scheduled work")
	main.queue_free()
	await process_frame
	current_scene = null
	await create_timer(0.1).timeout
	print("Assault-loop verification: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		print("FAIL: %s" % description)
