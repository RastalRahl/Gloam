extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const ECONOMY_BALANCE := preload("res://scripts/economy_balance.gd")

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var day_1: Dictionary = ECONOMY_BALANCE.expected_day_income(1)
	var day_2: Dictionary = ECONOMY_BALANCE.expected_day_income(2)
	var day_3: Dictionary = ECONOMY_BALANCE.expected_day_income(3)
	var pickup_counts: Dictionary = ECONOMY_BALANCE.pickup_counts()
	_check(pickup_counts["forest"] == {"wood": 8} and pickup_counts["mine"] == {"stone": 5, "iron": 3} and pickup_counts["ruins"] == {"essence": 6}, "income model matches the authored resource-marker plan")
	print("Expected income D1: %s" % _income_text(day_1))
	print("Expected income D2: %s" % _income_text(day_2))
	print("Expected income D3: %s" % _income_text(day_3))
	print("Expected cumulative income: %s" % _income_text(ECONOMY_BALANCE.expected_cumulative_income(3)))

	_check(_approx(day_1["wood"], 11.0) and _approx(day_1["stone"], 8.0) and _approx(day_1["iron"], 4.05) and _approx(day_1["essence"], 8.0), "Day 1 income model includes pickups and expected enemy rewards")
	_check(_approx(day_2["wood"], 16.0) and _approx(day_2["stone"], 11.0) and _approx(day_2["iron"], 5.40) and _approx(day_2["essence"], 9.0), "Day 2 income model includes workers")
	_check(_approx(day_3["wood"], 17.0) and _approx(day_3["stone"], 12.0) and _approx(day_3["iron"], 5.75) and _approx(day_3["essence"], 10.0), "Day 3 income model includes scaling enemy counts")
	var cumulative: Dictionary = ECONOMY_BALANCE.expected_cumulative_income(3)
	_check(_approx(cumulative["wood"], 44.0) and _approx(cumulative["stone"], 31.0) and _approx(cumulative["iron"], 15.20) and _approx(cumulative["essence"], 27.0), "three-night cumulative economy is bounded")
	_check(ECONOMY_BALANCE.worker_income(4) == {"wood": 4, "stone": 2, "iron": 1}, "workers have a measurable but finite income role")
	_check(ECONOMY_BALANCE.expected_cumulative_income(3, 4, 3)["food"] == 6.0, "a level 1 Farm pays back six food opportunities before the run ends")
	_check(ECONOMY_BALANCE.house_capacity_for_level(1) == 3 and ECONOMY_BALANCE.farm_income_for_level(1) == 3, "House and Farm have immediate useful output")

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
	var full_run_investment_cost: Dictionary = full_opening_cost
	for kind: String in ["house", "farm", "barracks", "blacksmith"]:
		full_run_investment_cost = _merge_costs(full_run_investment_cost, ECONOMY_BALANCE.village_upgrade_cost(kind, 2))
		full_run_investment_cost = _merge_costs(full_run_investment_cost, ECONOMY_BALANCE.village_upgrade_cost(kind, 3))
	for _kind: String in ["archer", "barricade", "ballista"]:
		full_run_investment_cost = _merge_costs(full_run_investment_cost, ECONOMY_BALANCE.defense_upgrade_cost(2))
		full_run_investment_cost = _merge_costs(full_run_investment_cost, ECONOMY_BALANCE.defense_upgrade_cost(3))
	_check(not _can_afford(cumulative, full_run_investment_cost), "cumulative income cannot max every important structure in one run")
	_check(
		ECONOMY_BALANCE.rescue_food_cost() == 1
			and ECONOMY_BALANCE.shrine_cost("heal")["essence"] == 1
			and ECONOMY_BALANCE.shrine_cost("blessing")["essence"] == 2
			and ECONOMY_BALANCE.shrine_cost("ward")["essence"] == 3,
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

	_check(main._defense_build_definition("archer")["cost"] == ECONOMY_BALANCE.defense_definition("archer")["cost"], "defense UI definition uses central balance data")
	_check(main._village_build_definition("blacksmith")["cost"] == ECONOMY_BALANCE.village_definition("blacksmith")["cost"], "village UI definition uses central balance data")
	_check(main._village_upgrade_cost("blacksmith", 3) == ECONOMY_BALANCE.village_upgrade_cost("blacksmith", 3), "upgrade UI and charging use the same level cost")
	_check(main.get_node("DayEnemies").get_child_count() == 8, "central enemy-count data preserves the first-day plan")
	_check(_day_enemy_rewards_are_central(main), "day enemy rewards come from central balance data")

	_check(_authored_pickup_counts_match_balance(main, pickup_counts), "authored resource markers match the centralized economy plan")
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


func _authored_pickup_counts_match_balance(main: Node2D, expected: Dictionary) -> bool:
	var actual: Dictionary = {"forest": {}, "mine": {}, "ruins": {}}
	for entry: Dictionary in main.world_visuals.get_resource_layout(17, 1):
		var zone: String = str(entry["zone"])
		var resource_name: String = str(entry["type"])
		actual[zone][resource_name] = int(actual[zone].get(resource_name, 0)) + 1
	return actual == expected


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


func _approx(value: float, expected: float) -> bool:
	return is_equal_approx(value, expected)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		print("FAIL: %s" % description)
