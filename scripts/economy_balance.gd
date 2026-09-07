extends RefCounted
class_name GloamEconomyBalance

## Economy data is kept independent of the phase controller so balance tuning
## changes one source of truth for charging, UI descriptions, and projections.

const RESOURCE_ORDER: Array[String] = ["wood", "stone", "iron", "essence"]

const PREDICTABLE_PICKUP_COUNTS: Dictionary = {
	"forest": {"wood": 8},
	"mine": {"stone": 5, "iron": 3},
	"ruins": {"essence": 6},
}

const BASE_POPULATION_CAPACITY: int = 6
const STARTING_FOOD: int = 3
const STARTING_POPULATION: int = 4
const STARTING_WORKERS: int = 4
const RESCUE_FOOD_COST: int = 1

const DAY_ENEMY_BASE_COUNTS: Dictionary = {
	"forest": 3,
	"mine": 3,
	"ruins": 2,
}

const DAY_ENEMY_REWARDS: Dictionary = {
	"forest": {
		"resource": "wood",
		"amount": 1,
		"bonus_resource": "",
		"bonus_chance": 0.0,
	},
	"mine": {
		"resource": "stone",
		"amount": 1,
		"bonus_resource": "iron",
		"bonus_chance": 0.35,
	},
	"ruins": {
		"resource": "essence",
		"amount": 1,
		"bonus_resource": "",
		"bonus_chance": 0.0,
	},
}

const DEFENSE_DEFINITIONS: Dictionary = {
	"archer": {
		"title": "Archer Tower",
		"cost": {"wood": 4, "stone": 0, "iron": 0, "essence": 0},
		"effect": "230 range • 1 damage every 0.70s",
	},
	"barricade": {
		"title": "Barricade",
		"cost": {"wood": 2, "stone": 1, "iron": 0, "essence": 0},
		"effect": "160 HP • buys time at the front line",
	},
	"ballista": {
		"title": "Ballista",
		"cost": {"wood": 2, "stone": 1, "iron": 2, "essence": 0},
		"effect": "320 range • 4 damage every 2.20s",
	},
}

const VILLAGE_DEFINITIONS: Dictionary = {
	"house": {
		"title": "House",
		"cost": {"wood": 3, "stone": 0, "iron": 0, "essence": 0},
		"effect": "+3 population capacity",
	},
	"farm": {
		"title": "Farm",
		"cost": {"wood": 2, "stone": 1, "iron": 0, "essence": 0},
		"effect": "+3 food each dawn",
	},
	"barracks": {
		"title": "Barracks",
		"cost": {"wood": 3, "stone": 2, "iron": 0, "essence": 0},
		"effect": "Unlocks Guards and Archers • Lv.2: +1 soldier damage",
	},
	"blacksmith": {
		"title": "Blacksmith",
		"cost": {"wood": 3, "stone": 1, "iron": 2, "essence": 0},
		"effect": "+1 hero and soldier damage • +1 per upgrade",
	},
}

const SHRINE_COSTS: Dictionary = {
	"heal": {"wood": 0, "stone": 0, "iron": 0, "essence": 1},
	"blessing": {"wood": 0, "stone": 0, "iron": 0, "essence": 2},
	"ward": {"wood": 0, "stone": 0, "iron": 0, "essence": 3},
}

const SHRINE_WARD_FORTIFICATION_BONUS: int = 35


static func cost(wood: int, stone: int, iron: int, essence: int = 0) -> Dictionary:
	return {
		"wood": maxi(0, wood),
		"stone": maxi(0, stone),
		"iron": maxi(0, iron),
		"essence": maxi(0, essence),
	}


