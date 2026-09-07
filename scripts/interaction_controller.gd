extends Node
class_name GloamInteractionController

## Finds the single deterministic world interaction target for the player.
## Menu contents and transactions stay with the gameplay root and the
## contextual menu, while this controller owns overlap resolution.

var player_actor: GloamPlayer
var build_spots_root: Node
var village_build_spots_root: Node
var shrines_root: Node
var gates_root: Node
var walls_root: Node
var can_act: Callable
var is_day: Callable
var menu_is_open: Callable
var contextual_menu: GloamContextualInteractionMenu
var settlement_state: GloamSettlementState
var construction_manager: GloamConstructionManager
var shrine_manager: GloamShrineManager
var execute_choice: Callable
var sync_target: Callable
var refresh_target: Callable
var play_audio: Callable
var menu_open: bool = false
var selection_latched: bool = false
var current_target: Node2D = null

const ECONOMY_BALANCE := preload("res://scripts/economy_balance.gd")


func configure(
	player: GloamPlayer,
	build_spots: Node,
	village_build_spots: Node,
	shrines: Node,
	gates: Node,
	walls: Node,
	can_act_check: Callable,
	day_check: Callable,
	menu_open_check: Callable,
	menu: GloamContextualInteractionMenu,
	state: GloamSettlementState,
	construction: GloamConstructionManager,
	shrine: GloamShrineManager,
	choice_executor: Callable,
	target_sync: Callable,
	target_refresh: Callable,
	audio_callback: Callable
) -> void:
	player_actor = player
	build_spots_root = build_spots
	village_build_spots_root = village_build_spots
	shrines_root = shrines
	gates_root = gates
	walls_root = walls
	can_act = can_act_check
	is_day = day_check
	menu_is_open = menu_open_check
	contextual_menu = menu
	settlement_state = state
	construction_manager = construction
	shrine_manager = shrine
	execute_choice = choice_executor
	sync_target = target_sync
	refresh_target = target_refresh
	play_audio = audio_callback
	contextual_menu.prompt_pressed.connect(_on_prompt_pressed)
	contextual_menu.choice_selected.connect(_on_choice_selected)
	contextual_menu.closed.connect(_on_menu_closed)


func find_target(active_shrine: GloamShrine = null) -> Node2D:
	if not _can_update():
		return null

	var best_target: Node2D = null
	var best_distance: float = INF
	var best_priority: int = 999

	for spot: Node in build_spots_root.get_children():
		var candidate: Node2D = spot as Node2D
		if not _inside(candidate):
			continue
		var candidate_distance: float = player_actor.global_position.distance_to(candidate.global_position)
		if _is_better(candidate_distance, 20, best_distance, best_priority):
			best_target = candidate
			best_distance = candidate_distance
			best_priority = 20

	for spot: Node in village_build_spots_root.get_children():
		var candidate: Node2D = spot as Node2D
		if not _inside(candidate):
			continue
		var candidate_distance: float = player_actor.global_position.distance_to(candidate.global_position)
		if _is_better(candidate_distance, 30, best_distance, best_priority):
			best_target = candidate
			best_distance = candidate_distance
			best_priority = 30

	var shrine_candidate: GloamShrine = active_shrine
	if not is_instance_valid(shrine_candidate):
		for shrine_node: Node in shrines_root.get_children():
			var shrine: GloamShrine = shrine_node as GloamShrine
			if _inside(shrine):
				shrine_candidate = shrine
				break
	if is_instance_valid(shrine_candidate) and _inside(shrine_candidate):
		var shrine_distance: float = player_actor.global_position.distance_to(shrine_candidate.global_position)
		if _is_better(shrine_distance, 10, best_distance, best_priority):
			best_target = shrine_candidate
			best_distance = shrine_distance
			best_priority = 10

	var nearest_fortification: Node2D = null
	var nearest_fortification_distance: float = 72.0
	for fortification_root: Node in [gates_root, walls_root]:
		for fortification_node: Node in fortification_root.get_children():
			var fortification: Node2D = fortification_node as Node2D
			if not is_instance_valid(fortification):
				continue
			var fortification_distance: float = player_actor.global_position.distance_to(fortification.global_position)
			if fortification_distance < nearest_fortification_distance:
				nearest_fortification = fortification
				nearest_fortification_distance = fortification_distance
	if is_instance_valid(nearest_fortification) and _is_better(
		nearest_fortification_distance, 15, best_distance, best_priority
	):
		best_target = nearest_fortification

	return best_target


