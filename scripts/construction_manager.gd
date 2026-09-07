extends Node
class_name GloamConstructionManager

## Owns construction transactions and infrastructure-derived effects.
##
## The manager receives scene references and UI Callables from the composition
## root, but it owns no phase, camera, or modal state.  All prices come from
## EconomyBalance and every successful transaction is followed by a derived
## settlement recalculation.

signal state_changed
signal building_destroyed(building: GloamVillageBuilding, released_spot: GloamVillageBuildSpot)

const ECONOMY_BALANCE := preload("res://scripts/economy_balance.gd")

var settlement_state: GloamSettlementState
var player_actor: GloamPlayer
var soldiers_root: Node
var defenses_root: Node
var village_buildings_root: Node
var village_build_spots_root: Node
var defense_prompt: Label
var village_prompt: Label
var defense_scenes: Dictionary = {}
var village_scenes: Dictionary = {}

var can_act: Callable
var is_day: Callable
var show_toast: Callable
var refresh_resources: Callable
var refresh_population: Callable
var refresh_buildings: Callable
var play_audio: Callable

var active_build_spot: GloamBuildSpot = null
var active_village_build_spot: GloamVillageBuildSpot = null


func configure(
	state: GloamSettlementState,
	player: GloamPlayer,
	soldiers: Node,
	defenses: Node,
	village_buildings: Node,
	village_build_spots: Node,
	defense_prompt_control: Label,
	village_prompt_control: Label,
	defense_scene_map: Dictionary,
	village_scene_map: Dictionary,
	can_act_check: Callable,
	day_check: Callable,
	toast_callback: Callable,
	resource_refresh: Callable,
	population_refresh: Callable,
	building_refresh: Callable,
	audio_callback: Callable
) -> void:
	settlement_state = state
	player_actor = player
	soldiers_root = soldiers
	defenses_root = defenses
	village_buildings_root = village_buildings
	village_build_spots_root = village_build_spots
	defense_prompt = defense_prompt_control
	village_prompt = village_prompt_control
	defense_scenes = defense_scene_map
	village_scenes = village_scene_map
	can_act = can_act_check
	is_day = day_check
	show_toast = toast_callback
	refresh_resources = resource_refresh
	refresh_population = population_refresh
	refresh_buildings = building_refresh
	play_audio = audio_callback


func set_active_build_spot(spot: GloamBuildSpot) -> void:
	active_build_spot = spot


func clear_active_build_spot(spot: GloamBuildSpot) -> void:
	if active_build_spot == spot:
		active_build_spot = null


func set_active_village_build_spot(spot: GloamVillageBuildSpot) -> void:
	active_village_build_spot = spot


func clear_active_village_build_spot(spot: GloamVillageBuildSpot) -> void:
	if active_village_build_spot == spot:
		active_village_build_spot = null


func defense_build_definition(kind: String) -> Dictionary:
	var definition: Dictionary = ECONOMY_BALANCE.defense_definition(kind)
	if definition.is_empty():
		return definition
	if defense_scenes.has(kind):
		definition["scene"] = defense_scenes[kind]
	return definition


func village_build_definition(kind: String) -> Dictionary:
	var definition: Dictionary = ECONOMY_BALANCE.village_definition(kind)
	if definition.is_empty():
		return definition
	if village_scenes.has(kind):
		definition["scene"] = village_scenes[kind]
	return definition


func fortification_repair_cost(fortification: Node2D) -> Dictionary:
	if fortification.is_in_group("gates"):
		return ECONOMY_BALANCE.defense_repair_cost(true, bool(fortification.get("is_breached")))
	return ECONOMY_BALANCE.defense_repair_cost(false, bool(fortification.get("is_breached")))


func fortification_upgrade_cost(fortification: Node2D) -> Dictionary:
	return ECONOMY_BALANCE.fortification_upgrade_cost(
		fortification.is_in_group("gates"),
		int(fortification.get("level")) + 1
	)


func defense_repair_cost() -> Dictionary:
	return ECONOMY_BALANCE.defense_repair_cost(false, false)


func defense_upgrade_cost(next_level: int = 2) -> Dictionary:
	return ECONOMY_BALANCE.defense_upgrade_cost(next_level)


func village_repair_cost() -> Dictionary:
	return ECONOMY_BALANCE.village_repair_cost()


func village_upgrade_cost(kind: String, next_level: int = 2) -> Dictionary:
	return ECONOMY_BALANCE.village_upgrade_cost(kind, next_level)


func try_build(kind: String) -> bool:
	if not _can_construct() or not is_instance_valid(active_build_spot) or active_build_spot.occupied:
		return false

	var definition: Dictionary = defense_build_definition(kind)
	if definition.is_empty():
		return false
	var cost: Dictionary = definition["cost"]
	if not _has_cost(cost):
		_set_prompt_text("defense", "NOT ENOUGH RESOURCES")
		_call(show_toast, "Not enough resources", "warning")
		return false
	_charge(cost)

	var defense: GloamDefense = (definition["scene"] as PackedScene).instantiate() as GloamDefense
	defense.global_position = active_build_spot.global_position
	defenses_root.add_child(defense)
	active_build_spot.assign_structure(defense, kind)
	active_build_spot = null
	_rebuild_state()
	_call(refresh_resources)
	_call(show_toast, "%s built" % kind.to_upper(), "success")
	return true


