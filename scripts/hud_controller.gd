extends Node
class_name GloamHUDController

## Projects authoritative run state into the HUD.
##
## This view has no economy or phase mutations.  It receives the current
## state from the composition root and renders it, keeping display formatting
## out of construction, population, and combat transactions.

const INPUT_ACTIONS := preload("res://scripts/input_actions.gd")
const UI_STYLE := preload("res://scripts/ui_style.gd")
const TINY_UI_FRAME_SCENE := preload("res://scenes/components/tiny_ui_frame.tscn")
const CURSOR_ARROW := preload("res://assets/generated/tiny_swords/ui/cursors/cursor_01.png")
const CURSOR_HAND := preload("res://assets/generated/tiny_swords/ui/cursors/cursor_02.png")
const CURSOR_UNAVAILABLE := preload("res://assets/generated/tiny_swords/ui/cursors/cursor_03.png")

var ui_root: Node
var player_actor: GloamPlayer
var settlement_state: GloamSettlementState
var can_act: Callable
var is_day: Callable
var is_village: Callable
var pending_upgrades: Callable
var management_open: Callable
var refresh_cursor: Callable

var weapon_icon: TextureRect
var weapon_panel: PanelContainer
var weapon_label: Label
var level_label: Label
var xp_label: Label
var xp_bar: ProgressBar
var hp_label: Label
var hp_bar: ProgressBar
var damage_label: Label
var speed_label: Label
var projectiles_label: Label
var core_hp_label: Label
var core_hp_bar: ProgressBar
var controls_label: Label
var level_ready_label: Label
var level_up_panel: PanelContainer
var game_over_panel: PanelContainer
var victory_panel: PanelContainer
var fire_label: Label
var water_label: Label
var earth_label: Label
var air_label: Label
var resource_panel: PanelContainer
var wood_label: Label
var stone_label: Label
var iron_label: Label
var food_label: Label
var essence_label: Label
var resource_strip: PanelContainer
var wood_strip_label: Label
var stone_strip_label: Label
var iron_strip_label: Label
var food_strip_label: Label
var essence_strip_label: Label
var population_panel: PanelContainer
var population_label: Label
var unassigned_label: Label
var workers_label: Label
var guards_label: Label
var archers_label: Label
var assign_worker_button: Button
var assign_guard_button: Button
var assign_archer_button: Button
var manage_village_button: Button
var buildings_panel: PanelContainer
var houses_label: Label
var farms_label: Label
var barracks_label: Label
var blacksmith_label: Label
var north_gate_label: Label
var east_gate_label: Label
var element_panel: PanelContainer
var downed_label: Label
var toast_panel: PanelContainer
var toast_label: Label
var toast_tween: Tween
var phase_panel: PanelContainer


func configure(
	ui: Node,
	player: GloamPlayer,
	state: GloamSettlementState,
	can_act_check: Callable,
	day_check: Callable,
	village_check: Callable,
	pending_upgrade_count: Callable,
	management_open_check: Callable,
	button_cursor_refresh: Callable
) -> void:
	ui_root = ui
	player_actor = player
	settlement_state = state
	can_act = can_act_check
	is_day = day_check
	is_village = village_check
	pending_upgrades = pending_upgrade_count
	management_open = management_open_check
	refresh_cursor = button_cursor_refresh
	_weapon_refs()
	toast_panel = ui_root.get_node("ToastPanel") as PanelContainer
	toast_label = ui_root.get_node("ToastPanel/Content/ToastLabel") as Label