func open_menu(target: Node2D) -> bool:
	if menu_open or not _can_update() or not _is_valid_target(target):
		return false
	var choices: Array[Dictionary] = choices_for(target)
	if choices.is_empty():
		return false
	if sync_target.is_valid():
		sync_target.call(target)
	current_target = target
	menu_open = true
	selection_latched = false
	contextual_menu.open_menu(
		_context_menu_title(target),
		"Choose one action. Costs are charged once when selected.",
		choices
	)
	get_tree().paused = true
	return true


func close_menu(update_target: bool = true) -> void:
	var was_open: bool = menu_open
	menu_open = false
	selection_latched = false
	current_target = null
	if is_instance_valid(contextual_menu):
		contextual_menu.close_menu(false)
	if was_open and get_tree().paused:
		get_tree().paused = false
	if update_target and refresh_target.is_valid():
		refresh_target.call()


func _on_prompt_pressed() -> void:
	# The composition root selects the target each frame; its wrapper supplies
	# the current target without letting a stale overlapping zone be reused.
	var target: Node2D = find_target()
	if sync_target.is_valid() and is_instance_valid(target):
		sync_target.call(target)
	open_menu(target)


func _on_choice_selected(choice_id: String) -> void:
	if not menu_open or selection_latched:
		return
	var target: Node2D = _current_target()
	if not _is_valid_target(target):
		close_menu(false)
		return
	selection_latched = true
	if sync_target.is_valid():
		sync_target.call(target)
	var succeeded: bool = execute_choice.is_valid() and bool(execute_choice.call(choice_id))
	if succeeded:
		_call(play_audio, "ui_confirm", target.global_position, 0.85)
		close_menu()
	elif not _can_act_now():
		close_menu(false)
	else:
		_call(play_audio, "ui_error", target.global_position, 0.75)
		contextual_menu.allow_choice_retry()
		selection_latched = false
		contextual_menu.open_menu(
			_context_menu_title(target),
			"Choose one action. Costs are charged once when selected.",
			choices_for(target)
		)


func _on_menu_closed() -> void:
	close_menu(false)


func _current_target() -> Node2D:
	return current_target


func _can_act_now() -> bool:
	return can_act.is_valid() and bool(can_act.call()) and is_day.is_valid() and bool(is_day.call())


func _is_valid_target(target: Node2D) -> bool:
	if not is_instance_valid(target) or not _can_act_now():
		return false
	if target is GloamBuildSpot or target is GloamVillageBuildSpot or target is GloamShrine:
		return target.get("player_inside") == true
	if target.is_in_group("gates") or target.is_in_group("walls"):
		return player_actor.global_position.distance_to(target.global_position) < 72.0
	return true


func _context_menu_title(target: Node2D) -> String:
	if target is GloamBuildSpot:
		return "DEFENSE SPOT"
	if target is GloamVillageBuildSpot:
		return "VILLAGE SPOT"
	if target is GloamShrine:
		return "RUIN SHRINE"
	if target.is_in_group("gates"):
		return str(target.get("gate_name")).to_upper()
	if target.is_in_group("walls"):
		return str(target.get("wall_name")).to_upper()
	return "INTERACTION"


