extends Node
class_name GloamPopulationManager

## Owns villagers, workers, and soldier population transactions.
##
## The scene root supplies the actor scenes and presentation callbacks.  The
## manager owns role accounting and ensures a soldier is created from the
## same authoritative population state that drives the HUD.

const ECONOMY_BALANCE := preload("res://scripts/economy_balance.gd")

signal population_changed

var settlement_state: GloamSettlementState
var player_actor: GloamPlayer
var survivors_root: Node
var soldiers_root: Node
var survivor_scene: PackedScene
var guard_scene: PackedScene
var archer_scene: PackedScene
var survivor_positions: Array[Vector2] = []
var guard_positions: Array[Vector2] = []
var archer_positions: Array[Vector2] = []

var can_act: Callable
var is_day: Callable
var set_objective: Callable
var show_toast: Callable
var refresh_resources: Callable
var refresh_population: Callable
var play_audio: Callable
var recalculate_settlement: Callable


func configure(
	state: GloamSettlementState,
	player: GloamPlayer,
	survivors: Node,
	soldiers: Node,
	survivor_scene_resource: PackedScene,
	guard_scene_resource: PackedScene,
	archer_scene_resource: PackedScene,
	survivor_layout: Array[Vector2],
	guard_layout: Array[Vector2],
	archer_layout: Array[Vector2],
	can_act_check: Callable,
	day_check: Callable,
	objective_callback: Callable,
	toast_callback: Callable,
	resource_refresh: Callable,
	population_refresh: Callable,
	audio_callback: Callable,
	settlement_recalculate: Callable
) -> void:
	settlement_state = state
	player_actor = player
	survivors_root = survivors
	soldiers_root = soldiers
	survivor_scene = survivor_scene_resource
	guard_scene = guard_scene_resource
	archer_scene = archer_scene_resource
	survivor_positions = survivor_layout.duplicate()
	guard_positions = guard_layout.duplicate()
	archer_positions = archer_layout.duplicate()
	can_act = can_act_check
	is_day = day_check
	set_objective = objective_callback
	show_toast = toast_callback
	refresh_resources = resource_refresh
	refresh_population = population_refresh
	play_audio = audio_callback
	recalculate_settlement = settlement_recalculate


func spawn_survivors() -> void:
	clear_survivors()
	for position: Vector2 in survivor_positions:
		var survivor: GloamSurvivor = survivor_scene.instantiate() as GloamSurvivor
		survivor.position = position
		survivors_root.add_child(survivor)


func clear_survivors() -> void:
	if not is_instance_valid(survivors_root):
		return
	for survivor: Node in survivors_root.get_children():
		survivor.queue_free()


func try_rescue_villager() -> bool:
	if not _can_manage_population():
		return false

	var total_population: int = _get_int("total_population")
	var population_capacity: int = _get_int("population_capacity")
	if total_population >= population_capacity:
		_call(set_objective, "Population full. Build a House.")
		_call(show_toast, "Population full. Build a House.", "warning")
		return false

	var rescue_food_cost: int = ECONOMY_BALANCE.rescue_food_cost()
	if _get_int("food") < rescue_food_cost:
		_call(set_objective, "Need %d Food to settle a rescued villager." % rescue_food_cost)
		_call(show_toast, "Need %d Food to rescue this villager" % rescue_food_cost, "warning")
		return false

	if not bool(settlement_state.call("charge", {"food": rescue_food_cost})):
		return false
	_set_int("total_population", total_population + 1)
	_set_int("unassigned_villagers", _get_int("unassigned_villagers") + 1)
	_refresh_population_state(true)
	_call(show_toast, "Villager rescued", "success")
	return true


func assign_villager(role: String) -> bool:
	if not _can_manage_population() or _get_int("unassigned_villagers") <= 0:
		return false

	if role == "guard" or role == "archer":
		if settlement_state.get("barracks_built") != true:
			_call(set_objective, "Build a Barracks before training %s." % ("Guards" if role == "guard" else "Archers"))
			_call(show_toast, "Build a Barracks first", "warning")
			return false
	if role != "worker" and role != "guard" and role != "archer":
		return false

	_set_int("unassigned_villagers", _get_int("unassigned_villagers") - 1)
	_set_int(role + "s" if role != "worker" else "workers", _get_int(role + "s" if role != "worker" else "workers") + 1)
	if role == "guard" or role == "archer":
		spawn_soldier(role)
	_refresh_population_state(false)
	_call(show_toast, "%s assigned" % role.to_upper(), "success")
	if is_instance_valid(player_actor):
		_call(play_audio, "ui_confirm", player_actor.global_position, 0.75)
	return true


func spawn_soldier(role: String) -> GloamSoldier:
	var scene: PackedScene = guard_scene if role == "guard" else archer_scene
	var slots: Array[Vector2] = guard_positions if role == "guard" else archer_positions
	if not is_instance_valid(scene) or slots.is_empty():
		return null

	var soldier: GloamSoldier = scene.instantiate() as GloamSoldier
	var same_role_count: int = 0
	for existing: Node in soldiers_root.get_children():
		if existing.get("role") == role:
			same_role_count += 1
	soldier.position = slots[same_role_count % slots.size()]
	soldier.killed.connect(on_soldier_killed)
	soldiers_root.add_child(soldier)
	soldier.set_home_position(soldier.global_position)
	_call(recalculate_settlement)
	return soldier


func apply_worker_income() -> void:
	settlement_state.call("apply_worker_income")
	_call(refresh_resources)


func on_soldier_killed(role: String) -> void:
	_set_int("total_population", _get_int("total_population") - 1)
	if role == "guard" or role == "archer":
		_set_int(role + "s", _get_int(role + "s") - 1)
	_refresh_population_state(false)
	_call(show_toast, "%s lost" % role.to_upper(), "danger")


func _can_manage_population() -> bool:
	return can_act.is_valid() and bool(can_act.call()) and is_day.is_valid() and bool(is_day.call())


func _refresh_population_state(refresh_resources_too: bool) -> void:
	population_changed.emit()
	_call(refresh_population)
	if refresh_resources_too:
		_call(refresh_resources)


func _get_int(property_name: String) -> int:
	return maxi(0, int(settlement_state.get(property_name)))


func _set_int(property_name: String, value: int) -> void:
	settlement_state.set(property_name, maxi(0, value))


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