func apply_visual_setup() -> void:
	var theme_resource: Theme = UI_STYLE.create_theme()
	for child: Node in ui_root.get_children():
		if child is Control:
			(child as Control).theme = theme_resource

	hp_bar.add_theme_stylebox_override("fill", UI_STYLE.make_progress_fill(Color(0.72, 0.19, 0.16, 1.0)))
	xp_bar.add_theme_stylebox_override("fill", UI_STYLE.make_progress_fill(Color(0.48, 0.60, 0.88, 1.0)))
	core_hp_bar.add_theme_stylebox_override("fill", UI_STYLE.make_progress_fill(Color(0.82, 0.59, 0.20, 1.0)))
	phase_panel = ui_root.get_node("PhasePanel") as PanelContainer
	_configure_compact_hud()
	for panel: PanelContainer in [weapon_panel, level_up_panel, game_over_panel, victory_panel]:
		panel.add_theme_stylebox_override("panel", UI_STYLE.make_modal_panel_style())
	var return_panel: PanelContainer = ui_root.get_node("ReturnPanel") as PanelContainer
	return_panel.add_theme_stylebox_override("panel", UI_STYLE.make_alert_panel_style())
	_add_tiny_ui_frame(weapon_panel, false)
	_configure_weapon_choice_buttons()
	_add_tiny_ui_frame(level_up_panel, false)
	_add_tiny_ui_frame(game_over_panel, false)
	_add_tiny_ui_frame(victory_panel, false)
	_configure_asset_button(manage_village_button)
	_configure_asset_button(ui_root.get_node("SkipToNightButton") as Button)
	_configure_asset_button(assign_worker_button)
	_configure_asset_button(assign_guard_button)
	_configure_asset_button(assign_archer_button)
	_configure_interactive_controls()
	_configure_mouse_cursors()
	toast_panel.hide()


func _configure_compact_hud() -> void:
	var stats_panel: PanelContainer = ui_root.get_node("StatsPanel") as PanelContainer
	for panel: PanelContainer in [stats_panel, resource_strip, population_panel, buildings_panel, phase_panel]:
		panel.add_theme_stylebox_override("panel", UI_STYLE.make_asset_panel_style())
		_add_tiny_ui_frame(panel, false, 0.78)

	stats_panel.offset_left = 14.0
	stats_panel.offset_top = 14.0
	stats_panel.offset_right = 244.0
	stats_panel.offset_bottom = 104.0
	stats_panel.get_node("Content/VBox").add_theme_constant_override("separation", 4)
	weapon_icon.hide()
	weapon_label.hide()
	level_label.hide()
	xp_label.hide()
	xp_bar.hide()
	damage_label.hide()
	speed_label.hide()
	projectiles_label.hide()
	controls_label.hide()
	xp_bar.custom_minimum_size.y = 7.0
	hp_bar.custom_minimum_size.y = 8.0
	core_hp_bar.custom_minimum_size.y = 7.0

	resource_strip.offset_left = 14.0
	resource_strip.offset_top = 110.0
	resource_strip.offset_right = 270.0
	resource_strip.offset_bottom = 146.0
	resource_strip.get_node("Content/HBox").add_theme_constant_override("separation", 5)
	for child: Node in resource_strip.get_node("Content/HBox").get_children():
		if child is TextureRect:
			(child as TextureRect).custom_minimum_size = Vector2(16.0, 16.0)

	population_panel.anchor_left = 1.0
	population_panel.anchor_right = 1.0
	population_panel.offset_left = -272.0
	population_panel.offset_top = 14.0
	population_panel.offset_right = -14.0
	population_panel.get_node("Content/VBox").add_theme_constant_override("separation", 5)
	for row_name: String in ["PopulationRow", "WorkersRow", "GuardsRow", "ArchersRow"]:
		var row: HBoxContainer = population_panel.get_node("Content/VBox/%s" % row_name) as HBoxContainer
		row.add_theme_constant_override("separation", 5)
		var avatar: TextureRect = row.get_node("Avatar") as TextureRect
		avatar.custom_minimum_size = Vector2(17.0, 17.0)

	buildings_panel.anchor_left = 1.0
	buildings_panel.anchor_right = 1.0
	buildings_panel.offset_left = -272.0
	buildings_panel.offset_right = -14.0
	buildings_panel.get_node("Content/VBox").add_theme_constant_override("separation", 5)
	phase_panel.offset_left = -220.0
	phase_panel.offset_top = 10.0
	phase_panel.offset_right = 220.0
	phase_panel.offset_bottom = 92.0
	phase_panel.get_node("Content/VBox").add_theme_constant_override("separation", 3)
	var phase_time: Label = phase_panel.get_node("Content/VBox/PhaseTimeLabel") as Label
	phase_time.add_theme_font_size_override("font_size", 18)
	var phase_title: Label = phase_panel.get_node("Content/VBox/PhaseLabel") as Label
	phase_title.add_theme_font_size_override("font_size", 13)
	var objective: Label = phase_panel.get_node("Content/VBox/ObjectiveLabel") as Label
	objective.add_theme_font_size_override("font_size", 12)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var wave: Label = phase_panel.get_node("Content/VBox/WaveLabel") as Label
	wave.add_theme_font_size_override("font_size", 10)


