extends Node
class_name GloamExplorationController

## Owns deterministic daytime world population and zone presentation.
##
## Combat and settlement managers remain separate.  This controller only
## instantiates the existing exploration actors and keeps their layout data in
## the dedicated day-layout resource.

const DAY_EXPLORATION_LAYOUT := preload("res://scripts/day_exploration_layout.gd")
const ECONOMY_BALANCE := preload("res://scripts/economy_balance.gd")
const RESOURCE_PROFILES := preload("res://scripts/resource_profiles.gd")
const PLACEMENT := preload("res://scripts/placement_validation.gd")

var player_actor: GloamPlayer
var resources_root: Node
var day_enemies_root: Node
var resource_scene: PackedScene
var forest_enemy_scene: PackedScene
var mine_enemy_scene: PackedScene
var ruins_enemy_scene: PackedScene
var zone_label: Label
var current_day: Callable
var exploration_seed: Callable
var placement_validation_errors: Array[String] = []
var resource_reservations: Array[Dictionary] = []


func configure(
	player_ref: GloamPlayer,
	resources: Node,
	day_enemies: Node,
	resource_scene_resource: PackedScene,
	forest_scene: PackedScene,
	mine_scene: PackedScene,
	ruins_scene: PackedScene,
	zone_label_control: Label,
	day_provider: Callable,
	seed_provider: Callable
) -> void:
	player_actor = player_ref
	resources_root = resources
	day_enemies_root = day_enemies
	resource_scene = resource_scene_resource
	forest_enemy_scene = forest_scene
	mine_enemy_scene = mine_scene
	ruins_enemy_scene = ruins_scene
	zone_label = zone_label_control
	current_day = day_provider
	exploration_seed = seed_provider

func spawn_day_resources() -> void:
	clear_day_resources()
	placement_validation_errors.clear()
	resource_reservations.clear()
	var seed_value: int = _seed_value()
	var day_value: int = _day_value()
	var main := get_tree().current_scene
	var world_visuals: Node = main.get_node_or_null("World") if is_instance_valid(main) else null
	var layout: Array[Dictionary] = []
	if is_instance_valid(world_visuals):
		layout.assign(world_visuals.call("get_resource_layout", seed_value, day_value))
	for data: Dictionary in layout:
		var resource_type: String = str(data["type"])
		var zone: String = str(data.get("zone", "wilderness"))
		var profile: Dictionary = RESOURCE_PROFILES.profile(resource_type)
		var bounds: Rect2 = DAY_EXPLORATION_LAYOUT.ZONE_BOUNDS.get(zone, Rect2(0.0, 0.0, 2400.0, 1400.0))
		var placement := PLACEMENT.find_runtime_position(
			world_visuals,
			main,
			data["position"],
			bounds,
			profile["placement_footprint"],
			resource_reservations
		)
		if not bool(placement.get("valid", false)):
			placement_validation_errors.append("resource %s at %s has no valid deterministic fallback" % [resource_type, str(data["position"])])
			continue
		var node: GloamResourceNode = resource_scene.instantiate() as GloamResourceNode
		node.resource_type = resource_type
		node.amount = 1
		node.risk_tier = int(data.get("risk_tier", 1))
		node.zone_name = zone
		node.position = placement["position"]
		resources_root.add_child(node)
		resource_reservations.append({
			"id": "resource_%s_%d" % [resource_type, resource_reservations.size() + 1],
			"zone": zone,
			"rect": PLACEMENT.footprint_rect(node.position, profile["placement_footprint"]),
			"position": node.position,
			"footprint": profile["placement_footprint"],
		})


func clear_day_resources() -> void:
	if not is_instance_valid(resources_root):
		return
	for node: Node in resources_root.get_children():
		node.queue_free()


