extends Node
class_name GloamShrineManager

## Owns shrine purchases and the one-shot ward applied at night start.

const ECONOMY_BALANCE := preload("res://scripts/economy_balance.gd")

var settlement_state: GloamSettlementState
var player_actor: GloamPlayer
var shrine_root: Node
var gates_root: Node
var walls_root: Node
var shrine_scene: PackedScene
var shrine_prompt: Label
var active_ward_bonus: int = 0

var can_act: Callable
var show_toast: Callable
var set_objective: Callable
var refresh_resources: Callable
var refresh_prompt: Callable


func configure(
	state: GloamSettlementState,
	player: GloamPlayer,
	shrines: Node,
	gates: Node,
	walls: Node,
	shrine_scene_resource: PackedScene,
	prompt_control: Label,
	can_act_check: Callable,
	toast_callback: Callable,
	objective_callback: Callable,
	resource_refresh: Callable,
	prompt_refresh: Callable
) -> void:
	settlement_state = state
	player_actor = player
	shrine_root = shrines
	gates_root = gates
	walls_root = walls
	shrine_scene = shrine_scene_resource
	shrine_prompt = prompt_control
	can_act = can_act_check
	show_toast = toast_callback
	set_objective = objective_callback
	refresh_resources = resource_refresh
	refresh_prompt = prompt_refresh


func spawn_shrine() -> GloamShrine:
	var shrine: GloamShrine = shrine_scene.instantiate() as GloamShrine
	shrine.position = Vector2(1780, 360)
	shrine_root.add_child(shrine)
	return shrine


func refresh() -> void:
	if not is_instance_valid(shrine_prompt):
		return
	shrine_prompt.text = (
		"RUIN SHRINE\n"
		+ "Essence: %d\n"
		+ "Mend Flesh    [%s]  Full heal (not respawn)\n"
		+ "Wild Blessing [%s]  Random elemental boon\n"
		+ "Ward Village  [%s]  +%d%% fortification HP tonight"
	) % [
		int(settlement_state.get("essence")),
		_cost_text(ECONOMY_BALANCE.shrine_cost("heal")),
		_cost_text(ECONOMY_BALANCE.shrine_cost("blessing")),
		_cost_text(ECONOMY_BALANCE.shrine_cost("ward")),
		ECONOMY_BALANCE.SHRINE_WARD_FORTIFICATION_BONUS,
	]


func buy_heal() -> bool:
	if not _can_use():
		return false
	var cost: Dictionary = ECONOMY_BALANCE.shrine_cost("heal")
	if not _has_cost(cost):
		_set_prompt("NOT ENOUGH ESSENCE")
		_call(show_toast, "Not enough Essence", "warning")
		return false
	if player_actor.hp >= player_actor.max_hp:
		_set_prompt("You are already at full health.")
		_call(show_toast, "Already at full health", "info")
		return false
	_charge(cost)
	player_actor.heal_full()
	_refresh_after_purchase()
	_call(show_toast, "Health restored", "success")
	return true


func buy_blessing(random_source: RandomNumberGenerator) -> bool:
	if not _can_use():
		return false
	var cost: Dictionary = ECONOMY_BALANCE.shrine_cost("blessing")
	if not _has_cost(cost):
		_set_prompt("NOT ENOUGH ESSENCE")
		_call(show_toast, "Not enough Essence", "warning")
		return false
	_charge(cost)
	var element_name: String = player_actor.apply_random_elemental_blessing(random_source)
	_call(set_objective, "Shrine blessing gained: %s" % element_name)
	_call(show_toast, "%s blessing gained" % element_name, "success")
	_refresh_after_purchase()
	return true


func buy_ward() -> bool:
	if not _can_use():
		return false
	var cost: Dictionary = ECONOMY_BALANCE.shrine_cost("ward")
	if not _has_cost(cost):
		_set_prompt("NOT ENOUGH ESSENCE")
		_call(show_toast, "Not enough Essence", "warning")
		return false
	if active_ward_bonus > 0:
		_set_prompt("The village is already warded for tonight.")
		_call(show_toast, "Village already warded", "info")
		return false
	_charge(cost)
	active_ward_bonus = ECONOMY_BALANCE.SHRINE_WARD_FORTIFICATION_BONUS
	_call(set_objective, "The village will be warded tonight.")
	_call(show_toast, "Village warded for tonight", "success")
	_refresh_after_purchase()
	return true


func apply_ward_to_fortifications() -> void:
	if active_ward_bonus <= 0:
		return
	var multiplier: float = 1.0 + float(active_ward_bonus) / 100.0
	for gate: Node in gates_root.get_children():
		if not is_instance_valid(gate):
			continue
		gate.max_hp = int(round(gate.max_hp * multiplier))
		gate.hp = gate.max_hp
		gate.health_changed.emit(gate.hp, gate.max_hp)
	for wall: Node in walls_root.get_children():
		if not is_instance_valid(wall):
			continue
		wall.max_hp = int(round(wall.max_hp * multiplier))
		wall.hp = wall.max_hp
	active_ward_bonus = 0


func _can_use() -> bool:
	return can_act.is_valid() and bool(can_act.call())


func _has_cost(cost: Dictionary) -> bool:
	return bool(settlement_state.call("can_afford", cost))


func _charge(cost: Dictionary) -> void:
	settlement_state.call("charge", cost)


func _refresh_after_purchase() -> void:
	_call(refresh_resources)
	_call(refresh_prompt)


func _set_prompt(text: String) -> void:
	if is_instance_valid(shrine_prompt):
		shrine_prompt.text = text


func _cost_text(cost: Dictionary) -> String:
	return ECONOMY_BALANCE.cost_text(cost)


func _call(callback: Callable, argument_1: Variant = null, argument_2: Variant = null) -> void:
	if not callback.is_valid():
		return
	if argument_2 != null:
		callback.call(argument_1, argument_2)
	elif argument_1 != null:
		callback.call(argument_1)
	else:
		callback.call()