func _configure_asset_button(button: Button) -> void:
	var asset_style: StyleBoxFlat = UI_STYLE.make_asset_button_style()
	for state_name: String in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state_name, asset_style)
	_add_tiny_ui_frame(button, true, 0.96)


func configure_weapon_tooltips() -> void:
	var sword_button: Button = ui_root.get_node("WeaponPanel/Content/VBox/SwordButton") as Button
	var bow_button: Button = ui_root.get_node("WeaponPanel/Content/VBox/BowButton") as Button
	var spear_button: Button = ui_root.get_node("WeaponPanel/Content/VBox/SpearButton") as Button
	sword_button.tooltip_text = "Fast melee cleave. Strong close-range control."
	bow_button.tooltip_text = "Safe ranged weapon with reliable precision."
	spear_button.tooltip_text = "Long-reach thrusts with focused knockback."
	assign_worker_button.tooltip_text = "Assign one available villager. Workers generate resources each dawn."
	assign_guard_button.tooltip_text = "Requires a Barracks. Guards defend the village in melee."
	assign_archer_button.tooltip_text = "Requires a Barracks. Archers defend from long range."
	manage_village_button.tooltip_text = "Open village assignments and settlement details."
	var restart_button: Button = ui_root.get_node("GameOverPanel/Content/VBox/RestartButton") as Button
	var victory_restart_button: Button = ui_root.get_node("VictoryPanel/Content/VBox/RestartButton") as Button
	restart_button.tooltip_text = "Return to the title screen."
	victory_restart_button.tooltip_text = "Return to the title screen."


func show_toast(message: String, tone: String = "info") -> void:
	if not is_instance_valid(toast_panel) or not is_instance_valid(toast_label):
		return
	if is_instance_valid(toast_tween):
		toast_tween.kill()
	toast_label.text = message
	toast_panel.add_theme_stylebox_override("panel", UI_STYLE.make_toast_panel_style(tone))
	toast_panel.modulate = Color(1, 1, 1, 0)
	toast_panel.show()
	toast_tween = create_tween()
	toast_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	toast_tween.tween_property(toast_panel, "modulate", Color.WHITE, 0.12)
	toast_tween.tween_interval(1.45)
	toast_tween.tween_property(toast_panel, "modulate", Color(1, 1, 1, 0), 0.22)
	toast_tween.tween_callback(Callable(toast_panel, "hide"))


func add_tiny_ui_frame(control: Control, is_button: bool) -> void:
	_add_tiny_ui_frame(control, is_button)


func _configure_interactive_controls() -> void:
	_configure_buttons_recursive(ui_root)
	configure_weapon_tooltips()


func _configure_weapon_choice_buttons() -> void:
	for weapon_button: Button in [
		ui_root.get_node("WeaponPanel/Content/VBox/SwordButton") as Button,
		ui_root.get_node("WeaponPanel/Content/VBox/BowButton") as Button,
		ui_root.get_node("WeaponPanel/Content/VBox/SpearButton") as Button
	]:
		var asset_style: StyleBoxFlat = UI_STYLE.make_asset_button_style()
		weapon_button.add_theme_stylebox_override("normal", asset_style)
		weapon_button.add_theme_stylebox_override("hover", asset_style)
		weapon_button.add_theme_stylebox_override("pressed", asset_style)
		weapon_button.add_theme_stylebox_override("disabled", asset_style)
		_add_tiny_ui_frame(weapon_button, true)