func choices_for(target: Node2D) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	if not is_instance_valid(target):
		return choices
	if target is GloamBuildSpot:
		if target.occupied and not is_instance_valid(target.structure):
			return choices
		if target.occupied:
			var defense: GloamDefense = target.structure as GloamDefense
			var repair_cost: Dictionary = construction_manager.defense_repair_cost()
			var repair_enabled: bool = defense.hp < defense.max_hp
			choices.append(_make_choice("repair_defense", "Repair", repair_cost, "Restore %s to full HP" % defense.defense_name, repair_enabled and _has_cost(repair_cost), "Already at full HP" if not repair_enabled else _requirement_text(repair_cost)))
			var upgrade_cost: Dictionary = construction_manager.defense_upgrade_cost(defense.level + 1)
			var upgrade_enabled: bool = defense.can_upgrade()
			choices.append(_make_choice("upgrade_defense", "Upgrade", upgrade_cost, "Increase defensive strength and maximum HP", upgrade_enabled and _has_cost(upgrade_cost), "Maximum level reached" if not upgrade_enabled else _requirement_text(upgrade_cost)))
			return choices
		for kind: String in ["archer", "barricade", "ballista"]:
			var definition: Dictionary = construction_manager.defense_build_definition(kind)
			choices.append(_make_choice("build_%s" % kind, str(definition["title"]), definition["cost"], str(definition["effect"]), _has_cost(definition["cost"]), _requirement_text(definition["cost"])))
		return choices

	if target is GloamVillageBuildSpot:
		if target.occupied and not is_instance_valid(target.building):
			return choices
		if target.occupied:
			var building: GloamVillageBuilding = target.building as GloamVillageBuilding
			var repair_cost: Dictionary = construction_manager.village_repair_cost()
			var repair_enabled: bool = building.hp < building.max_hp
			choices.append(_make_choice("repair_village_building", "Repair", repair_cost, "Restore %s to full HP" % building.display_name, repair_enabled and _has_cost(repair_cost), "Already at full HP" if not repair_enabled else _requirement_text(repair_cost)))
			var upgrade_cost: Dictionary = construction_manager.village_upgrade_cost(building.building_type, building.level + 1)
			var upgrade_enabled: bool = building.can_upgrade()
			choices.append(_make_choice("upgrade_village_building", "Upgrade", upgrade_cost, "Improve this building's level and output", upgrade_enabled and _has_cost(upgrade_cost), "Maximum level reached" if not upgrade_enabled else _requirement_text(upgrade_cost)))
			return choices
		for kind: String in ["house", "farm", "barracks", "blacksmith"]:
			var definition: Dictionary = construction_manager.village_build_definition(kind)
			var enabled: bool = _has_cost(definition["cost"])
			var reason: String = _requirement_text(definition["cost"])
			if kind == "barracks" and settlement_state.get("barracks_built") == true:
				enabled = false
				reason = "Only one Barracks can be built"
			elif kind == "blacksmith" and settlement_state.get("blacksmith_built") == true:
				enabled = false
				reason = "Only one Blacksmith can be built"
			choices.append(_make_choice("build_%s" % kind, str(definition["title"]), definition["cost"], str(definition["effect"]), enabled, reason))
		return choices

	if target is GloamShrine:
		var heal_cost: Dictionary = ECONOMY_BALANCE.shrine_cost("heal")
		var blessing_cost: Dictionary = ECONOMY_BALANCE.shrine_cost("blessing")
		var ward_cost: Dictionary = ECONOMY_BALANCE.shrine_cost("ward")
		var heal_enabled: bool = _has_cost(heal_cost) and player_actor.hp < player_actor.max_hp
		choices.append(_make_choice("shrine_heal", "Mend Flesh", heal_cost, "Restore the hero to full health (not a respawn)", heal_enabled, "Already at full health" if player_actor.hp >= player_actor.max_hp else _requirement_text(heal_cost)))
		choices.append(_make_choice("shrine_blessing", "Wild Blessing", blessing_cost, "Gain a random elemental boon", _has_cost(blessing_cost), _requirement_text(blessing_cost)))
		var ward_enabled: bool = _has_cost(ward_cost) and shrine_manager.active_ward_bonus <= 0
		choices.append(_make_choice("shrine_ward", "Ward Village", ward_cost, "Increase fortification HP by %d%% for the next night" % ECONOMY_BALANCE.SHRINE_WARD_FORTIFICATION_BONUS, ward_enabled, "Already active for tonight" if shrine_manager.active_ward_bonus > 0 else _requirement_text(ward_cost)))
		return choices

	if target.is_in_group("gates") or target.is_in_group("walls"):
		var fortification_repair_cost: Dictionary = construction_manager.fortification_repair_cost(target)
		var fortification_repair_enabled: bool = int(target.get("hp")) < int(target.get("max_hp")) or target.get("is_breached") == true
		choices.append(_make_choice("repair_fortification", "Repair / Rebuild", fortification_repair_cost, "Restore this gate or wall to full HP", fortification_repair_enabled and _has_cost(fortification_repair_cost), "Already at full HP" if not fortification_repair_enabled else _requirement_text(fortification_repair_cost)))
		var fortification_upgrade_cost: Dictionary = construction_manager.fortification_upgrade_cost(target)
		var fortification_upgrade_enabled: bool = bool(target.call("can_upgrade"))
		var fortification_reason: String = _requirement_text(fortification_upgrade_cost)
		if target.get("is_breached") == true:
			fortification_upgrade_enabled = false
			fortification_reason = "Repair before upgrading"
		elif not fortification_upgrade_enabled:
			fortification_reason = "Maximum level reached"
		choices.append(_make_choice("upgrade_fortification", "Upgrade", fortification_upgrade_cost, "Increase fortification strength and maximum HP", fortification_upgrade_enabled and _has_cost(fortification_upgrade_cost), fortification_reason))
	return choices


