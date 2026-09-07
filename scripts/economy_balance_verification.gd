extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const ECONOMY_BALANCE := preload("res://scripts/economy_balance.gd")
const NIGHT_WAVE_SCHEDULE := preload("res://scripts/night_wave_schedule.gd")

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var expected_days: Array[Dictionary] = [
		{"wood": 11.0, "stone": 8.0, "iron": 3.75, "essence": 8.0},
		{"wood": 14.0, "stone": 9.0, "iron": 3.00, "essence": 6.0},
		{"wood": 14.0, "stone": 9.0, "iron": 3.00, "essence": 6.0},
		{"wood": 14.0, "stone": 9.0, "iron": 3.25, "essence": 6.0},
		{"wood": 14.0, "stone": 9.0, "iron": 3.25, "essence": 6.0},
		{"wood": 12.0, "stone": 8.0, "iron": 2.00, "essence": 5.0},
		{"wood": 12.0, "stone": 7.0, "iron": 2.00, "essence": 4.0},
		{"wood": 11.0, "stone": 7.0, "iron": 2.00, "essence": 4.0},
		{"wood": 11.0, "stone": 7.0, "iron": 2.00, "essence": 4.0},
		{"wood": 11.0, "stone": 7.0, "iron": 2.00, "essence": 4.0},
	]
	var pickup_counts: Dictionary = ECONOMY_BALANCE.pickup_counts()
	_check(pickup_counts["forest"] == {"wood": 8} and pickup_counts["mine"] == {"stone": 5, "iron": 3} and pickup_counts["ruins"] == {"essence": 6}, "income model matches the authored resource-marker plan")
	for day: int in range(1, 11):
		var income: Dictionary = ECONOMY_BALANCE.expected_day_income(day)
		var expected: Dictionary = expected_days[day - 1]
		print("Expected income D%d: %s" % [day, _income_text(income)])
		_check(_income_matches(income, expected), "Day %d income matches the ten-day deterministic projection" % day)
		if day > 1:
			_check(_pickup_total(ECONOMY_BALANCE.pickup_counts_for_day(day)) <= _pickup_total(ECONOMY_BALANCE.pickup_counts_for_day(day - 1)), "Day %d pickup respawn does not grow late-game abundance" % day)

	var day_1: Dictionary = ECONOMY_BALANCE.expected_day_income(1)
	var day_2: Dictionary = ECONOMY_BALANCE.expected_day_income(2)
	var cumulative: Dictionary = ECONOMY_BALANCE.expected_cumulative_income(10)
	print("Expected cumulative income D1-10: %s" % _income_text(cumulative))
	_check(_income_matches(cumulative, {"wood": 124.0, "stone": 80.0, "iron": 26.25, "essence": 53.0}), "ten-night cumulative economy remains bounded")
	_check(ECONOMY_BALANCE.worker_income(4) == {"wood": 4, "stone": 1, "iron": 0}, "starting Workers provide useful Wood without passive Iron abundance")
	_check(ECONOMY_BALANCE.worker_income(6) == {"wood": 5, "stone": 2, "iron": 1} and ECONOMY_BALANCE.worker_income(10) == {"wood": 6, "stone": 3, "iron": 1}, "additional Workers have useful diminishing returns")
	_check(ECONOMY_BALANCE.worker_income(20) == ECONOMY_BALANCE.worker_income(10), "Worker income saturates before population growth can create late-game abundance")
	_check(ECONOMY_BALANCE.expected_cumulative_income(10, 4, 2)["food"] == 18.0, "a Day 1 level-1 Farm supports eighteen optional rescues through Day 10")
	_check(ECONOMY_BALANCE.house_capacity_for_level(1) == 3 and ECONOMY_BALANCE.farm_income_for_level(1) == 2 and ECONOMY_BALANCE.farm_income_for_level(3) == 4, "House and Farm outputs remain useful but bounded")

	var worker_growth_cumulative: Dictionary = _cumulative_with_workers(6, 2)
	_check(_income_matches(worker_growth_cumulative, {"wood": 133.0, "stone": 89.0, "iron": 35.25, "essence": 53.0, "food": 18.0}), "assigning two early Workers creates a distinct ten-day growth projection")

	var day_1_pickups: Dictionary = _pickup_totals_from_counts(pickup_counts)
	print("Predictable Day 1 pickups: %s" % _income_text(day_1_pickups))
	var immediate_fortification_cost: Dictionary = _sum_defense_cost(["archer", "ballista", "barricade"])
	var infrastructure_cost: Dictionary = _sum_village_cost(["barracks", "farm", "barricade"])
	_check(_can_afford(day_1_pickups, immediate_fortification_cost), "immediate fortification plan is affordable from predictable Day 1 pickups")
	_check(_can_afford(day_1_pickups, infrastructure_cost), "infrastructure plan is affordable from predictable Day 1 pickups")
	_check(not _can_afford(day_1_pickups, _merge_costs(immediate_fortification_cost, infrastructure_cost)), "the two viable openings compete for the same Day 1 budget")
	var full_opening_cost: Dictionary = _merge_costs(
		_sum_village_cost(["house", "farm", "barracks", "blacksmith"]),
		_sum_defense_cost(["archer", "ballista", "barricade"])
	)
	_check(not _can_afford(day_1, full_opening_cost), "Day 1 enemy-inclusive income cannot buy every important opening investment")
	var combat_specialist_cost: Dictionary = _combat_specialist_cost()
	var population_specialist_cost: Dictionary = _population_specialist_cost()
	_check(_can_afford(cumulative, combat_specialist_cost), "baseline income supports a focused Blacksmith and three-defense combat plan")
	_check(_can_afford(cumulative, population_specialist_cost), "baseline income supports a focused House, Farm, and Barracks growth plan")
	_check(not _can_afford(cumulative, _merge_costs(combat_specialist_cost, population_specialist_cost)), "baseline income cannot complete both specialist plans, preserving a run-level strategy choice")
	_check(_can_afford(worker_growth_cumulative, _merge_costs(combat_specialist_cost, population_specialist_cost)), "early Worker investment can fund both plans only by giving up immediate soldiers")
	_check(not _can_afford(cumulative, _seven_max_barricades_cost()), "baseline income cannot fill and max every defense slot")
	_check(
		ECONOMY_BALANCE.rescue_food_cost() == 1
			and ECONOMY_BALANCE.shrine_cost("heal")["essence"] == 2
			and ECONOMY_BALANCE.shrine_cost("blessing")["essence"] == 4
			and ECONOMY_BALANCE.shrine_cost("ward")["essence"] == 5,
		"rescue and shrine costs are included in the centralized economy model"
	)
	_check(
		int(ECONOMY_BALANCE.village_definition("blacksmith")["cost"]["iron"]) > 0
			and int(ECONOMY_BALANCE.village_definition("barracks")["cost"]["stone"]) > 0,
		"Blacksmith and Barracks compete for different scarce materials and create a timing choice"
	)
	_check(
		ECONOMY_BALANCE.village_upgrade_cost("blacksmith", 3)["iron"] > ECONOMY_BALANCE.village_upgrade_cost("blacksmith", 2)["iron"]
			and ECONOMY_BALANCE.defense_upgrade_cost(3)["iron"] > ECONOMY_BALANCE.defense_upgrade_cost(2)["iron"],
		"late upgrades arrive with meaningful escalating costs"
	)
	_check(not _can_afford(day_1, _merge_costs(ECONOMY_BALANCE.shrine_cost("blessing"), ECONOMY_BALANCE.shrine_cost("ward"))), "Day 1 Essence forces a blessing-versus-ward choice")
	_check(
		ECONOMY_BALANCE.defense_repair_cost(false, true)["wood"] > 0
			and _can_afford(day_2, ECONOMY_BALANCE.defense_repair_cost(false, true)),
		"a destroyed defense is painful but recoverable from a later day"
	)

	var main: Node2D = MAIN_SCENE.instantiate() as Node2D
	main.exploration_debug_seed = 17
	root.add_child(main)
	current_scene = main
	await process_frame
	paused = false
	main._choose_starting_weapon("bow")
	await process_frame
	_check(main.nights_to_survive == 10 and is_equal_approx(main.day_duration, 165.0), "runtime is configured for ten 165-second days")
	_check(_boss_is_exclusive_to_night_10(), "the final boss remains exclusive to Night 10")

	_check(main._defense_build_definition("archer")["cost"] == ECONOMY_BALANCE.defense_definition("archer")["cost"], "defense UI definition uses central balance data")
	_check(main._village_build_definition("blacksmith")["cost"] == ECONOMY_BALANCE.village_definition("blacksmith")["cost"], "village UI definition uses central balance data")
	_check(main._village_upgrade_cost("blacksmith", 3) == ECONOMY_BALANCE.village_upgrade_cost("blacksmith", 3), "upgrade UI and charging use the same level cost")
	_check(main.get_node("DayEnemies").get_child_count() == 8, "central enemy-count data preserves the first-day plan")
	_check(_day_enemy_rewards_are_central(main), "day enemy rewards come from central balance data")

	for day: int in range(1, 11):
		_check(_authored_pickup_counts_match_balance(main, ECONOMY_BALANCE.pickup_counts_for_day(day), day), "Day %d authored resource respawns match the central schedule" % day)
		_check(_authored_enemy_counts_match_balance(main, day), "Day %d authored enemy rewards match the central count schedule" % day)
	var build_spot: GloamBuildSpot = main.get_node("World/Regions/Village/DefenseBuildSpots").get_child(0) as GloamBuildSpot
	main.wood = 8
	main.stone = 5
	main.iron = 3
	main.active_build_spot = build_spot
	var archer_cost: Dictionary = ECONOMY_BALANCE.defense_definition("archer")["cost"]
	_check(main._try_build("archer"), "a central-cost defense can be purchased")
	_check(main.wood == 8 - int(archer_cost["wood"]), "charged defense cost matches the central price")

	main.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("Economy balance verification: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _pickup_totals_from_counts(counts: Dictionary) -> Dictionary:
	var totals: Dictionary = {"wood": 0.0, "stone": 0.0, "iron": 0.0, "essence": 0.0, "food": 0.0}
	for zone: String in counts:
		for resource_name: String in counts[zone]:
			totals[resource_name] += float(counts[zone][resource_name])
	return totals


func _pickup_total(counts: Dictionary) -> int:
	var total: int = 0
	for zone: String in counts:
		for resource_name: String in counts[zone]:
			total += int(counts[zone][resource_name])
	return total


func _cumulative_with_workers(worker_count_after_day_1: int, farm_income: int) -> Dictionary:
	var result: Dictionary = {"wood": 0.0, "stone": 0.0, "iron": 0.0, "essence": 0.0, "food": 0.0}
	for day: int in range(1, 11):
		var income: Dictionary = ECONOMY_BALANCE.expected_day_income(
			day,
			ECONOMY_BALANCE.STARTING_WORKERS if day == 1 else worker_count_after_day_1,
			farm_income
		)
		for resource_name: String in result:
			result[resource_name] += float(income.get(resource_name, 0.0))
	return result


func _combat_specialist_cost() -> Dictionary:
	var result: Dictionary = ECONOMY_BALANCE.village_definition("blacksmith")["cost"]
	result = _merge_costs(result, ECONOMY_BALANCE.village_upgrade_cost("blacksmith", 2))
	result = _merge_costs(result, ECONOMY_BALANCE.village_upgrade_cost("blacksmith", 3))
	for kind: String in ["archer", "archer", "ballista"]:
		result = _merge_costs(result, ECONOMY_BALANCE.defense_definition(kind)["cost"])
		result = _merge_costs(result, ECONOMY_BALANCE.defense_upgrade_cost(2))
		result = _merge_costs(result, ECONOMY_BALANCE.defense_upgrade_cost(3))
	return result


func _population_specialist_cost() -> Dictionary:
	var result: Dictionary = {"wood": 0, "stone": 0, "iron": 0, "essence": 0}
	for kind: String in ["house", "farm", "barracks"]:
		result = _merge_costs(result, ECONOMY_BALANCE.village_definition(kind)["cost"])
		result = _merge_costs(result, ECONOMY_BALANCE.village_upgrade_cost(kind, 2))
		result = _merge_costs(result, ECONOMY_BALANCE.village_upgrade_cost(kind, 3))
	return result


func _seven_max_barricades_cost() -> Dictionary:
	var result: Dictionary = {"wood": 0, "stone": 0, "iron": 0, "essence": 0}
	for _slot: int in range(7):
		result = _merge_costs(result, ECONOMY_BALANCE.defense_definition("barricade")["cost"])
		result = _merge_costs(result, ECONOMY_BALANCE.defense_upgrade_cost(2))
		result = _merge_costs(result, ECONOMY_BALANCE.defense_upgrade_cost(3))
	return result


func _boss_is_exclusive_to_night_10() -> bool:
	for night: int in range(1, 11):
		var plan: Array[Dictionary] = NIGHT_WAVE_SCHEDULE.for_night(night, 15.0)
		var has_boss: bool = str(plan.back().get("lane", "")) == "boss"
		if has_boss != (night == 10):
			return false
	return true


func _authored_pickup_counts_match_balance(main: Node2D, expected: Dictionary, day: int) -> bool:
	var actual: Dictionary = {"forest": {}, "mine": {}, "ruins": {}}
	for entry: Dictionary in main.world_visuals.get_resource_layout(17, day):
		var zone: String = str(entry["zone"])
		var resource_name: String = str(entry["type"])
		actual[zone][resource_name] = int(actual[zone].get(resource_name, 0)) + 1
	return actual == expected


func _authored_enemy_counts_match_balance(main: Node2D, day: int) -> bool:
	for zone: String in ["forest", "mine", "ruins"]:
		var count: int = ECONOMY_BALANCE.day_enemy_count(zone, day)
		if main.world_visuals.get_day_enemy_spawn_positions(zone, 17, day, count).size() != count:
			return false
	return true


func _sum_defense_cost(kinds: Array[String]) -> Dictionary:
	var result: Dictionary = {"wood": 0, "stone": 0, "iron": 0, "essence": 0}
	for kind: String in kinds:
		result = _merge_costs(result, ECONOMY_BALANCE.defense_definition(kind)["cost"])
	return result


func _sum_village_cost(kinds: Array[String]) -> Dictionary:
	var result: Dictionary = {"wood": 0, "stone": 0, "iron": 0, "essence": 0}
	for kind: String in kinds:
		var definition: Dictionary = ECONOMY_BALANCE.village_definition(kind)
		if not definition.is_empty():
			result = _merge_costs(result, definition["cost"])
	return result


func _merge_costs(first: Dictionary, second: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for resource_name: String in ECONOMY_BALANCE.RESOURCE_ORDER:
		result[resource_name] = int(first.get(resource_name, 0)) + int(second.get(resource_name, 0))
	return result


func _can_afford(resources: Dictionary, cost: Dictionary) -> bool:
	for resource_name: String in ECONOMY_BALANCE.RESOURCE_ORDER:
		if float(resources.get(resource_name, 0.0)) < float(cost.get(resource_name, 0)):
			return false
	return true


func _day_enemy_rewards_are_central(main: Node2D) -> bool:
	for enemy_node: Node in main.get_node("DayEnemies").get_children():
		var enemy: GloamDayEnemy = enemy_node as GloamDayEnemy
		var reward: Dictionary = ECONOMY_BALANCE.enemy_reward_profile(enemy.zone_type)
		if enemy.reward_resource != str(reward["resource"]):
			return false
		if enemy.reward_amount != int(reward["amount"]):
			return false
		if enemy.bonus_resource != str(reward["bonus_resource"]):
			return false
		if not is_equal_approx(enemy.bonus_chance, float(reward["bonus_chance"])):
			return false
	return true


func _income_text(income: Dictionary) -> String:
	return "W %.2f / S %.2f / I %.2f / E %.2f / F %.2f" % [
		float(income.get("wood", 0.0)),
		float(income.get("stone", 0.0)),
		float(income.get("iron", 0.0)),
		float(income.get("essence", 0.0)),
		float(income.get("food", 0.0)),
	]


func _income_matches(actual: Dictionary, expected: Dictionary) -> bool:
	for resource_name: String in expected:
		if not _approx(float(actual.get(resource_name, 0.0)), float(expected[resource_name])):
			return false
	return true


func _approx(value: float, expected: float) -> bool:
	return is_equal_approx(value, expected)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		print("FAIL: %s" % description)
