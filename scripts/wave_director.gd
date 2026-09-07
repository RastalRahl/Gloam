extends Node
class_name GloamWaveDirector

## Owns scheduled spawn work and the required-hostile ledger for one night.
## Timers pace readable waves only; they never decide when a night ends.

signal wave_warning(wave_number: int, total_waves: int, lane_label: String, warning_text: String, audio_position: Vector2)
signal wave_progress(wave_number: int, total_waves: int, lane_label: String)
signal breathing_room
signal hostile_count_changed(alive: int, pending: int)
signal spawn_cap_reached(alive: int, cap: int, pending: int)
signal spawn_work_completed
signal schedule_completed
signal wave_cancelled(reason: String)

const NIGHT_WAVE_SCHEDULE := preload("res://scripts/night_wave_schedule.gd")

var spawn_enemy: Callable
var spawn_boss: Callable
var is_night_active: Callable
var audio_position_for_wave: Callable

var final_boss_spawn_delay: float = 15.0
var current_day: int = 1
var wave_plan: Array[Dictionary] = []
var wave_index: int = 0
var wave_active: bool = false
var wave_waiting: bool = false
var wave_token: int = 0
var night_schedule_active: bool = false
var night_schedule_complete: bool = false
var night_finish_started: bool = false
var spawn_work_complete: bool = false
var night_schedule_duration: float = 0.0
var night_clock_time_left: float = 0.0 # Compatibility only; nights have no countdown.
var wave_cancel_reported: bool = false

var active_enemy_cap: int = 20
var active_enemy_cap_override: int = 0
var scheduled_spawn_count: int = 0
var spawned_required_count: int = 0
var killed_required_count: int = 0
var pending_spawn_count: int = 0
var boss_required: bool = false
var boss_killed: bool = false
var living_required_hostiles: Dictionary = {}
var killed_hostile_ids: Dictionary = {}


func configure(enemy_spawner: Callable, boss_spawner: Callable, lifecycle_check: Callable, wave_position_provider: Callable) -> void:
	spawn_enemy = enemy_spawner
	spawn_boss = boss_spawner
	is_night_active = lifecycle_check
	audio_position_for_wave = wave_position_provider
	process_mode = Node.PROCESS_MODE_PAUSABLE


func get_wave_plan(day: int, boss_delay: float = final_boss_spawn_delay) -> Array[Dictionary]:
	return NIGHT_WAVE_SCHEDULE.for_night(day, boss_delay)


func start_night(day: int, _legacy_minimum_duration: float, boss_delay: float) -> void:
	if night_schedule_active or wave_waiting or wave_active:
		cancel_pending_work("night restarted")
	current_day = day
	final_boss_spawn_delay = maxf(0.0, boss_delay)
	wave_plan = get_wave_plan(current_day, final_boss_spawn_delay)
	wave_index = 0
	wave_active = false
	wave_waiting = false
	night_schedule_active = true
	night_schedule_complete = false
	night_finish_started = false
	spawn_work_complete = false
	night_schedule_duration = NIGHT_WAVE_SCHEDULE.duration(wave_plan)
	night_clock_time_left = 0.0
	wave_cancel_reported = false
	active_enemy_cap = active_enemy_cap_override if active_enemy_cap_override > 0 else NIGHT_WAVE_SCHEDULE.active_enemy_cap(current_day)
	scheduled_spawn_count = _planned_spawn_total(wave_plan)
	spawned_required_count = 0
	killed_required_count = 0
	pending_spawn_count = scheduled_spawn_count
	boss_required = _plan_has_boss(wave_plan)
	boss_killed = false
	living_required_hostiles.clear()
	killed_hostile_ids.clear()
	wave_token += 1
	hostile_count_changed.emit(0, pending_spawn_count)
	_start_next_wave(wave_token)


func reset_for_day() -> void:
	if night_schedule_active or wave_waiting or wave_active:
		cancel_pending_work("day phase started")
	wave_index = 0
	wave_active = false
	wave_waiting = false
	night_schedule_active = false
	night_schedule_complete = false
	night_finish_started = false
	spawn_work_complete = false
	night_schedule_duration = 0.0
	night_clock_time_left = 0.0
	pending_spawn_count = 0
	living_required_hostiles.clear()
	killed_hostile_ids.clear()
	wave_plan.clear()


