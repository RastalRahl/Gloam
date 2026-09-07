extends Node
class_name GloamNightPresentationController

## Owns the camera and visual presentation that distinguishes exploration from
## night defense.  It never changes combat state; it only projects the current
## phase and live threats into camera, lighting, and HUD presentation.

const NIGHT_LANE_VISUALS := preload("res://scripts/night_lane_visuals.gd")
const NIGHT_THREAT_OVERLAY := preload("res://scripts/night_threat_overlay.gd")
const PIXEL_SNAP_CAMERA := preload("res://scripts/pixel_snap_camera.gd")
const VISUALS := preload("res://scripts/visual_constants.gd")
const DAY_EXPLORATION_LAYOUT := preload("res://scripts/day_exploration_layout.gd")

var player_actor: GloamPlayer
var village_core: GloamVillageCore
var enemies_root: Node
var ui_root: Node
var north_gate: Node2D
var east_gate: Node2D
var north_breach_marker: Node2D
var east_breach_marker: Node2D
var world_size: Vector2
var phase_label: Label
var return_panel: PanelContainer
var return_label: Label
var objective_label: Label
var dusk_tint: ColorRect
var world_light: CanvasModulate
var phase_provider: Callable
var day_provider: Callable
var game_over_check: Callable
var world_camera: Camera2D
var lane_visuals: Node
var threat_overlay: Node
var dusk_warning_time: float = 12.0
var telegraphed_lanes: Array[String] = []


func configure(
	player_ref: GloamPlayer,
	village_core_ref: GloamVillageCore,
	enemies: Node,
	ui: Node,	north_gate_ref: Node2D,
	east_gate_ref: Node2D,
	north_marker: Node2D,
	east_marker: Node2D,	size: Vector2,
	phase_label_control: Label,
	return_panel_control: PanelContainer,
	return_label_control: Label,
	objective_label_control: Label,
	dusk_tint_control: ColorRect,
	world_light_control: CanvasModulate,
	phase_check: Callable,
	day_check: Callable,
	game_over_check_callback: Callable
) -> void:
	player_actor = player_ref
	village_core = village_core_ref
	enemies_root = enemies
	ui_root = ui
	north_gate = north_gate_ref
	east_gate = east_gate_ref
	north_breach_marker = north_marker
	east_breach_marker = east_marker
	world_size = size
	phase_label = phase_label_control
	return_panel = return_panel_control
	return_label = return_label_control
	objective_label = objective_label_control
	dusk_tint = dusk_tint_control
	world_light = world_light_control
	phase_provider = phase_check
	day_provider = day_check
	game_over_check = game_over_check_callback


func setup_camera() -> Camera2D:
	world_camera = PIXEL_SNAP_CAMERA.new() as Camera2D
	world_camera.name = "WorldCamera"
	world_camera.set("stable_zoom", VISUALS.CAMERA_ZOOM)
	world_camera.zoom = VISUALS.CAMERA_ZOOM
	world_camera.position_smoothing_enabled = false
	world_camera.limit_left = 0
	world_camera.limit_top = 0
	world_camera.limit_right = int(world_size.x)
	world_camera.limit_bottom = int(world_size.y)
	player_actor.add_child(world_camera)
	world_camera.make_current()
	return world_camera


func setup_readability_visuals() -> void:
	lane_visuals = NIGHT_LANE_VISUALS.new()
	lane_visuals.name = "NightLaneVisuals"
	lane_visuals.z_index = 1
	add_child(lane_visuals)
	lane_visuals.configure(north_gate, east_gate, north_breach_marker, east_breach_marker)
	lane_visuals.set_active(false)

	threat_overlay = NIGHT_THREAT_OVERLAY.new()
	threat_overlay.name = "NightThreatOverlay"
	threat_overlay.z_index = 15
	ui_root.add_child(threat_overlay)


func set_high_contrast(enabled: bool) -> void:
	if is_instance_valid(threat_overlay):
		threat_overlay.set_high_contrast(enabled)


func clamp_player_to_world() -> void:
	if not is_instance_valid(player_actor):
		return
	player_actor.global_position.x = clampf(player_actor.global_position.x, 20.0, world_size.x - 20.0)
	player_actor.global_position.y = clampf(player_actor.global_position.y, 20.0, world_size.y - 20.0)


func set_night_readability(active: bool) -> void:
	if is_instance_valid(lane_visuals):
		lane_visuals.set_active(active)
	if is_instance_valid(threat_overlay) and not active:
		telegraphed_lanes.clear()
		threat_overlay.set_threats([])
	if not is_instance_valid(enemies_root):
		return
	for enemy: Node in enemies_root.get_children():
		if enemy.has_method("set_night_readability"):
			enemy.set_night_readability(active)