func _configure_mouse_cursors() -> void:
	Input.set_custom_mouse_cursor(CURSOR_ARROW, Input.CURSOR_ARROW, Vector2(5, 3))
	Input.set_custom_mouse_cursor(CURSOR_HAND, Input.CURSOR_POINTING_HAND, Vector2(14, 7))
	Input.set_custom_mouse_cursor(CURSOR_UNAVAILABLE, Input.CURSOR_FORBIDDEN, Vector2(16, 16))
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _configure_buttons_recursive(root: Node) -> void:
	for child: Node in root.get_children():
		if child is BaseButton:
			var button: BaseButton = child as BaseButton
			button.focus_mode = Control.FOCUS_ALL
			button.mouse_default_cursor_shape = Control.CURSOR_ARROW if button.disabled else Control.CURSOR_POINTING_HAND
			var minimum_size: Vector2 = button.custom_minimum_size
			minimum_size.y = maxf(minimum_size.y, 36.0)
			button.custom_minimum_size = minimum_size
		_configure_buttons_recursive(child)


func _add_tiny_ui_frame(control: Control, is_button: bool, opacity: float = 1.0) -> void:
	if control.get_node_or_null("TinyUIFrame") != null:
		return
	var frame: Control = TINY_UI_FRAME_SCENE.instantiate() as Control
	frame.name = "TinyUIFrame"
	frame.set("button_frame", is_button)
	frame.set("frame_opacity", opacity)
	frame.z_index = 0
	frame.show_behind_parent = true
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(frame)
	control.move_child(frame, 0)


func refresh_button_cursor(button: BaseButton) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_ARROW if button.disabled else Control.CURSOR_POINTING_HAND


