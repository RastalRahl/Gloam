extends SceneTree

## Accelerated production-spawner soak. It traverses every authored wave and
## spawn entry, holds batches at the real active cap for several frames, then
## retires them through the required-hostile ledger without real-time delays.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const NIGHT_WAVE_SCHEDULE := preload("res://scripts/night_wave_schedule.gd")

var failures: int = 0
var total_spawned: int = 0
var split_nights_seen: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node2D = MAIN_SCENE.instantiate() as Node2D
	main.checkpoint_enabled = false
	main.exploration_debug_seed = 424242
	main.final_boss_spawn_delay = 999.0
	root.add_child(main)
	current_scene = main
	await _frames(4)
	paused = false
	main._choose_starting_weapon("bow")
	await _frames(3)

	for night: int in range(1, 11):
		await _soak_night(main, night)

	_check(total_spawned == 464, "all 463 ordinary hostiles and the Night 10 boss traverse the production spawner")
	_check(split_nights_seen == 10, "every night exercises at least one split-lane wave")
	print("Accelerated ten-night combat soak: %s (spawned=%d)" % ["PASS" if failures == 0 else "FAIL (%d)" % failures, total_spawned])
	main._cancel_pending_wave_work("ten-night soak cleanup")
	main.queue_free()
	await _frames(3)
	quit(0 if failures == 0 else 1)


func _soak_night(main: Node2D, night: int) -> void:
	main.current_phase = main.Phase.DAY
	main.current_day = night
	main._clear_all_enemies()
	main._start_night()
	await _frames(1)

	# Invalidate only the timer coroutine; retain the production night ledger.
	main.wave_director.wave_token += 1
	main.wave_director.wave_waiting = false
	main.wave_director.wave_active = false
	var plan: Array[Dictionary] = NIGHT_WAVE_SCHEDULE.for_night(night, 0.0)
	var expected: int = NIGHT_WAVE_SCHEDULE.ordinary_total(night) + (1 if night == 10 else 0)
	main.wave_director.wave_plan = plan
	main.wave_director.scheduled_spawn_count = expected
	main.wave_director.spawned_required_count = 0
	main.wave_director.killed_required_count = 0
	main.wave_director.pending_spawn_count = expected
	main.wave_director.living_required_hostiles.clear()
	main.wave_director.killed_hostile_ids.clear()
	main.wave_director.spawn_work_complete = false
	main.wave_director.boss_required = night == 10
	main.wave_director.boss_killed = false

	var spawned_this_night: int = 0
	var saw_split: bool = false
	for wave: Dictionary in plan:
		var lane: String = str(wave["lane"])
		if lane == "boss":
			_check(main._spawn_grave_ox(), "Night 10 boss spawns through the production path")
			spawned_this_night += 1
			total_spawned += 1
			await _hold_and_retire_batch(main)
			continue
		if lane == "split":
			saw_split = true
		for spawn_index: int in range(int(wave["count"])):
			if main.wave_director.required_alive_count() >= main.wave_director.active_enemy_cap:
				await _hold_and_retire_batch(main)
			var spawn_lane: String = ("north" if spawn_index % 2 == 0 else "east") if lane == "split" else lane
			var entry: Dictionary = NIGHT_WAVE_SCHEDULE.spawn_entry(wave, spawn_index)
			_check(main._spawn_enemy_in_lane(spawn_lane, str(entry["family"]), entry["behavior"]), "Night %d wave spawn succeeds" % night)
			spawned_this_night += 1
			total_spawned += 1
			_check(main.wave_director.required_alive_count() <= main.wave_director.active_enemy_cap, "Night %d never exceeds its active cap" % night)

	await _hold_and_retire_batch(main)
	main.wave_director.spawn_work_complete = true
	main.wave_director.pending_spawn_count = 0
	_check(spawned_this_night == expected, "Night %d preserves its exact scheduled total" % night)
	_check(main.wave_director.spawned_required_count == expected and main.wave_director.killed_required_count == expected, "Night %d ledger accounts for every accelerated hostile" % night)
	_check(main.wave_director.can_complete_night(), "Night %d remains kill-gated after accelerated traversal" % night)
	if saw_split:
		split_nights_seen += 1
	main.wave_director._try_complete_night()
	await _frames(2)


func _hold_and_retire_batch(main: Node2D) -> void:
	var alive_before: int = main.wave_director.required_alive_count()
	if alive_before <= 0:
		return
	main.night_presentation_controller.update_night_readability()
	await _frames(3)
	for hostile: Node in main.get_node("Enemies").get_children():
		if is_instance_valid(hostile):
			main.wave_director.mark_required_hostile_killed(hostile)
			hostile.queue_free()
	await _frames(2)
	_check(main.wave_director.required_alive_count() == 0, "accelerated cap batch retires cleanly")


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		return
	failures += 1
	print("FAIL: %s" % description)