func try_build_village_building(kind: String) -> bool:
	if not _can_construct() or not is_instance_valid(active_village_build_spot) or active_village_build_spot.occupied:
		return false

	var definition: Dictionary = village_build_definition(kind)
	if definition.is_empty():
		return false
	if (kind == "barracks" and settlement_state.get("barracks_built") == true) or (kind == "blacksmith" and settlement_state.get("blacksmith_built") == true):
		_set_prompt_text("village", "%s ALREADY BUILT" % str(definition["title"]).to_upper())
		_call(show_toast, "That building is already built", "warning")
		return false
	var cost: Dictionary = definition["cost"]
	if not _has_cost(cost):
		_set_prompt_text("village", "NOT ENOUGH RESOURCES")
		_call(show_toast, "Not enough resources", "warning")
		return false
	_charge(cost)

	var building: GloamVillageBuilding = (definition["scene"] as PackedScene).instantiate() as GloamVillageBuilding
	building.global_position = active_village_build_spot.global_position
	building.destroyed.connect(_on_village_building_destroyed)
	village_buildings_root.add_child(building)
	active_village_build_spot.assign_building(building, kind)
	active_village_build_spot = null
	_rebuild_state()
	_call(refresh_resources)
	_call(refresh_population)
	_call(refresh_buildings)
	_call(show_toast, "%s built" % kind.to_upper(), "success")
	return true


func repair_fortification() -> bool:
	if not _can_construct() or not is_instance_valid(active_build_spot) or not active_build_spot.occupied:
		return false
	var defense: GloamDefense = active_build_spot.structure as GloamDefense
	if not is_instance_valid(defense):
		return false
	if defense.hp >= defense.max_hp:
		_set_prompt_text("defense", "%s is already fully repaired." % defense.defense_name)
		_call(show_toast, "Already at full health", "info")
		return false
	var cost: Dictionary = defense_repair_cost()
	if not _has_cost(cost):
		_set_prompt_text("defense", "NOT ENOUGH RESOURCES FOR REPAIR")
		_call(show_toast, "Not enough resources to repair", "warning")
		return false
	_charge(cost)
	defense.repair_full()
	_call(refresh_resources)
	refresh_defense_prompt()
	_call(show_toast, "%s repaired" % defense.defense_name, "success")
	return true


func upgrade_fortification() -> bool:
	if not _can_construct() or not is_instance_valid(active_build_spot) or not active_build_spot.occupied:
		return false
	var defense: GloamDefense = active_build_spot.structure as GloamDefense
	if not is_instance_valid(defense):
		return false
	if not defense.can_upgrade():
		_set_prompt_text("defense", "%s IS MAX LEVEL" % defense.defense_name)
		_call(show_toast, "Already at maximum level", "info")
		return false
	var cost: Dictionary = defense_upgrade_cost(defense.level + 1)
	if not _has_cost(cost):
		_set_prompt_text("defense", "NOT ENOUGH RESOURCES FOR UPGRADE")
		_call(show_toast, "Not enough resources to upgrade", "warning")
		return false
	_charge(cost)
	defense.upgrade()
	_call(refresh_resources)
	refresh_defense_prompt()
	_call(show_toast, "%s upgraded to Lv.%d" % [defense.defense_name, defense.level], "success")
	return true


func repair_village_building() -> bool:
	if not _can_construct() or not is_instance_valid(active_village_build_spot) or not active_village_build_spot.occupied:
		return false
	var building: GloamVillageBuilding = active_village_build_spot.building as GloamVillageBuilding
	if not is_instance_valid(building):
		return false
	if building.hp >= building.max_hp:
		_set_prompt_text("village", "%s is already fully repaired." % building.display_name)
		_call(show_toast, "Already at full health", "info")
		return false
	var cost: Dictionary = village_repair_cost()
	if not _has_cost(cost):
		_set_prompt_text("village", "NOT ENOUGH RESOURCES FOR REPAIR")
		_call(show_toast, "Not enough resources to repair", "warning")
		return false
	_charge(cost)
	building.repair_full()
	_call(refresh_resources)
	refresh_village_prompt()
	_call(show_toast, "%s repaired" % building.display_name, "success")
	return true