func cancel_pending_work(reason: String) -> void:
	var had_pending_work: bool = wave_waiting or wave_active or night_schedule_active
	if had_pending_work and not wave_cancel_reported:
		wave_cancel_reported = true
		wave_cancelled.emit(reason)
	wave_token += 1
	wave_active = false
	wave_waiting = false
	night_schedule_active = false
	spawn_work_complete = false
	pending_spawn_count = 0
	living_required_hostiles.clear()
	hostile_count_changed.emit(0, 0)


func register_required_hostile(hostile: Node, is_boss: bool = false) -> bool:
	if not night_schedule_active or not is_instance_valid(hostile):
		return false
	var hostile_id: int = hostile.get_instance_id()
	if living_required_hostiles.has(hostile_id) or killed_hostile_ids.has(hostile_id):
		return false
	living_required_hostiles[hostile_id] = weakref(hostile)
	hostile.set_meta("night_required_hostile", true)
	hostile.set_meta("night_wave_token", wave_token)
	hostile.set_meta("night_boss", is_boss)
	spawned_required_count += 1
	pending_spawn_count = maxi(0, scheduled_spawn_count - spawned_required_count)
	hostile.tree_exiting.connect(_on_required_hostile_tree_exiting.bind(hostile_id, wave_token), CONNECT_ONE_SHOT)
	hostile_count_changed.emit(required_alive_count(), pending_spawn_count)
	return true


func mark_required_hostile_killed(hostile: Node) -> bool:
	if not is_instance_valid(hostile):
		return false
	var hostile_id: int = hostile.get_instance_id()
	if not living_required_hostiles.has(hostile_id) or killed_hostile_ids.has(hostile_id):
		return false
	killed_hostile_ids[hostile_id] = true
	living_required_hostiles.erase(hostile_id)
	killed_required_count += 1
	if bool(hostile.get_meta("night_boss", false)):
		boss_killed = true
	hostile_count_changed.emit(required_alive_count(), pending_spawn_count)
	_try_complete_night()
	return true


func required_alive_count() -> int:
	_prune_invalid_living_refs()
	return living_required_hostiles.size()


func is_spawn_capacity_available() -> bool:
	return required_alive_count() < active_enemy_cap


func can_complete_night() -> bool:
	return (
		night_schedule_active
		and spawn_work_complete
		and pending_spawn_count == 0
		and spawned_required_count == scheduled_spawn_count
		and killed_required_count == scheduled_spawn_count
		and required_alive_count() == 0
		and (not boss_required or boss_killed)
	)


func is_lifecycle_valid(token: int) -> bool:
	return token == wave_token and night_schedule_active and _host_allows_progression()


func wait_for_gameplay_delay(seconds: float) -> bool:
	if seconds <= 0.0:
		return _host_allows_progression()
	var remaining: float = seconds
	while remaining > 0.0:
		var sample: float = minf(0.05, remaining)
		await get_tree().create_timer(sample, true).timeout
		if not _host_allows_progression() or not night_schedule_active:
			return false
		if get_tree().paused:
			continue
		remaining -= sample
	return true


func _host_allows_progression() -> bool:
	return is_night_active.is_valid() and bool(is_night_active.call())


func _start_next_wave(token: int) -> void:
	if not is_lifecycle_valid(token) or wave_waiting or wave_active:
		return
	if wave_index >= wave_plan.size():
		_mark_spawn_work_complete(token)
		return
	var this_wave_index: int = wave_index
	var wave: Dictionary = wave_plan[wave_index]
	wave_waiting = true
	var lane_label: String = _incoming_lane_text(str(wave.get("lane", "")))
	var position: Vector2 = audio_position_for_wave.call(wave) if audio_position_for_wave.is_valid() else Vector2.ZERO
	wave_warning.emit(this_wave_index + 1, wave_plan.size(), lane_label, str(wave.get("warning", "Incoming assault")), position)
	if not await wait_for_gameplay_delay(NIGHT_WAVE_SCHEDULE.pre_spawn_delay(wave)):
		return
	if not is_lifecycle_valid(token) or this_wave_index != wave_index:
		return
	wave_waiting = false
	wave_active = true
	wave_progress.emit(this_wave_index + 1, wave_plan.size(), lane_label)
	var completed: bool = await _run_wave_spawns(wave, token, this_wave_index)
	if not completed or not is_lifecycle_valid(token) or this_wave_index != wave_index:
		return
	wave_active = false
	wave_index += 1
	if wave_index < wave_plan.size():
		breathing_room.emit()
		if not await wait_for_gameplay_delay(NIGHT_WAVE_SCHEDULE.breathing_delay(wave)):
			return
		if is_lifecycle_valid(token):
			_start_next_wave(token)
	else:
		_mark_spawn_work_complete(token)


