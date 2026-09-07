extends RefCounted
class_name GloamSettlementState

## Authoritative run economy, infrastructure, and population state.
##
## This object contains no scene references.  It derives infrastructure output
## from the live building list and exposes resource transactions to the scene
## controller, so UI and gameplay can use the same values.

signal changed

const ECONOMY_BALANCE := preload("res://scripts/economy_balance.gd")

var wood: int = 0
var stone: int = 0
var iron: int = 0
var food: int = ECONOMY_BALANCE.STARTING_FOOD
var essence: int = 0

var houses: int = 0
var farms: int = 0
var farm_food_income: int = 0
var barracks_built: bool = false
var barracks_training_bonus: int = 0
var blacksmith_built: bool = false
var blacksmith_bonus_damage: int = 0

var total_population: int = ECONOMY_BALANCE.STARTING_POPULATION
var unassigned_villagers: int = 0
var workers: int = ECONOMY_BALANCE.STARTING_WORKERS
var guards: int = 0
var archers: int = 0
var population_capacity: int = ECONOMY_BALANCE.BASE_POPULATION_CAPACITY


func resource_amount(resource_name: String) -> int:
	match resource_name:
		"wood":
			return wood
		"stone":
			return stone
		"iron":
			return iron
		"food":
			return food
		"essence":
			return essence
	return 0


func can_afford(cost: Dictionary) -> bool:
	for resource_name: String in ECONOMY_BALANCE.RESOURCE_ORDER:
		if resource_amount(resource_name) < int(cost.get(resource_name, 0)):
			return false
	return true


func charge(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	wood = maxi(0, wood - int(cost.get("wood", 0)))
	stone = maxi(0, stone - int(cost.get("stone", 0)))
	iron = maxi(0, iron - int(cost.get("iron", 0)))
	food = maxi(0, food - int(cost.get("food", 0)))
	essence = maxi(0, essence - int(cost.get("essence", 0)))
	changed.emit()
	return true


func grant(resource_name: String, amount: int) -> bool:
	if amount <= 0:
		return false
	match resource_name:
		"wood":
			wood += amount
		"stone":
			stone += amount
		"iron":
			iron += amount
		"food":
			food += amount
		"essence":
			essence += amount
		_:
			return false
	changed.emit()
	return true


func apply_worker_income() -> void:
	var income: Dictionary = ECONOMY_BALANCE.worker_income(workers)
	wood += maxi(0, int(income.get("wood", 0)))
	stone += maxi(0, int(income.get("stone", 0)))
	iron += maxi(0, int(income.get("iron", 0)))
	food += maxi(0, farm_food_income)
	changed.emit()


func recalculate_from_buildings(buildings: Array[Node], base_capacity: int) -> void:
	var active_houses: int = 0
	var active_farms: int = 0
	var derived_house_capacity: int = 0
	var derived_farm_income: int = 0
	var highest_barracks_level: int = 0
	var highest_blacksmith_level: int = 0

	for child: Node in buildings:
		var building: GloamVillageBuilding = child as GloamVillageBuilding
		if not is_instance_valid(building):
			continue
		if building.is_queued_for_deletion() or building.hp <= 0:
			continue

		var level: int = maxi(1, building.level)
		match building.building_type:
			"house":
				active_houses += 1
				derived_house_capacity += ECONOMY_BALANCE.house_capacity_for_level(level)
			"farm":
				active_farms += 1
				derived_farm_income += ECONOMY_BALANCE.farm_income_for_level(level)
			"barracks":
				highest_barracks_level = maxi(highest_barracks_level, level)
			"blacksmith":
				highest_blacksmith_level = maxi(highest_blacksmith_level, level)

	houses = maxi(0, active_houses)
	farms = maxi(0, active_farms)
	farm_food_income = maxi(0, derived_farm_income)
	barracks_built = highest_barracks_level > 0
	barracks_training_bonus = ECONOMY_BALANCE.barracks_training_bonus_for_level(highest_barracks_level)
	blacksmith_built = highest_blacksmith_level > 0
	blacksmith_bonus_damage = ECONOMY_BALANCE.blacksmith_damage_bonus_for_level(highest_blacksmith_level)
	total_population = maxi(0, total_population)
	population_capacity = maxi(base_capacity + maxi(0, derived_house_capacity), total_population)
	changed.emit()