func upgrade_village_building() -> bool:
	if not _can_construct() or not is_instance_valid(active_village_build_spot) or not active_village_build_spot.occupied:
		return false
	var building: GloamVillageBuilding = active_village_build_spot.building as GloamVillageBuilding
	if not is_instance_valid(building):
		return false
	if not building.can_upgrade():
		_set_prompt_text("village", "%s IS MAX LEVEL" % building.display_name)
		_call(show_toast, "Already at maximum level", "info")
		return false
	var cost: Dictionary = village_upgrade_cost(building.building_type, building.level + 1)
	if not _has_cost(cost):
		_set_prompt_text("village", "NOT ENOUGH RESOURCES FOR UPGRADE")
		_call(show_toast, "Not enough resources to upgrade", "warning")
		return false
	_charge(cost)
	building.upgrade()
	_rebuild_state()
	_call(refresh_resources)
	_call(refresh_population)
	_call(refresh_buildings)
	refresh_village_prompt()
	_call(show_toast, "%s upgraded to Lv.%d" % [building.display_name, building.level], "success")
	return true


func refresh_defense_prompt() -> void:
	if not is_instance_valid(active_build_spot) or not active_build_spot.occupied:
		return
	var defense: GloamDefense = active_build_spot.structure as GloamDefense
	if not is_instance_valid(defense):
		return
	var upgrade_text: String = "MAX LEVEL"
	if defense.can_upgrade():
		upgrade_text = "Upgrade  [%s]" % _cost_text(defense_upgrade_cost(defense.level + 1))
	var prompt: Label = _prompt("defense")
	if is_instance_valid(prompt):
		prompt.text = "%s  Lv.%d\nHP: %d / %d\nRepair   [%s]\n%s" % [
			defense.defense_name,
			defense.level,
			defense.hp,
			defense.max_hp,
			_cost_text(defense_repair_cost()),
			upgrade_text
		]


func refresh_village_prompt() -> void:
	if not is_instance_valid(active_village_build_spot) or not active_village_build_spot.occupied:
		return
	var building: GloamVillageBuilding = active_village_build_spot.building as GloamVillageBuilding
	if not is_instance_valid(building):
		return
	var upgrade_text: String = "MAX LEVEL"
	if building.can_upgrade():
		upgrade_text = "Upgrade  [%s]" % _cost_text(village_upgrade_cost(building.building_type, building.level + 1))
	var prompt: Label = _prompt("village")
	if is_instance_valid(prompt):
		prompt.text = "%s  Lv.%d\nHP: %d / %d\nRepair   [%s]\n%s" % [
			building.display_name,
			building.level,
			building.hp,
			building.max_hp,
			_cost_text(village_repair_cost()),
			upgrade_text
		]


func handle_village_building_destroyed(building: GloamVillageBuilding) -> void:
	_on_village_building_destroyed(building)


func _on_village_building_destroyed(building: GloamVillageBuilding) -> void:
	if not is_instance_valid(building):
		return
	var released_spot: GloamVillageBuildSpot = null
	for child: Node in village_build_spots_root.get_children():
		var spot: GloamVillageBuildSpot = child as GloamVillageBuildSpot
		if is_instance_valid(spot) and spot.building == building:
			released_spot = spot
			break
	_rebuild_state(building)
	building_destroyed.emit(building, released_spot)


func recalculate(destroyed_building: GloamVillageBuilding = null) -> void:
	_rebuild_state(destroyed_building)


func _rebuild_state(destroyed_building: GloamVillageBuilding = null) -> void:
	var buildings: Array[Node] = []
	for child: Node in village_buildings_root.get_children():
		if child != destroyed_building:
			buildings.append(child)
	settlement_state.call("recalculate_from_buildings", buildings, ECONOMY_BALANCE.BASE_POPULATION_CAPACITY)
	player_actor.set_settlement_damage_bonus(int(settlement_state.get("blacksmith_bonus_damage")))
	var soldier_bonus: int = int(settlement_state.get("blacksmith_bonus_damage")) + int(settlement_state.get("barracks_training_bonus"))
	for soldier: Node in soldiers_root.get_children():
		if soldier.has_method("set_infrastructure_damage_bonus"):
			soldier.call("set_infrastructure_damage_bonus", soldier_bonus)
	state_changed.emit()


func _can_construct() -> bool:
	return can_act.is_valid() and bool(can_act.call()) and is_day.is_valid() and bool(is_day.call())


func _has_cost(cost: Dictionary) -> bool:
	return bool(settlement_state.call("can_afford", cost))


func _charge(cost: Dictionary) -> void:
	settlement_state.call("charge", cost)


func _cost_text(cost: Dictionary) -> String:
	return ECONOMY_BALANCE.cost_text(cost)


func _prompt(kind: String) -> Label:
	return defense_prompt if kind == "defense" else village_prompt


func _set_prompt_text(kind: String, text: String) -> void:
	var prompt: Label = _prompt(kind)
	if is_instance_valid(prompt):
		prompt.text = text


func _call(callback: Callable, argument_1: Variant = null, argument_2: Variant = null) -> void:
	if not callback.is_valid():
		return
	if argument_2 != null:
		callback.call(argument_1, argument_2)
	elif argument_1 != null:
		callback.call(argument_1)
	else:
		callback.call()