func _run_wave_spawns(wave: Dictionary, token: int, this_wave_index: int) -> bool:
	var expected_count: int = maxi(0, int(wave.get("count", 0)))
	var gap: float = maxf(0.0, float(wave.get("gap", 0.0)))
	var lane: String = str(wave.get("lane", "north"))
	var families: Array = wave.get("families", ["grunt"]) as Array
	for spawn_index: int in range(expected_count):
		if not await _wait_for_spawn_capacity(token):
			return false
		var spawned: bool = false
		if lane == "boss":
			spawned = spawn_boss.is_valid() and bool(spawn_boss.call())
		else:
			var spawn_lane: String = ("north" if spawn_index % 2 == 0 else "east") if lane == "split" else lane
			var family: String = str(families[spawn_index % maxi(1, families.size())]) if not families.is_empty() else "grunt"
			spawned = spawn_enemy.is_valid() and bool(spawn_enemy.call(spawn_lane, family))
		if not spawned:
			_cancel_wave("wave %d cancelled: required spawn unavailable" % (this_wave_index + 1))
			return false
		if gap > 0.0 and spawn_index < expected_count - 1 and not await wait_for_gameplay_delay(gap):
			return false
	return true


func _wait_for_spawn_capacity(token: int) -> bool:
	var reported: bool = false
	while is_lifecycle_valid(token) and not is_spawn_capacity_available():
		if not reported:
			spawn_cap_reached.emit(required_alive_count(), active_enemy_cap, pending_spawn_count)
			reported = true
		if not await wait_for_gameplay_delay(0.10):
			return false
	return is_lifecycle_valid(token)


func _mark_spawn_work_complete(token: int) -> void:
	if not is_lifecycle_valid(token) or spawn_work_complete:
		return
	spawn_work_complete = true
	wave_active = false
	wave_waiting = false
	spawn_work_completed.emit()
	_try_complete_night()


func _try_complete_night() -> void:
	if not can_complete_night() or night_schedule_complete:
		return
	night_schedule_active = false
	night_schedule_complete = true
	wave_active = false
	wave_waiting = false
	schedule_completed.emit()


func _on_required_hostile_tree_exiting(hostile_id: int, token: int) -> void:
	if token != wave_token or killed_hostile_ids.has(hostile_id):
		return
	# Invalid/freed nodes are removed from the live count, but never credited as
	# kills. That keeps teardown safe and prevents an accidental free from ending
	# an active night.
	living_required_hostiles.erase(hostile_id)
	hostile_count_changed.emit(required_alive_count(), pending_spawn_count)


func _prune_invalid_living_refs() -> void:
	var invalid_ids: Array[int] = []
	for hostile_id: Variant in living_required_hostiles.keys():
		var reference: WeakRef = living_required_hostiles[hostile_id] as WeakRef
		if reference == null or not is_instance_valid(reference.get_ref()):
			invalid_ids.append(int(hostile_id))
	for hostile_id: int in invalid_ids:
		living_required_hostiles.erase(hostile_id)


func _planned_spawn_total(plan: Array[Dictionary]) -> int:
	var total: int = 0
	for wave: Dictionary in plan:
		total += maxi(0, int(wave.get("count", 0)))
	return total


func _plan_has_boss(plan: Array[Dictionary]) -> bool:
	for wave: Dictionary in plan:
		if str(wave.get("lane", "")) == "boss":
			return true
	return false


func _cancel_wave(reason: String) -> void:
	wave_cancelled.emit(reason)
	wave_cancel_reported = true
	wave_active = false
	wave_waiting = false
	night_schedule_active = false
	pending_spawn_count = 0
	wave_token += 1


func _incoming_lane_text(lane: String) -> String:
	match lane:
		"north": return "NORTH GATE"
		"east": return "EAST GATE"
		"split": return "NORTH + EAST"
		"boss": return "NORTH GATE  •  BOSS"
	return "UNKNOWN LANE"