func _weapon_refs() -> void:
	weapon_panel = ui_root.get_node("WeaponPanel") as PanelContainer
	weapon_icon = ui_root.get_node("StatsPanel/Content/VBox/LoadoutRow/WeaponIcon") as TextureRect
	weapon_label = ui_root.get_node("StatsPanel/Content/VBox/LoadoutRow/WeaponLabel") as Label
	level_label = ui_root.get_node("StatsPanel/Content/VBox/LevelLabel") as Label
	xp_label = ui_root.get_node("StatsPanel/Content/VBox/XPLabel") as Label
	xp_bar = ui_root.get_node("StatsPanel/Content/VBox/XPBar") as ProgressBar
	hp_label = ui_root.get_node("StatsPanel/Content/VBox/PlayerHPLabel") as Label
	hp_bar = ui_root.get_node("StatsPanel/Content/VBox/PlayerHPBar") as ProgressBar
	damage_label = ui_root.get_node("StatsPanel/Content/VBox/DamageLabel") as Label
	speed_label = ui_root.get_node("StatsPanel/Content/VBox/SpeedLabel") as Label
	projectiles_label = ui_root.get_node("StatsPanel/Content/VBox/ProjectilesLabel") as Label
	core_hp_label = ui_root.get_node("StatsPanel/Content/VBox/CoreHPLabel") as Label
	core_hp_bar = ui_root.get_node("StatsPanel/Content/VBox/CoreHPBar") as ProgressBar
	controls_label = ui_root.get_node("StatsPanel/Content/VBox/ControlsLabel") as Label
	level_ready_label = ui_root.get_node("LevelReadyLabel") as Label
	level_up_panel = ui_root.get_node("LevelUpPanel") as PanelContainer
	game_over_panel = ui_root.get_node("GameOverPanel") as PanelContainer
	victory_panel = ui_root.get_node("VictoryPanel") as PanelContainer
	element_panel = ui_root.get_node("ElementPanel") as PanelContainer
	fire_label = ui_root.get_node("ElementPanel/Content/VBox/FireLabel") as Label
	water_label = ui_root.get_node("ElementPanel/Content/VBox/WaterLabel") as Label
	earth_label = ui_root.get_node("ElementPanel/Content/VBox/EarthLabel") as Label
	air_label = ui_root.get_node("ElementPanel/Content/VBox/AirLabel") as Label
	resource_panel = ui_root.get_node("ResourcePanel") as PanelContainer
	wood_label = ui_root.get_node("ResourcePanel/Content/VBox/WoodLabel") as Label
	stone_label = ui_root.get_node("ResourcePanel/Content/VBox/StoneLabel") as Label
	iron_label = ui_root.get_node("ResourcePanel/Content/VBox/IronLabel") as Label
	food_label = ui_root.get_node("ResourcePanel/Content/VBox/FoodLabel") as Label
	essence_label = ui_root.get_node("ResourcePanel/Content/VBox/EssenceLabel") as Label
	resource_strip = ui_root.get_node("ResourceStrip") as PanelContainer
	wood_strip_label = ui_root.get_node("ResourceStrip/Content/HBox/WoodValue") as Label
	stone_strip_label = ui_root.get_node("ResourceStrip/Content/HBox/StoneValue") as Label
	iron_strip_label = ui_root.get_node("ResourceStrip/Content/HBox/IronValue") as Label
	food_strip_label = ui_root.get_node("ResourceStrip/Content/HBox/FoodValue") as Label
	essence_strip_label = ui_root.get_node("ResourceStrip/Content/HBox/EssenceValue") as Label
	population_panel = ui_root.get_node("PopulationPanel") as PanelContainer
	population_label = ui_root.get_node("PopulationPanel/Content/VBox/PopulationRow/PopulationLabel") as Label
	unassigned_label = ui_root.get_node("PopulationPanel/Content/VBox/UnassignedLabel") as Label
	workers_label = ui_root.get_node("PopulationPanel/Content/VBox/WorkersRow/WorkersLabel") as Label
	guards_label = ui_root.get_node("PopulationPanel/Content/VBox/GuardsRow/GuardsLabel") as Label
	archers_label = ui_root.get_node("PopulationPanel/Content/VBox/ArchersRow/ArchersLabel") as Label
	assign_worker_button = ui_root.get_node("PopulationPanel/Content/VBox/AssignWorkerButton") as Button
	assign_guard_button = ui_root.get_node("PopulationPanel/Content/VBox/AssignGuardButton") as Button
	assign_archer_button = ui_root.get_node("PopulationPanel/Content/VBox/AssignArcherButton") as Button
	manage_village_button = ui_root.get_node("ManageVillageButton") as Button
	buildings_panel = ui_root.get_node("BuildingsPanel") as PanelContainer
	houses_label = ui_root.get_node("BuildingsPanel/Content/VBox/HousesLabel") as Label
	farms_label = ui_root.get_node("BuildingsPanel/Content/VBox/FarmsLabel") as Label
	barracks_label = ui_root.get_node("BuildingsPanel/Content/VBox/BarracksLabel") as Label
	blacksmith_label = ui_root.get_node("BuildingsPanel/Content/VBox/BlacksmithLabel") as Label
	north_gate_label = ui_root.get_node("BuildingsPanel/Content/VBox/NorthGateLabel") as Label
	east_gate_label = ui_root.get_node("BuildingsPanel/Content/VBox/EastGateLabel") as Label
	downed_label = ui_root.get_node("DownedLabel") as Label


func update_resource() -> void:
	var wood: int = int(settlement_state.get("wood"))
	var stone: int = int(settlement_state.get("stone"))
	var iron: int = int(settlement_state.get("iron"))
	var food: int = int(settlement_state.get("food"))
	var essence: int = int(settlement_state.get("essence"))
	wood_label.text = "WOOD  •  %d" % wood
	stone_label.text = "STONE  •  %d" % stone
	iron_label.text = "IRON  •  %d" % iron
	food_label.text = "FOOD  •  %d" % food
	essence_label.text = "ESSENCE  •  %d" % essence
	wood_strip_label.text = str(wood)
	stone_strip_label.text = str(stone)
	iron_strip_label.text = str(iron)
	food_strip_label.text = str(food)
	essence_strip_label.text = str(essence)