static func cost_text(value: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_name: String in RESOURCE_ORDER:
		var amount: int = int(value.get(resource_name, 0))
		if amount > 0:
			parts.append("%d %s" % [amount, resource_name.capitalize()])
	return "Free" if parts.is_empty() else " + ".join(parts)


static func defense_definition(kind: String) -> Dictionary:
	return DEFENSE_DEFINITIONS.get(kind, {}).duplicate(true)


static func village_definition(kind: String) -> Dictionary:
	return VILLAGE_DEFINITIONS.get(kind, {}).duplicate(true)


static func shrine_cost(kind: String) -> Dictionary:
	return SHRINE_COSTS.get(kind, {}).duplicate(true)


static func rescue_food_cost() -> int:
	return RESCUE_FOOD_COST


static func day_enemy_count(zone: String, day: int) -> int:
	return maxi(0, int(DAY_ENEMY_BASE_COUNTS.get(zone, 0)) + maxi(0, day - 1))


static func enemy_reward_profile(zone: String) -> Dictionary:
	return DAY_ENEMY_REWARDS.get(zone, {}).duplicate(true)


static func worker_income(worker_count: int) -> Dictionary:
	var workers: int = maxi(0, worker_count)
	return {
		"wood": workers,
		"stone": int(floor(workers / 2.0)),
		"iron": int(floor(workers / 4.0)),
	}


static func house_capacity_for_level(level: int) -> int:
	return 3 + maxi(0, level - 1) * 2


static func farm_income_for_level(level: int) -> int:
	return 3 + maxi(0, level - 1) * 2


static func barracks_training_bonus_for_level(level: int) -> int:
	return maxi(0, level - 1)


static func blacksmith_damage_bonus_for_level(level: int) -> int:
	return maxi(0, level)


static func pickup_counts() -> Dictionary:
	return PREDICTABLE_PICKUP_COUNTS.duplicate(true)


static func defense_repair_cost(is_gate: bool, is_breached: bool) -> Dictionary:
	if is_gate:
		return cost(2, 2 if is_breached else 1, 0)
	return cost(1, 2 if is_breached else 1, 0)


static func fortification_upgrade_cost(is_gate: bool, next_level: int) -> Dictionary:
	if is_gate:
		match next_level:
			2:
				return cost(2, 3, 1)
			3:
				return cost(3, 4, 2)
	else:
		match next_level:
			2:
				return cost(2, 1, 1)
			3:
				return cost(3, 2, 2)
	return cost(0, 0, 0)


static func defense_upgrade_cost(next_level: int) -> Dictionary:
	match next_level:
		2:
			return cost(2, 1, 1)
		3:
			return cost(3, 2, 2)
	return cost(0, 0, 0)


static func village_repair_cost() -> Dictionary:
	return cost(1, 1, 0)


static func village_upgrade_cost(kind: String, next_level: int) -> Dictionary:
	match kind:
		"house", "farm":
			match next_level:
				2:
					return cost(2, 1, 0)
				3:
					return cost(3, 2, 0)
		"barracks":
			match next_level:
				2:
					return cost(2, 2, 1)
				3:
					return cost(3, 3, 2)
		"blacksmith":
			match next_level:
				2:
					return cost(2, 1, 2)
				3:
					return cost(3, 2, 3)
	return cost(0, 0, 0)


static func expected_day_income(
	day: int,
	worker_count: int = STARTING_WORKERS,
	farm_food_income: int = 0,
	enemy_defeat_rate: float = 1.0
) -> Dictionary:
	var result: Dictionary = {
		"wood": 0.0,
		"stone": 0.0,
		"iron": 0.0,
		"essence": 0.0,
		"food": 0.0,
	}
	var defeat_rate: float = clampf(enemy_defeat_rate, 0.0, 1.0)

	for pickup_profile: Dictionary in pickup_counts().values():
		for resource_name: String in pickup_profile:
			result[resource_name] += float(pickup_profile[resource_name])

	for zone: String in DAY_ENEMY_BASE_COUNTS:
		var count: int = day_enemy_count(zone, day)
		var reward: Dictionary = enemy_reward_profile(zone)
		var resource_name: String = str(reward.get("resource", ""))
		if resource_name != "":
			result[resource_name] += float(count * int(reward.get("amount", 0))) * defeat_rate
		var bonus_resource: String = str(reward.get("bonus_resource", ""))
		if bonus_resource != "":
			result[bonus_resource] += float(count) * float(reward.get("bonus_chance", 0.0)) * defeat_rate

	if day > 1:
		var worker_result: Dictionary = worker_income(worker_count)
		for resource_name: String in worker_result:
			result[resource_name] += float(worker_result[resource_name])
		result["food"] += float(maxi(0, farm_food_income))

	return result


static func expected_cumulative_income(
	last_day: int,
	worker_count: int = STARTING_WORKERS,
	farm_food_income: int = 0,
	enemy_defeat_rate: float = 1.0
) -> Dictionary:
	var result: Dictionary = {
		"wood": 0.0,
		"stone": 0.0,
		"iron": 0.0,
		"essence": 0.0,
		"food": 0.0,
	}
	for day: int in range(1, maxi(0, last_day) + 1):
		var day_result: Dictionary = expected_day_income(
			day,
			worker_count,
			farm_food_income,
			enemy_defeat_rate
		)
		for resource_name: String in result:
			result[resource_name] += float(day_result.get(resource_name, 0.0))
	return result