func spawn_day_enemies() -> void:
	clear_day_enemies()
	var seed_value: int = _seed_value()
	var day_value: int = _day_value()
	_spawn_day_enemy_group(
		forest_enemy_scene,
		_get_enemy_spawn_positions(
			"forest", seed_value, day_value, ECONOMY_BALANCE.day_enemy_count("forest", day_value)
		),
		"forest"
	)
	_spawn_day_enemy_group(
		mine_enemy_scene,
		_get_enemy_spawn_positions(
			"mine", seed_value, day_value, ECONOMY_BALANCE.day_enemy_count("mine", day_value)
		),
		"mine"
	)
	_spawn_day_enemy_group(
		ruins_enemy_scene,
		_get_enemy_spawn_positions(
			"ruins", seed_value, day_value, ECONOMY_BALANCE.day_enemy_count("ruins", day_value)
		),
		"ruins"
	)


func clear_day_enemies() -> void:
	if not is_instance_valid(day_enemies_root):
		return
	for enemy: Node in day_enemies_root.get_children():
		enemy.queue_free()


func update_zone_status(day_active: bool) -> void:
	if not is_instance_valid(zone_label) or not is_instance_valid(player_actor):
		return
	if not day_active:
		zone_label.text = "VILLAGE DEFENSE"
		return

	match DAY_EXPLORATION_LAYOUT.zone_for_position(player_actor.global_position):
		"village":
			zone_label.text = "VILLAGE • Safe"
		"forest":
			zone_label.text = "FOREST • Low Risk • Wood"
		"mine":
			zone_label.text = "MINE • Medium Risk • Stone / Iron"
		"ruins":
			zone_label.text = "RUINS • High Risk • Essence"
		_:
			zone_label.text = "WILDERNESS"


func _spawn_day_enemy_group(scene: PackedScene, positions: Array[Vector2], zone: String) -> void:
	if not is_instance_valid(scene) or not is_instance_valid(day_enemies_root):
		return
	var main := get_tree().current_scene
	var world_visuals: Node = main.get_node_or_null("World") if is_instance_valid(main) else null
	var enemy_footprint := Vector2(18.0, 10.0) if zone == "ruins" else Vector2(24.0, 10.0)
	var reservations: Array[Dictionary] = resource_reservations.duplicate(true)
	for position: Vector2 in positions:
		var placement := PLACEMENT.find_runtime_position(
			world_visuals,
			main,
			position,
			DAY_EXPLORATION_LAYOUT.ZONE_BOUNDS[zone],
			enemy_footprint,
			reservations
		)
		if not bool(placement.get("valid", false)):
			placement_validation_errors.append("%s enemy at %s has no valid deterministic fallback" % [zone, str(position)])
			continue
		var enemy: GloamDayEnemy = scene.instantiate() as GloamDayEnemy
		enemy.position = placement["position"]
		enemy.set_player(player_actor)
		var controller: Node = get_tree().current_scene
		if is_instance_valid(controller) and controller.has_method("_record_run_kill"):
			enemy.defeated.connect(Callable(controller, "_record_run_kill"), CONNECT_ONE_SHOT)
		day_enemies_root.add_child(enemy)
		reservations.append({
			"id": "%s_enemy_%d" % [zone, reservations.size() + 1],
			"zone": zone,
			"rect": PLACEMENT.footprint_rect(enemy.position, enemy_footprint),
			"position": enemy.position,
			"footprint": enemy_footprint,
		})


func _get_enemy_spawn_positions(zone: String, seed_value: int, day_value: int, count: int) -> Array[Vector2]:
	var main := get_tree().current_scene
	var world_visuals: Node = main.get_node_or_null("World") if is_instance_valid(main) else null
	var positions: Array[Vector2] = []
	if is_instance_valid(world_visuals):
		positions.assign(world_visuals.call("get_day_enemy_spawn_positions", zone, seed_value, day_value, count))
	return positions


func _day_value() -> int:
	return int(current_day.call()) if current_day.is_valid() else 1


func _seed_value() -> int:
	return int(exploration_seed.call()) if exploration_seed.is_valid() else 0