func update_population() -> void:
	var total: int = int(settlement_state.get("total_population"))
	var capacity: int = int(settlement_state.get("population_capacity"))
	var unassigned: int = int(settlement_state.get("unassigned_villagers"))
	var workers: int = int(settlement_state.get("workers"))
	var guards: int = int(settlement_state.get("guards"))
	var archers: int = int(settlement_state.get("archers"))
	var barracks_built: bool = settlement_state.get("barracks_built") == true
	population_label.text = "POPULATION  %d / %d" % [total, capacity]
	unassigned_label.text = "AVAILABLE  •  %d" % unassigned
	workers_label.text = "WORKERS  •  %d" % workers
	guards_label.text = "GUARDS  •  %d" % guards
	archers_label.text = "ARCHERS  •  %d" % archers

	var can_assign: bool = can_act.is_valid() and bool(can_act.call()) and is_day.is_valid() and bool(is_day.call()) and unassigned > 0
	assign_worker_button.disabled = not can_assign
	assign_guard_button.disabled = not can_assign or not barracks_built
	assign_archer_button.disabled = not can_assign or not barracks_built
	if unassigned <= 0:
		assign_worker_button.tooltip_text = "No available villagers to assign."
	else:
		assign_worker_button.tooltip_text = "Assign one villager as a Worker. Produces resources each dawn."
	if not barracks_built:
		assign_guard_button.tooltip_text = "Build a Barracks before training Guards."
		assign_archer_button.tooltip_text = "Build a Barracks before training Archers."
	elif unassigned <= 0:
		assign_guard_button.tooltip_text = "No available villagers to train."
		assign_archer_button.tooltip_text = "No available villagers to train."
	else:
		assign_guard_button.tooltip_text = "Train one Guard for short-range village defense."
		assign_archer_button.tooltip_text = "Train one Archer for long-range village defense."
	_call_cursor(assign_worker_button)
	_call_cursor(assign_guard_button)
	_call_cursor(assign_archer_button)


func update_buildings() -> void:
	houses_label.text = "HOUSES %d / CAP %d  •  FARMS %d (+%d)" % [
		int(settlement_state.get("houses")),
		int(settlement_state.get("population_capacity")),
		int(settlement_state.get("farms")),
		int(settlement_state.get("farm_food_income")),
	]
	farms_label.text = "BARRACKS %s  •  SMITH %s (+%d)" % [
		"READY" if settlement_state.get("barracks_built") == true else "—",
		"READY" if settlement_state.get("blacksmith_built") == true else "—",
		int(settlement_state.get("blacksmith_bonus_damage")),
	]
	barracks_label.text = "BARRACKS  •  %s" % ("READY" if settlement_state.get("barracks_built") == true else "NONE")
	blacksmith_label.text = "BLACKSMITH  •  %s   +%d DMG" % [
		"READY" if settlement_state.get("blacksmith_built") == true else "NONE",
		int(settlement_state.get("blacksmith_bonus_damage")),
	]
	barracks_label.hide()
	blacksmith_label.hide()


func update_xp(current_xp: int, required_xp: int, current_level: int) -> void:
	level_label.text = "LV %d" % current_level
	xp_label.text = "XP  %d / %d" % [current_xp, required_xp]
	xp_bar.max_value = required_xp
	xp_bar.value = current_xp


func update_hp(current_hp: int, max_hp: int) -> void:
	hp_label.text = "HP  %d / %d" % [current_hp, max_hp]
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp


func update_build() -> void:
	weapon_label.text = player_actor.weapon_display_name.to_upper()
	weapon_icon.modulate = (
		Color(0.98, 0.78, 0.34, 1.0) if player_actor.weapon_type == "sword"
		else Color(0.46, 0.78, 0.88, 1.0) if player_actor.weapon_type == "bow"
		else Color(0.78, 0.56, 0.88, 1.0)
	)
	damage_label.text = "DMG %d" % player_actor.projectile_damage
	speed_label.text = "ATK %.2fs" % player_actor.shot_cooldown
	projectiles_label.text = "SHOT %d" % int(player_actor.projectile_speed) if player_actor.weapon_type == "bow" else "MOVE %d" % int(player_actor.move_speed)
	fire_label.text = "FIRE  •  %d" % player_actor.fire_level
	water_label.text = "WATER  •  %d" % player_actor.water_level
	earth_label.text = "EARTH  •  %d" % player_actor.earth_level
	air_label.text = "AIR  •  %d" % player_actor.air_level


func update_core(current_hp: int, max_hp: int) -> void:
	core_hp_label.text = "CORE  %d / %d" % [current_hp, max_hp]
	core_hp_bar.max_value = max_hp
	core_hp_bar.value = current_hp