func _make_choice(choice_id: String, title: String, cost: Dictionary, effect: String, enabled: bool, reason: String) -> Dictionary:
	var availability: String = "AVAILABLE" if enabled else "UNAVAILABLE • %s" % reason
	var text: String = "%s\nCost: %s  •  Effect: %s\n%s" % [title, _cost_text(cost), effect, availability]
	return {"id": choice_id, "text": text, "enabled": enabled, "tooltip": text}


func _has_cost(cost: Dictionary) -> bool:
	return bool(settlement_state.call("can_afford", cost))


func _requirement_text(cost: Dictionary) -> String:
	var missing: Array[String] = []
	for resource_name: String in ECONOMY_BALANCE.RESOURCE_ORDER:
		var required: int = int(cost.get(resource_name, 0))
		var available: int = int(settlement_state.call("resource_amount", resource_name))
		if required > available:
			missing.append("%d more %s" % [required - available, resource_name.capitalize()])
	return "Available" if missing.is_empty() else "Need %s" % ", ".join(missing)


func _cost_text(cost: Dictionary) -> String:
	return ECONOMY_BALANCE.cost_text(cost)


func _call(
	callback: Callable,
	argument_1: Variant = null,
	argument_2: Variant = null,
	argument_3: Variant = null
) -> void:
	if not callback.is_valid():
		return
	if argument_3 != null:
		callback.call(argument_1, argument_2, argument_3)
	elif argument_2 != null:
		callback.call(argument_1, argument_2)
	elif argument_1 != null:
		callback.call(argument_1)
	else:
		callback.call()


func _can_update() -> bool:
	return (
		can_act.is_valid()
		and bool(can_act.call())
		and is_day.is_valid()
		and bool(is_day.call())
		and (not menu_is_open.is_valid() or not bool(menu_is_open.call()))
	)


func _inside(candidate: Node2D) -> bool:
	return is_instance_valid(candidate) and candidate.get("player_inside") == true


func _is_better(
	candidate_distance: float,
	candidate_priority: int,
	best_distance: float,
	best_priority: int
) -> bool:
	return (
		candidate_distance < best_distance - 0.1
		or (absf(candidate_distance - best_distance) <= 0.1 and candidate_priority < best_priority)
	)