func update_night_readability() -> void:
	if not is_instance_valid(threat_overlay):
		return
	if _phase() != 1 or _game_over():
		threat_overlay.set_threats([])
		return

	var threats: Array[Dictionary] = []
	for lane: String in telegraphed_lanes:
		threats.append({
			"lane": lane,
			"direction": "↓" if lane == "NORTH" else "←",
			"urgency": "WAVE INCOMING",
			"color": Color(1.0, 0.44, 0.18, 1.0),
		})
	var north_threat: Dictionary = _find_offscreen_lane_threat(north_gate, "NORTH")
	var east_threat: Dictionary = _find_offscreen_lane_threat(east_gate, "EAST")
	if not north_threat.is_empty() and not telegraphed_lanes.has("NORTH"):
		threats.append(north_threat)
	if not east_threat.is_empty() and not telegraphed_lanes.has("EAST"):
		threats.append(east_threat)
	threat_overlay.set_threats(threats)


func set_wave_telegraph(lane_label: String) -> void:
	telegraphed_lanes.clear()
	if lane_label.contains("NORTH"):
		telegraphed_lanes.append("NORTH")
	if lane_label.contains("EAST"):
		telegraphed_lanes.append("EAST")
	update_night_readability()


func clear_wave_telegraph() -> void:
	telegraphed_lanes.clear()
	update_night_readability()


func update_dusk_guidance(time_left: float) -> void:
	if _phase() != 0:
		dusk_tint.color = Color(0.030, 0.055, 0.115, 0.09)
		world_light.color = Color(0.87, 0.90, 0.98, 1.0)
		return_panel.hide()
		return

	if time_left <= 15.0:
		var urgency: float = clampf((15.0 - time_left) / 15.0, 0.0, 1.0)
		dusk_tint.color = Color(0.30, 0.09, 0.035, 0.025 + urgency * 0.075)
	else:
		dusk_tint.color = Color(0, 0, 0, 0)
		world_light.color = Color(0.99, 0.98, 0.94, 1.0)

	if time_left <= dusk_warning_time:
		phase_label.text = "DUSK"
		if not _is_player_in_village():
			var delta_to_village: Vector2 = village_core.global_position - player_actor.global_position
			return_label.text = "%s  RETURN TO VILLAGE  •  %d" % [_direction_arrow(delta_to_village), int(round(delta_to_village.length()))]
			return_panel.show()
			objective_label.text = "Night is coming. Get behind the walls."
		else:
			return_panel.hide()
			objective_label.text = "Dusk. Finish preparations."
	else:
		phase_label.text = "DAY %d" % _day()
		return_panel.hide()


func _find_offscreen_lane_threat(gate: Node2D, lane: String) -> Dictionary:
	if not is_instance_valid(gate) or not is_instance_valid(world_camera) or not is_instance_valid(enemies_root):
		return {}
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var closest_distance: float = INF
	for enemy: Node in enemies_root.get_children():
		if not is_instance_valid(enemy) or not enemy.is_in_group("enemies"):
			continue
		if enemy.get("primary_gate") as Node2D != gate:
			continue
		var enemy_hp: Variant = enemy.get("hp")
		if enemy_hp != null and int(enemy_hp) <= 0:
			continue
		var enemy_is_dead: Variant = enemy.get("is_dead")
		if enemy_is_dead != null and bool(enemy_is_dead):
			continue
		var screen_position: Vector2 = (
			(enemy.global_position - world_camera.get_screen_center_position()) * world_camera.zoom
			+ viewport_size * 0.5
		)
		if screen_position.x >= -32.0 and screen_position.y >= -32.0 and screen_position.x <= viewport_size.x + 32.0 and screen_position.y <= viewport_size.y + 32.0:
			continue
		closest_distance = minf(closest_distance, enemy.global_position.distance_to(gate.global_position))

	if closest_distance == INF:
		return {}
	var urgency: String = "APPROACHING"
	var urgency_color := Color(0.96, 0.64, 0.24, 1.0)
	if closest_distance <= 170.0:
		urgency = "IMMINENT"
		urgency_color = Color(1.0, 0.25, 0.16, 1.0)
	elif closest_distance <= 410.0:
		urgency = "CLOSE"
		urgency_color = Color(1.0, 0.48, 0.18, 1.0)
	return {"lane": lane, "direction": "↓" if lane == "NORTH" else "←", "urgency": urgency, "color": urgency_color}


func _is_player_in_village() -> bool:
	return DAY_EXPLORATION_LAYOUT.is_village_position(player_actor.global_position)


func _direction_arrow(direction: Vector2) -> String:
	if direction.length_squared() <= 1.0:
		return "•"
	var angle: float = direction.angle()
	var eighth: float = PI / 8.0
	if angle >= -eighth and angle < eighth:
		return "→"
	if angle >= eighth and angle < 3.0 * eighth:
		return "↘"
	if angle >= 3.0 * eighth and angle < 5.0 * eighth:
		return "↓"
	if angle >= 5.0 * eighth and angle < 7.0 * eighth:
		return "↙"
	if angle >= 7.0 * eighth or angle < -7.0 * eighth:
		return "←"
	if angle >= -7.0 * eighth and angle < -5.0 * eighth:
		return "↖"
	if angle >= -5.0 * eighth and angle < -3.0 * eighth:
		return "↑"
	return "↗"


func _phase() -> int:
	return int(phase_provider.call()) if phase_provider.is_valid() else 0


func _day() -> int:
	return int(day_provider.call()) if day_provider.is_valid() else 1


func _game_over() -> bool:
	return bool(game_over_check.call()) if game_over_check.is_valid() else false
