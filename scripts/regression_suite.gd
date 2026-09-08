extends SceneTree

## Fast, deterministic logic regressions for the failure-prone run systems.
##
## This suite intentionally advances state directly.  Full-scene verification
## remains separate because it exercises rendering, scene wiring, and timers.

const ECONOMY_BALANCE := preload("res://scripts/economy_balance.gd")
const NIGHT_WAVE_SCHEDULE := preload("res://scripts/night_wave_schedule.gd")
const WAVE_DIRECTOR := preload("res://scripts/wave_director.gd")
const RUN_PHASE_DIRECTOR := preload("res://scripts/run_phase_director.gd")
const SETTLEMENT_STATE := preload("res://scripts/settlement_state.gd")
const ELEMENTAL_PROGRESSION := preload("res://scripts/elemental_progression.gd")
const INPUT_ACTIONS := preload("res://scripts/input_actions.gd")
const CONTEXTUAL_MENU := preload("res://scripts/contextual_interaction_menu.gd")
const GUARD_SCENE := preload("res://scenes/guard.tscn")
const BLACKSMITH_SCENE := preload("res://scenes/blacksmith.tscn")
const HOUSE_SCENE := preload("res://scenes/house.tscn")

const EXPECTED_WAVE_COUNTS: Array[Array] = [
	[5, 6, 7],
	[6, 7, 7, 8],
	[8, 9, 10, 11],
	[8, 8, 9, 8, 9],
	[8, 9, 9, 9, 10],
	[8, 8, 8, 8, 8, 8],
	[8, 8, 9, 9, 10, 10],
	[8, 8, 8, 8, 8, 8, 8],
	[8, 8, 9, 9, 9, 9, 10],
	[9, 9, 10, 10, 10, 11, 13, 1],
]

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("GLOAM FAST LOGIC REGRESSION")
	_test_wave_plan()
	_test_ten_day_economy()
	await _test_phase_and_wave_lifecycle()
	await _test_required_hostile_completion()
	_test_settlement_accounting()
	_test_resource_transactions()
	_test_upgrade_choice_validity()
	_test_input_action_contract()
	await _test_interaction_debouncing()
	await _test_soldier_return_to_post()
	print("FAST LOGIC REGRESSION: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _test_wave_plan() -> void:
	print("-- wave schedule")
	var target_totals: Array[int] = [18, 28, 38, 42, 45, 48, 54, 56, 62, 72]
	for night_number in range(1, 11):
		var plan: Array[Dictionary] = NIGHT_WAVE_SCHEDULE.for_night(night_number, 15.0)
		var expected_plan: Array = EXPECTED_WAVE_COUNTS[night_number - 1]
		_expect(plan.size() == expected_plan.size(), "Night %d wave count" % night_number, expected_plan.size(), plan.size())

		var elapsed: float = 0.0
		for wave_index in range(plan.size()):
			var wave: Dictionary = plan[wave_index]
			var expected_count: int = int(expected_plan[wave_index])
			var actual_count: int = int(wave.get("count", 0))
			print("Night %d wave %d started: expected %d actual %d" % [
				night_number,
				wave_index + 1,
				expected_count,
				actual_count,
			])
			_expect(actual_count == expected_count, "Night %d wave %d completes" % [night_number, wave_index + 1], expected_count, actual_count)
			elapsed += NIGHT_WAVE_SCHEDULE.pre_spawn_delay(wave)
			for spawn_index: int in range(maxi(0, actual_count - 1)):
				elapsed += NIGHT_WAVE_SCHEDULE.spawn_gap(wave, spawn_index)
			if wave_index < plan.size() - 1:
				elapsed += NIGHT_WAVE_SCHEDULE.breathing_delay(wave)

		var declared_duration: float = NIGHT_WAVE_SCHEDULE.duration(plan)
		_expect(is_equal_approx(declared_duration, elapsed), "Night %d duration matches all spawn work" % night_number, declared_duration, elapsed)
		_expect(NIGHT_WAVE_SCHEDULE.ordinary_total(night_number) == target_totals[night_number - 1], "Night %d ordinary pressure total" % night_number, target_totals[night_number - 1], NIGHT_WAVE_SCHEDULE.ordinary_total(night_number))
		_expect((str(plan.back().get("lane", "")) == "boss") == (night_number == 10), "boss is scheduled only on Night 10")
		_expect(NIGHT_WAVE_SCHEDULE.active_enemy_cap(night_number) >= 20 and NIGHT_WAVE_SCHEDULE.active_enemy_cap(night_number) <= 36, "Night %d has a bounded active cap" % night_number)


func _test_ten_day_economy() -> void:
	print("-- ten-day economy")
	var expected_pickup_totals: Array[int] = [22, 15, 15, 12, 12, 10, 8, 7, 7, 7]
	var expected_enemy_totals: Array[int] = [8, 11, 11, 14, 14, 11, 11, 11, 11, 11]
	for day: int in range(1, 11):
		var pickup_total: int = 0
		for zone_counts: Dictionary in ECONOMY_BALANCE.pickup_counts_for_day(day).values():
			for amount: int in zone_counts.values():
				pickup_total += amount
		var enemy_total: int = 0
		for zone: String in ["forest", "mine", "ruins"]:
			enemy_total += ECONOMY_BALANCE.day_enemy_count(zone, day)
		_expect(pickup_total == expected_pickup_totals[day - 1], "Day %d pickup respawn budget" % day, expected_pickup_totals[day - 1], pickup_total)
		_expect(enemy_total == expected_enemy_totals[day - 1], "Day %d optional enemy reward budget" % day, expected_enemy_totals[day - 1], enemy_total)
	var cumulative: Dictionary = ECONOMY_BALANCE.expected_cumulative_income(10)
	_expect(is_equal_approx(float(cumulative["wood"]), 124.0), "Day 1-10 Wood projection is bounded", 124.0, cumulative["wood"])
	_expect(is_equal_approx(float(cumulative["stone"]), 80.0), "Day 1-10 Stone projection is bounded", 80.0, cumulative["stone"])
	_expect(is_equal_approx(float(cumulative["iron"]), 26.25), "Day 1-10 Iron projection is bounded", 26.25, cumulative["iron"])
	_expect(is_equal_approx(float(cumulative["essence"]), 53.0), "Day 1-10 Essence projection is bounded", 53.0, cumulative["essence"])
	_expect(ECONOMY_BALANCE.worker_income(6) == {"wood": 5, "stone": 2, "iron": 1}, "population investment has bounded resource returns")
	_expect(ECONOMY_BALANCE.worker_income(20) == {"wood": 6, "stone": 3, "iron": 1}, "late population cannot create runaway passive income")
	_expect(ECONOMY_BALANCE.farm_income_for_level(1) == 2 and ECONOMY_BALANCE.farm_income_for_level(3) == 4, "Farm upgrades remain useful without exponential food growth")


func _test_phase_and_wave_lifecycle() -> void:
	print("-- phase and wave lifecycle")
	var phase_director: GloamRunPhaseDirector = RUN_PHASE_DIRECTOR.new()
	phase_director.configure(10)
	phase_director.start_run()
	_expect(phase_director.phase == GloamRunPhaseDirector.Phase.DAY and phase_director.day == 1, "run starts in Day 1", "DAY 1", "phase=%d day=%d" % [phase_director.phase, phase_director.day])
	phase_director.enter_night()
	_expect(phase_director.phase == GloamRunPhaseDirector.Phase.NIGHT, "phase advances to night")
	phase_director.complete_regular_night()
	_expect(phase_director.phase == GloamRunPhaseDirector.Phase.DAY and phase_director.day == 2, "completed night returns to Day 2", "DAY 2", "phase=%d day=%d" % [phase_director.phase, phase_director.day])
	phase_director.enter_victory()
	_expect(phase_director.phase == GloamRunPhaseDirector.Phase.VICTORY, "terminal victory phase is distinct from day and night")
	phase_director.free()

	var wave_director: GloamWaveDirector = WAVE_DIRECTOR.new()
	root.add_child(wave_director)
	wave_director.configure(
		func(_lane: String, _family: String, _behavior: Dictionary) -> bool: return true,
		func() -> bool: return true,
		func() -> bool: return true,
		func(_wave: Dictionary) -> Vector2: return Vector2.ZERO
	)
	wave_director.start_night(2, 0.0, 15.0)
	var declared_duration: float = NIGHT_WAVE_SCHEDULE.duration(wave_director.wave_plan)
	_expect(wave_director.night_clock_time_left == 0.0 and declared_duration > 0.0, "night pacing has no phase-ending countdown", 0.0, wave_director.night_clock_time_left)
	_expect(wave_director.wave_index == 0 and wave_director.night_schedule_active, "Night 2 starts its first wave without skipping state", "index=0 active=true", "index=%d active=%s" % [wave_director.wave_index, wave_director.night_schedule_active])
	wave_director.cancel_pending_work("regression cleanup")
	_expect(not wave_director.night_schedule_active and not wave_director.wave_active and not wave_director.wave_waiting, "cancelled wave work is no longer active")
	# Let the already-created gameplay timer resume its cancelled continuation
	# before freeing the director. This advances frames only for teardown; no
	# gameplay assertion depends on elapsed wall-clock time.
	for _frame in range(8):
		await process_frame
	wave_director.queue_free()
	await process_frame


func _test_required_hostile_completion() -> void:
	print("-- required hostile ledger")
	var director: GloamWaveDirector = WAVE_DIRECTOR.new()
	root.add_child(director)
	director.configure(func(_lane: String, _family: String, _behavior: Dictionary) -> bool: return true, func() -> bool: return true, func() -> bool: return true, func(_wave: Dictionary) -> Vector2: return Vector2.ZERO)
	director.night_schedule_active = true
	director.scheduled_spawn_count = 2
	director.pending_spawn_count = 2
	director.active_enemy_cap = 2
	var first := Node.new()
	var second := Node.new()
	root.add_child(first)
	root.add_child(second)
	director.register_required_hostile(first)
	director.register_required_hostile(second)
	director.spawn_work_complete = true
	_expect(not director.can_complete_night(), "night cannot end while required hostiles remain")
	director.mark_required_hostile_killed(first)
	_expect(not director.night_schedule_complete, "night remains active after all but the last required death")
	director.mark_required_hostile_killed(second)
	_expect(director.night_schedule_complete, "night ends after spawn completion and the last required death")
	first.queue_free()
	second.queue_free()
	director.queue_free()
	await process_frame

	var cap_director: GloamWaveDirector = WAVE_DIRECTOR.new()
	root.add_child(cap_director)
	cap_director.night_schedule_active = true
	cap_director.scheduled_spawn_count = 3
	cap_director.pending_spawn_count = 3
	cap_director.active_enemy_cap = 2
	var capped_a := Node.new()
	var capped_b := Node.new()
	var postponed := Node.new()
	root.add_child(capped_a)
	root.add_child(capped_b)
	root.add_child(postponed)
	cap_director.register_required_hostile(capped_a)
	cap_director.register_required_hostile(capped_b)
	_expect(not cap_director.is_spawn_capacity_available() and cap_director.pending_spawn_count == 1, "spawn cap postpones one scheduled hostile without discarding it")
	cap_director.mark_required_hostile_killed(capped_a)
	_expect(cap_director.is_spawn_capacity_available() and cap_director.pending_spawn_count == 1, "a kill reopens capacity while preserving pending work")
	cap_director.register_required_hostile(postponed)
	_expect(cap_director.spawned_required_count == 3 and cap_director.pending_spawn_count == 0, "postponed hostile eventually consumes its preserved schedule slot")
	cap_director.cancel_pending_work("cap ledger cleanup")
	for node: Node in [capped_a, capped_b, postponed]: node.queue_free()
	cap_director.queue_free()
	await process_frame

	var invalid_director: GloamWaveDirector = WAVE_DIRECTOR.new()
	root.add_child(invalid_director)
	invalid_director.night_schedule_active = true
	invalid_director.scheduled_spawn_count = 1
	invalid_director.pending_spawn_count = 1
	var invalid_hostile := Node.new()
	root.add_child(invalid_hostile)
	invalid_director.register_required_hostile(invalid_hostile)
	invalid_director.spawn_work_complete = true
	invalid_hostile.queue_free()
	await process_frame
	_expect(invalid_director.required_alive_count() == 0 and invalid_director.killed_required_count == 0 and not invalid_director.can_complete_night(), "freed invalid nodes are neither living hostiles nor credited kills")
	invalid_director.cancel_pending_work("scene reload safety")
	_expect(invalid_director.pending_spawn_count == 0 and not invalid_director.night_schedule_active, "cancellation clears pending work without completing the night")
	invalid_director.queue_free()
	await process_frame

	var boss_director: GloamWaveDirector = WAVE_DIRECTOR.new()
	root.add_child(boss_director)
	boss_director.night_schedule_active = true
	boss_director.scheduled_spawn_count = 2
	boss_director.pending_spawn_count = 2
	boss_director.boss_required = true
	var ordinary := Node.new()
	var boss := Node.new()
	root.add_child(ordinary)
	root.add_child(boss)
	boss_director.register_required_hostile(ordinary)
	boss_director.register_required_hostile(boss, true)
	boss_director.spawn_work_complete = true
	boss_director.mark_required_hostile_killed(ordinary)
	_expect(not boss_director.can_complete_night(), "final victory gate remains closed while the boss lives")
	boss_director.mark_required_hostile_killed(boss)
	_expect(boss_director.night_schedule_complete and boss_director.boss_killed, "final-night completion opens only after the required boss death")
	ordinary.queue_free()
	boss.queue_free()
	boss_director.queue_free()
	await process_frame


func _test_settlement_accounting() -> void:
	print("-- settlement accounting")
	var state: GloamSettlementState = SETTLEMENT_STATE.new()
	var blacksmith: GloamVillageBuilding = _configured_building(BLACKSMITH_SCENE, "blacksmith", 2)
	var buildings: Array[Node] = [blacksmith]
	state.recalculate_from_buildings(buildings, ECONOMY_BALANCE.BASE_POPULATION_CAPACITY)
	_expect(state.blacksmith_built, "active Blacksmith is detected")
	_expect(state.blacksmith_bonus_damage == 2, "level 2 Blacksmith bonus is derived", 2, state.blacksmith_bonus_damage)
	state.recalculate_from_buildings(buildings, ECONOMY_BALANCE.BASE_POPULATION_CAPACITY)
	_expect(state.blacksmith_bonus_damage == 2, "recalculation does not duplicate Blacksmith bonus", 2, state.blacksmith_bonus_damage)
	blacksmith.hp = 0
	state.recalculate_from_buildings(buildings, ECONOMY_BALANCE.BASE_POPULATION_CAPACITY)
	_expect(not state.blacksmith_built and state.blacksmith_bonus_damage == 0, "destroyed Blacksmith has no active bonus", 0, state.blacksmith_bonus_damage)
	blacksmith.hp = blacksmith.max_hp
	blacksmith.level = 1
	state.recalculate_from_buildings(buildings, ECONOMY_BALANCE.BASE_POPULATION_CAPACITY)
	_expect(state.blacksmith_bonus_damage == 1, "rebuilt level 1 Blacksmith applies once", 1, state.blacksmith_bonus_damage)

	var house: GloamVillageBuilding = _configured_building(HOUSE_SCENE, "house", 2)
	var house_buildings: Array[Node] = [house]
	state.total_population = 10
	state.recalculate_from_buildings(house_buildings, ECONOMY_BALANCE.BASE_POPULATION_CAPACITY)
	_expect(state.population_capacity == 11, "level 2 house capacity is derived", 11, state.population_capacity)
	house.hp = 0
	state.recalculate_from_buildings(house_buildings, ECONOMY_BALANCE.BASE_POPULATION_CAPACITY)
	_expect(state.population_capacity >= state.total_population and state.population_capacity >= 0, "house destruction keeps population state valid", true, state.population_capacity >= state.total_population)
	house.hp = house.max_hp
	state.recalculate_from_buildings(house_buildings, ECONOMY_BALANCE.BASE_POPULATION_CAPACITY)
	_expect(state.population_capacity == 11, "rebuilt house restores derived capacity without duplication", 11, state.population_capacity)
	blacksmith.free()
	house.free()


func _test_resource_transactions() -> void:
	print("-- resource transactions")
	var state: GloamSettlementState = SETTLEMENT_STATE.new()
	state.wood = 5
	state.stone = 2
	var cost: Dictionary = ECONOMY_BALANCE.cost(4, 2, 0)
	_expect(state.can_afford(cost), "affordable purchase is recognized", true, state.can_afford(cost))
	_expect(state.charge(cost), "affordable purchase charges successfully", true, false)
	_expect(state.wood == 1 and state.stone == 0, "purchase deduction matches its cost", "wood=1 stone=0", "wood=%d stone=%d" % [state.wood, state.stone])
	var before_wood: int = state.wood
	var expensive_cost: Dictionary = ECONOMY_BALANCE.cost(99, 0, 0)
	_expect(not state.charge(expensive_cost), "unaffordable purchase is rejected", false, true)
	_expect(state.wood == before_wood and state.wood >= 0 and state.stone >= 0, "rejected purchase does not create negative resources", true, state.wood >= 0 and state.stone >= 0)


func _test_upgrade_choice_validity() -> void:
	print("-- upgrade choices")
	var levels: Dictionary = {"fire": 0, "water": 0, "earth": 0, "air": 0}
	var seeded_rng := RandomNumberGenerator.new()
	seeded_rng.seed = 1307
	var first_choices: Array[String] = ELEMENTAL_PROGRESSION.roll_choices(levels, "sword", seeded_rng)
	_expect(not first_choices.is_empty(), "seeded upgrade choice list is non-empty")
	for upgrade_id: String in first_choices:
		_expect(ELEMENTAL_PROGRESSION.is_upgrade_available(upgrade_id, levels), "choice %s is valid at tier 1" % upgrade_id, true, ELEMENTAL_PROGRESSION.is_upgrade_available(upgrade_id, levels))
	_expect(not ELEMENTAL_PROGRESSION.is_upgrade_available("fire_lingering", levels), "advanced Fire choice stays gated", false, true)
	levels["fire"] = 1
	_expect(ELEMENTAL_PROGRESSION.is_upgrade_available("fire_lingering", levels), "Fire tier 2 unlocks after its prerequisite", true, ELEMENTAL_PROGRESSION.is_upgrade_available("fire_lingering", levels))
	var repeat_rng := RandomNumberGenerator.new()
	repeat_rng.seed = 1307
	var repeat_choices: Array[String] = ELEMENTAL_PROGRESSION.roll_choices({"fire": 0, "water": 0, "earth": 0, "air": 0}, "sword", repeat_rng)
	_expect(first_choices == repeat_choices, "debug seed reproduces upgrade choices", first_choices, repeat_choices)


func _test_input_action_contract() -> void:
	print("-- input actions")
	var required_actions: Array[String] = [
		INPUT_ACTIONS.MOVE_LEFT,
		INPUT_ACTIONS.MOVE_RIGHT,
		INPUT_ACTIONS.MOVE_UP,
		INPUT_ACTIONS.MOVE_DOWN,
		INPUT_ACTIONS.ATTACK,
		INPUT_ACTIONS.INTERACT,
		INPUT_ACTIONS.MENU_ACCEPT,
		INPUT_ACTIONS.MENU_CANCEL,
	]
	for action_name: String in required_actions:
		var mapped: bool = InputMap.has_action(action_name) and not InputMap.action_get_events(action_name).is_empty()
		_expect(mapped, "named action %s is mapped" % action_name, true, mapped)


func _test_interaction_debouncing() -> void:
	print("-- interaction debouncing")
	var menu: GloamContextualInteractionMenu = CONTEXTUAL_MENU.new()
	root.add_child(menu)
	await process_frame
	var selected_ids: Array[String] = []
	menu.choice_selected.connect(func(choice_id: String) -> void: selected_ids.append(choice_id))
	menu.open_menu("Test", "Test choice", [{"id": "build", "text": "Build — 1 Wood", "enabled": true}])
	var button: Button = menu.choice_buttons[0]
	menu._on_choice_pressed(button)
	menu._on_choice_pressed(button)
	_expect(selected_ids.size() == 1, "held/repeated choice input is debounced", 1, selected_ids.size())
	_expect(selected_ids[0] == "build", "debounced choice still reports the intended action", "build", selected_ids[0])
	menu.close_menu()
	menu.queue_free()
	await process_frame


func _test_soldier_return_to_post() -> void:
	print("-- soldier return to post")
	var holder := Node2D.new()
	root.add_child(holder)
	var guard: GloamSoldier = GUARD_SCENE.instantiate() as GloamSoldier
	holder.add_child(guard)
	await process_frame
	var home: Vector2 = guard.global_position
	guard.set_home_position(home)
	guard.global_position = home + Vector2(240.0, 0.0)
	guard.set_night_combat_active(false)
	for _step in range(40):
		guard._process(0.1)
	_expect(guard.global_position.distance_to(home) <= GloamSoldier.HOME_ARRIVAL_DISTANCE, "soldier returns to its stable home position", true, guard.global_position.distance_to(home) <= GloamSoldier.HOME_ARRIVAL_DISTANCE)
	guard.queue_free()
	holder.queue_free()
	await process_frame


func _configured_building(scene: PackedScene, building_type: String, level: int) -> GloamVillageBuilding:
	var building: GloamVillageBuilding = scene.instantiate() as GloamVillageBuilding
	building.building_type = building_type
	building.level = level
	building.max_hp = 100
	building.hp = 100
	return building


func _expect(condition: bool, description: String, expected: Variant = null, actual: Variant = null) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	failures += 1
	var details: String = ""
	if expected != null or actual != null:
		details = " | expected=%s actual=%s" % [str(expected), str(actual)]
	print("FAIL: %s%s" % [description, details])