func update_downed(time_left: float, duration: float, down_number: int, next_delay: float) -> void:
	var down_context: String = "Day down"
	var escalation: String = "Next night down: %d seconds" % int(round(next_delay))
	if player_actor.night_respawn_penalty_active:
		down_context = "Night down %d  •  %ds penalty" % [down_number, int(round(duration))]
		escalation = "Next night down: %d seconds" % int(round(next_delay)) if down_number < 3 else "Maximum night penalty: 7 seconds"
	downed_label.text = "DOWNED\nRespawning in %.1f seconds\n%s\n%s" % [maxf(0.0, time_left), down_context, escalation]


func update_contextual(phase: int, downed: bool, level_panel_visible: bool) -> void:
	var in_village: bool = is_village.is_valid() and bool(is_village.call())
	core_hp_label.show()
	core_hp_bar.show()
	var stats_panel: PanelContainer = ui_root.get_node("StatsPanel") as PanelContainer
	stats_panel.offset_bottom = 104.0
	resource_strip.offset_top = 110.0
	resource_strip.offset_bottom = 146.0
	element_panel.hide()
	var managing: bool = management_open.is_valid() and bool(management_open.call()) and in_village and phase == 0
	if phase == 0:
		resource_panel.hide()
		resource_strip.show()
		population_panel.visible = managing
		buildings_panel.visible = managing
		# Keep the action visible during the day so an unavailable state can
		# explain itself; main.gd supplies the authoritative reason/disabled state.
		manage_village_button.visible = true
		manage_village_button.disabled = downed
		set_village_management_layout(managing)
		houses_label.show()
		farms_label.show()
		barracks_label.hide()
		blacksmith_label.hide()
		phase_panel.offset_bottom = 92.0
		ui_root.get_node("PhasePanel/Content/VBox/WaveLabel").hide()
	else:
		resource_panel.hide()
		resource_strip.show()
		population_panel.hide()
		buildings_panel.hide()
		manage_village_button.hide()
		set_village_management_layout(false)
		buildings_panel.offset_top = 120.0
		buildings_panel.offset_bottom = 220.0
		houses_label.hide()
		farms_label.hide()
		barracks_label.hide()
		blacksmith_label.hide()
		phase_panel.offset_bottom = 112.0
		ui_root.get_node("PhasePanel/Content/VBox/WaveLabel").show()
	north_gate_label.visible = managing
	east_gate_label.visible = managing
	var pending: int = pending_upgrades.call() if pending_upgrades.is_valid() else 0
	level_ready_label.visible = pending > 0 and not level_panel_visible
	if pending > 0:
		level_ready_label.text = "LEVEL UP READY  •  %s DURING DAY" % INPUT_ACTIONS.action_hint(INPUT_ACTIONS.LEVEL_UP) if phase == 0 else "LEVEL UP READY  •  CHOOSE AT DAWN"


func set_village_management_layout(open: bool) -> void:
	manage_village_button.text = "CLOSE MANAGEMENT" if open else "MANAGE VILLAGE"
	assign_worker_button.visible = open
	assign_guard_button.visible = open
	assign_archer_button.visible = open
	if open:
		population_panel.offset_bottom = 326.0
		manage_village_button.anchor_left = 1.0
		manage_village_button.anchor_right = 1.0
		manage_village_button.offset_left = -252.0
		manage_village_button.offset_top = 332.0
		manage_village_button.offset_right = -14.0
		manage_village_button.offset_bottom = 374.0
		manage_village_button.text = "CLOSE MANAGEMENT"
		buildings_panel.offset_top = 380.0
		buildings_panel.offset_bottom = 512.0
	else:
		population_panel.offset_bottom = 184.0
		manage_village_button.anchor_left = 1.0
		manage_village_button.anchor_right = 1.0
		manage_village_button.offset_left = -252.0
		manage_village_button.offset_top = 190.0
		manage_village_button.offset_right = -14.0
		manage_village_button.offset_bottom = 232.0
		buildings_panel.offset_top = 238.0
		buildings_panel.offset_bottom = 356.0


func _call_cursor(button: BaseButton) -> void:
	if refresh_cursor.is_valid():
		refresh_cursor.call(button)
