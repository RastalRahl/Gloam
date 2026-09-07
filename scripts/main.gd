extends Node2D

## Scene composition root.
##
## Gameplay state and transactions live in the child directors/managers below:
## phase identity, wave timing, settlement, construction, population,
## interactions, progression, shrine services, HUD projection, and daytime
## world population.  The small compatibility adapters in this file preserve
## the scene's existing callback surface while keeping ownership explicit.

enum Phase {
	DAY,
	NIGHT,
	VICTORY
}

const ARCHER_TOWER_SCENE := preload("res://scenes/archer_tower.tscn")
const BARRICADE_SCENE := preload("res://scenes/barricade.tscn")
const BALLISTA_SCENE := preload("res://scenes/ballista.tscn")

const GRUNT_SCENE := preload("res://scenes/enemy.tscn")
const RUNNER_SCENE := preload("res://scenes/enemy_runner.tscn")
const BRUTE_SCENE := preload("res://scenes/enemy_brute.tscn")
const RANGED_ENEMY_SCENE := preload("res://scenes/enemy_ranged.tscn")
const GRAVE_OX_SCENE := preload("res://scenes/grave_ox.tscn")
const SURVIVOR_SCENE := preload("res://scenes/survivor.tscn")
const GUARD_SCENE := preload("res://scenes/guard.tscn")
const ARCHER_SOLDIER_SCENE := preload("res://scenes/archer_soldier.tscn")
const HOUSE_SCENE := preload("res://scenes/house.tscn")
const FARM_SCENE := preload("res://scenes/farm.tscn")
const BARRACKS_BUILDING_SCENE := preload("res://scenes/barracks_building.tscn")
const BLACKSMITH_SCENE := preload("res://scenes/blacksmith.tscn")
const SHRINE_SCENE := preload("res://scenes/shrine.tscn")
const CONTEXTUAL_INTERACTION_MENU := preload("res://scripts/contextual_interaction_menu.gd")
const INPUT_ACTIONS := preload("res://scripts/input_actions.gd")
const DAY_EXPLORATION_LAYOUT := preload("res://scripts/day_exploration_layout.gd")
const ECONOMY_BALANCE := preload("res://scripts/economy_balance.gd")
const PAUSE_MENU := preload("res://scripts/pause_menu.gd")
const WAVE_DIRECTOR := preload("res://scripts/wave_director.gd")
const SETTLEMENT_STATE := preload("res://scripts/settlement_state.gd")
const CONSTRUCTION_MANAGER := preload("res://scripts/construction_manager.gd")
const POPULATION_MANAGER := preload("res://scripts/population_manager.gd")
const INTERACTION_CONTROLLER := preload("res://scripts/interaction_controller.gd")
const PROGRESSION_MANAGER := preload("res://scripts/progression_manager.gd")
const SHRINE_MANAGER := preload("res://scripts/shrine_manager.gd")
const RUN_PHASE_DIRECTOR := preload("res://scripts/run_phase_director.gd")
const HUD_CONTROLLER := preload("res://scripts/hud_controller.gd")
const EXPLORATION_CONTROLLER := preload("res://scripts/exploration_controller.gd")
const NIGHT_PRESENTATION_CONTROLLER := preload("res://scripts/night_presentation_controller.gd")
const VISUALS := preload("res://scripts/visual_constants.gd")
const UI_FOCUS := preload("res://scripts/ui_focus.gd")
const UI_INPUT_CONTRACT := preload("res://scripts/ui_input_contract.gd")
const RUN_CHECKPOINT := preload("res://scripts/run_checkpoint.gd")
const TITLE_MENU := preload("res://scripts/title_menu.gd")

const NIGHT_ENEMY_MOVEMENT_MULTIPLIER: float = 0.85
const SKIP_CONFIRMATION_SECONDS: float = 3.0

const DEPTH_SORT_ROOTS: Array[String] = [
	"Resources", "Survivors", "Soldiers", "VillageBuildings", "Defenses", "Enemies",
	"DayEnemies", "Shrines", "World/Regions/Village/Gates",
	"World/Regions/Village/DefenseBuildSpots", "World/Regions/Village/VillageBuildSpots"
]

@export var day_duration: float = 165.0
@export var world_size: Vector2 = Vector2(2400, 1400)
@export var night_duration: float = 0.0 # Legacy inspector field; night completion is kill-gated.
@export var nights_to_survive: int = 10
@export var final_boss_spawn_delay: float = 15.0
@export var upgrade_debug_seed: int = 0
@export var exploration_debug_seed: int = 0
@export var checkpoint_enabled: bool = true

@onready var village_core: GloamVillageCore = $World/Regions/Village/Landmarks/VillageCore as GloamVillageCore
@onready var phase_timer: Timer = $PhaseTimer
@onready var player: GloamPlayer = $Player as GloamPlayer
@onready var game_settings: GloamGameSettings = $GameSettings as GloamGameSettings
@onready var stats_panel: PanelContainer = $UI/StatsPanel

var world_camera: Camera2D
var night_lane_visuals
var night_threat_overlay
var wave_director: GloamWaveDirector = null
var settlement_state: GloamSettlementState = SETTLEMENT_STATE.new() as GloamSettlementState
var construction_manager: GloamConstructionManager = null
var population_manager: GloamPopulationManager = null
var interaction_controller: GloamInteractionController = null
var progression_manager: GloamProgressionManager = null
var shrine_manager: GloamShrineManager = null
var run_phase_director: GloamRunPhaseDirector = null
var hud_controller: GloamHUDController = null
var exploration_controller: GloamExplorationController = null
var night_presentation_controller: GloamNightPresentationController = null
var ui_input_contract: RefCounted = null
var run_checkpoint: GloamRunCheckpoint = RUN_CHECKPOINT.new() as GloamRunCheckpoint
var title_menu: GloamTitleMenu = null
var run_started_at_msec: int = 0
var run_kills: int = 0
var run_rescues: int = 0
var run_structures_lost: int = 0

@onready var weapon_icon: TextureRect = $UI/StatsPanel/Content/VBox/LoadoutRow/WeaponIcon
@onready var weapon_label: Label = $UI/StatsPanel/Content/VBox/LoadoutRow/WeaponLabel
@onready var level_label: Label = $UI/StatsPanel/Content/VBox/LevelLabel
@onready var xp_label: Label = $UI/StatsPanel/Content/VBox/XPLabel
@onready var xp_bar: ProgressBar = $UI/StatsPanel/Content/VBox/XPBar
@onready var hp_label: Label = $UI/StatsPanel/Content/VBox/PlayerHPLabel
@onready var hp_bar: ProgressBar = $UI/StatsPanel/Content/VBox/PlayerHPBar
@onready var damage_label: Label = $UI/StatsPanel/Content/VBox/DamageLabel
@onready var speed_label: Label = $UI/StatsPanel/Content/VBox/SpeedLabel
@onready var projectiles_label: Label = $UI/StatsPanel/Content/VBox/ProjectilesLabel
@onready var core_hp_label: Label = $UI/StatsPanel/Content/VBox/CoreHPLabel
@onready var core_hp_bar: ProgressBar = $UI/StatsPanel/Content/VBox/CoreHPBar
@onready var controls_label: Label = $UI/StatsPanel/Content/VBox/ControlsLabel
@onready var level_ready_label: Label = $UI/LevelReadyLabel

@onready var element_panel: PanelContainer = $UI/ElementPanel
@onready var fire_label: Label = $UI/ElementPanel/Content/VBox/FireLabel
@onready var water_label: Label = $UI/ElementPanel/Content/VBox/WaterLabel
@onready var earth_label: Label = $UI/ElementPanel/Content/VBox/EarthLabel
@onready var air_label: Label = $UI/ElementPanel/Content/VBox/AirLabel

@onready var resource_panel: PanelContainer = $UI/ResourcePanel
@onready var wood_label: Label = $UI/ResourcePanel/Content/VBox/WoodLabel
@onready var stone_label: Label = $UI/ResourcePanel/Content/VBox/StoneLabel
@onready var iron_label: Label = $UI/ResourcePanel/Content/VBox/IronLabel
@onready var food_label: Label = $UI/ResourcePanel/Content/VBox/FoodLabel
@onready var essence_label: Label = $UI/ResourcePanel/Content/VBox/EssenceLabel
@onready var resource_strip: PanelContainer = $UI/ResourceStrip
@onready var wood_strip_label: Label = $UI/ResourceStrip/Content/HBox/WoodValue
@onready var stone_strip_label: Label = $UI/ResourceStrip/Content/HBox/StoneValue
@onready var iron_strip_label: Label = $UI/ResourceStrip/Content/HBox/IronValue
@onready var food_strip_label: Label = $UI/ResourceStrip/Content/HBox/FoodValue
@onready var essence_strip_label: Label = $UI/ResourceStrip/Content/HBox/EssenceValue

@onready var population_panel: PanelContainer = $UI/PopulationPanel
@onready var population_label: Label = $UI/PopulationPanel/Content/VBox/PopulationRow/PopulationLabel
@onready var unassigned_label: Label = $UI/PopulationPanel/Content/VBox/UnassignedLabel
@onready var workers_label: Label = $UI/PopulationPanel/Content/VBox/WorkersRow/WorkersLabel
@onready var guards_label: Label = $UI/PopulationPanel/Content/VBox/GuardsRow/GuardsLabel
@onready var archers_label: Label = $UI/PopulationPanel/Content/VBox/ArchersRow/ArchersLabel
@onready var assign_worker_button: Button = $UI/PopulationPanel/Content/VBox/AssignWorkerButton
@onready var assign_guard_button: Button = $UI/PopulationPanel/Content/VBox/AssignGuardButton
@onready var assign_archer_button: Button = $UI/PopulationPanel/Content/VBox/AssignArcherButton
@onready var manage_village_button: Button = $UI/ManageVillageButton

@onready var buildings_panel: PanelContainer = $UI/BuildingsPanel
@onready var houses_label: Label = $UI/BuildingsPanel/Content/VBox/HousesLabel
@onready var farms_label: Label = $UI/BuildingsPanel/Content/VBox/FarmsLabel
@onready var barracks_label: Label = $UI/BuildingsPanel/Content/VBox/BarracksLabel
@onready var blacksmith_label: Label = $UI/BuildingsPanel/Content/VBox/BlacksmithLabel
@onready var north_gate_label: Label = $UI/BuildingsPanel/Content/VBox/NorthGateLabel
@onready var east_gate_label: Label = $UI/BuildingsPanel/Content/VBox/EastGateLabel

@onready var fortification_panel: PanelContainer = $UI/FortificationPanel
@onready var fortification_prompt: Label = $UI/FortificationPanel/Content/VBox/Prompt

@onready var shrine_panel: PanelContainer = $UI/ShrinePanel
@onready var shrine_prompt: Label = $UI/ShrinePanel/Content/VBox/Prompt

@onready var phase_label: Label = $UI/PhasePanel/Content/VBox/PhaseLabel
@onready var phase_time_label: Label = $UI/PhasePanel/Content/VBox/PhaseTimeLabel
@onready var objective_label: Label = $UI/PhasePanel/Content/VBox/ObjectiveLabel
@onready var wave_label: Label = $UI/PhasePanel/Content/VBox/WaveLabel
@onready var zone_label: Label = $UI/PhasePanel/Content/VBox/ZoneLabel
@onready var skip_to_night_button: Button = $UI/SkipToNightButton

@onready var boss_panel: PanelContainer = $UI/BossPanel
@onready var boss_hp_label: Label = $UI/BossPanel/Content/VBox/BossHPLabel

@onready var build_panel: PanelContainer = $UI/BuildPanel
@onready var build_prompt: Label = $UI/BuildPanel/Content/VBox/Prompt

@onready var village_build_panel: PanelContainer = $UI/VillageBuildPanel
@onready var village_build_prompt: Label = $UI/VillageBuildPanel/Content/VBox/Prompt

@onready var downed_label: Label = $UI/DownedLabel

@onready var weapon_panel: PanelContainer = $UI/WeaponPanel
@onready var sword_button: Button = $UI/WeaponPanel/Content/VBox/SwordButton
@onready var bow_button: Button = $UI/WeaponPanel/Content/VBox/BowButton
@onready var spear_button: Button = $UI/WeaponPanel/Content/VBox/SpearButton

@onready var level_up_panel: PanelContainer = $UI/LevelUpPanel
@onready var level_up_title: Label = $UI/LevelUpPanel/Content/VBox/Title
@onready var upgrade_button_1: Button = $UI/LevelUpPanel/Content/VBox/UpgradeButton1
@onready var upgrade_button_2: Button = $UI/LevelUpPanel/Content/VBox/UpgradeButton2
@onready var upgrade_button_3: Button = $UI/LevelUpPanel/Content/VBox/UpgradeButton3

@onready var game_over_panel: PanelContainer = $UI/GameOverPanel
@onready var restart_button: Button = $UI/GameOverPanel/Content/VBox/RestartButton
@onready var game_over_results: Label = $UI/GameOverPanel/Content/VBox/RunResults

@onready var victory_panel: PanelContainer = $UI/VictoryPanel
@onready var victory_restart_button: Button = $UI/VictoryPanel/Content/VBox/RestartButton
@onready var victory_results: Label = $UI/VictoryPanel/Content/VBox/RunResults

@onready var dusk_tint: ColorRect = $UI/DuskTint
@onready var world_light: CanvasModulate = $WorldLight
@onready var world_visuals: GloamWorldVisuals = $World as GloamWorldVisuals
@onready var day_obstacles: Node2D = $DayObstacles
@onready var return_panel: PanelContainer = $UI/ReturnPanel
@onready var return_label: Label = $UI/ReturnPanel/ReturnLabel
@onready var modal_dimmer: ColorRect = $UI/ModalDimmer

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var upgrade_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var exploration_seed: int = 0

var pending_level_ups: int:
	get:
		return progression_manager.pending_level_ups if is_instance_valid(progression_manager) else 0
	set(value):
		if is_instance_valid(progression_manager):
			progression_manager.pending_level_ups = maxi(0, value)

var controls_hint_time_left: float = 0.0
var village_management_open: bool = false
var village_management_input_latched: bool = false

var wave_index: int:
	get:
		return wave_director.wave_index if is_instance_valid(wave_director) else 0
	set(value):
		if is_instance_valid(wave_director):
			wave_director.wave_index = value
var wave_active: bool:
	get:
		return wave_director.wave_active if is_instance_valid(wave_director) else false
	set(value):
		if is_instance_valid(wave_director):
			wave_director.wave_active = value
var wave_waiting: bool:
	get:
		return wave_director.wave_waiting if is_instance_valid(wave_director) else false
	set(value):
		if is_instance_valid(wave_director):
			wave_director.wave_waiting = value
var wave_token: int:
	get:
		return wave_director.wave_token if is_instance_valid(wave_director) else 0
	set(value):
		if is_instance_valid(wave_director):
			wave_director.wave_token = value
var game_over: bool = false
var run_started: bool:
	get:
		return run_phase_director.run_started if is_instance_valid(run_phase_director) else false
	set(value):
		if is_instance_valid(run_phase_director):
			run_phase_director.run_started = value
var night_schedule_active: bool:
	get:
		return wave_director.night_schedule_active if is_instance_valid(wave_director) else false
	set(value):
		if is_instance_valid(wave_director):
			wave_director.night_schedule_active = value
var night_schedule_complete: bool:
	get:
		return wave_director.night_schedule_complete if is_instance_valid(wave_director) else false
	set(value):
		if is_instance_valid(wave_director):
			wave_director.night_schedule_complete = value
var night_finish_started: bool:
	get:
		return wave_director.night_finish_started if is_instance_valid(wave_director) else false
	set(value):
		if is_instance_valid(wave_director):
			wave_director.night_finish_started = value
var night_schedule_duration: float:
	get:
		return wave_director.night_schedule_duration if is_instance_valid(wave_director) else 0.0
	set(value):
		if is_instance_valid(wave_director):
			wave_director.night_schedule_duration = value
var night_clock_time_left: float:
	get:
		return wave_director.night_clock_time_left if is_instance_valid(wave_director) else 0.0
	set(value):
		if is_instance_valid(wave_director):
			wave_director.night_clock_time_left = value
var wave_cancel_reported: bool:
	get:
		return wave_director.wave_cancel_reported if is_instance_valid(wave_director) else false
	set(value):
		if is_instance_valid(wave_director):
			wave_director.wave_cancel_reported = value

var current_phase: int:
	get:
		return run_phase_director.phase if is_instance_valid(run_phase_director) else Phase.DAY
	set(value):
		if is_instance_valid(run_phase_director):
			run_phase_director.phase = value
var current_day: int:
	get:
		return run_phase_director.day if is_instance_valid(run_phase_director) else 1
	set(value):
		if is_instance_valid(run_phase_director):
			run_phase_director.day = value
var completed_nights: int:
	get:
		return run_phase_director.completed_nights if is_instance_valid(run_phase_director) else 0
	set(value):
		if is_instance_valid(run_phase_director):
			run_phase_director.completed_nights = value

const BASE_POPULATION_CAPACITY: int = ECONOMY_BALANCE.BASE_POPULATION_CAPACITY
var wood: int:
	get: return int(settlement_state.get("wood"))
	set(value): settlement_state.set("wood", maxi(0, value))
var stone: int:
	get: return int(settlement_state.get("stone"))
	set(value): settlement_state.set("stone", maxi(0, value))
var iron: int:
	get: return int(settlement_state.get("iron"))
	set(value): settlement_state.set("iron", maxi(0, value))
var food: int:
	get: return int(settlement_state.get("food"))
	set(value): settlement_state.set("food", maxi(0, value))
var essence: int:
	get: return int(settlement_state.get("essence"))
	set(value): settlement_state.set("essence", maxi(0, value))

var houses: int:
	get: return int(settlement_state.get("houses"))
	set(value): settlement_state.set("houses", maxi(0, value))
var farms: int:
	get: return int(settlement_state.get("farms"))
	set(value): settlement_state.set("farms", maxi(0, value))
var farm_food_income: int:
	get: return int(settlement_state.get("farm_food_income"))
	set(value): settlement_state.set("farm_food_income", maxi(0, value))
var barracks_built: bool:
	get: return bool(settlement_state.get("barracks_built"))
	set(value): settlement_state.set("barracks_built", value)
var barracks_training_bonus: int:
	get: return int(settlement_state.get("barracks_training_bonus"))
	set(value): settlement_state.set("barracks_training_bonus", maxi(0, value))
var blacksmith_built: bool:
	get: return bool(settlement_state.get("blacksmith_built"))
	set(value): settlement_state.set("blacksmith_built", value)
var blacksmith_bonus_damage: int:
	get: return int(settlement_state.get("blacksmith_bonus_damage"))
	set(value): settlement_state.set("blacksmith_bonus_damage", maxi(0, value))

var total_population: int:
	get: return int(settlement_state.get("total_population"))
	set(value): settlement_state.set("total_population", maxi(0, value))
var unassigned_villagers: int:
	get: return int(settlement_state.get("unassigned_villagers"))
	set(value): settlement_state.set("unassigned_villagers", maxi(0, value))
var workers: int:
	get: return int(settlement_state.get("workers"))
	set(value): settlement_state.set("workers", maxi(0, value))
var guards: int:
	get: return int(settlement_state.get("guards"))
	set(value): settlement_state.set("guards", maxi(0, value))
var archers: int:
	get: return int(settlement_state.get("archers"))
	set(value): settlement_state.set("archers", maxi(0, value))
var population_capacity: int:
	get: return int(settlement_state.get("population_capacity"))
	set(value): settlement_state.set("population_capacity", maxi(0, value))

var active_build_spot: GloamBuildSpot:
	get:
		return construction_manager.active_build_spot if is_instance_valid(construction_manager) else null
	set(value):
		if is_instance_valid(construction_manager):
			construction_manager.active_build_spot = value
var active_village_build_spot: GloamVillageBuildSpot:
	get:
		return construction_manager.active_village_build_spot if is_instance_valid(construction_manager) else null
	set(value):
		if is_instance_valid(construction_manager):
			construction_manager.active_village_build_spot = value
var active_shrine: GloamShrine = null
var active_interaction_target: Node2D = null
var contextual_interaction_menu: GloamContextualInteractionMenu = null
var pause_menu: GloamPauseMenu = null
var interaction_menu_open: bool:
	get:
		return interaction_controller.menu_open if is_instance_valid(interaction_controller) else false
	set(value):
		if is_instance_valid(interaction_controller):
			interaction_controller.menu_open = value
var interaction_selection_latched: bool = false
var level_up_input_latched: bool = false

var current_boss: GloamGraveOx = null
var final_boss_spawned: bool = false
var north_gate: GloamGate = null
var east_gate: GloamGate = null
var north_breach_marker: Node2D = null
var east_breach_marker: Node2D = null
var active_fortification: Node2D = null

var shrine_active: bool = false
var shrine_night_guard_bonus: int:
	get:
		return shrine_manager.active_ward_bonus if is_instance_valid(shrine_manager) else 0
	set(value):
		if is_instance_valid(shrine_manager):
			shrine_manager.active_ward_bonus = maxi(0, value)
var final_night_survival_complete: bool = false
var final_boss_defeated: bool = false
var dusk_return_pending: bool = false
var skip_confirmation_time_left: float = 0.0

var current_upgrade_choices: Array[String]:
	get:
		return progression_manager.current_choices if is_instance_valid(progression_manager) else []
	set(value):
		if is_instance_valid(progression_manager):
			progression_manager.current_choices = value

func _ready() -> void:
	# Script-driven verification/capture processes must never read, overwrite, or
	# clear a player's real user:// checkpoint.
	checkpoint_enabled = checkpoint_enabled and not OS.get_cmdline_args().has("--script")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if exploration_debug_seed != 0:
		rng.seed = exploration_debug_seed
		exploration_seed = exploration_debug_seed
	else:
		rng.randomize()
		var seed_rng := RandomNumberGenerator.new()
		seed_rng.randomize()
		exploration_seed = seed_rng.randi()

	DAY_EXPLORATION_LAYOUT.create_day_obstacles(day_obstacles)
	DAY_EXPLORATION_LAYOUT.set_day_obstacles_active(day_obstacles, true)
	world_visuals.set_layout_seed(exploration_seed)
	_bind_authored_world()

	if upgrade_debug_seed != 0:
		upgrade_rng.seed = upgrade_debug_seed
	else:
		upgrade_rng.randomize()

	phase_timer.one_shot = true
	phase_timer.timeout.connect(_on_phase_timer_timeout)
	_setup_run_phase_director()
	_setup_wave_director()

	player.xp_changed.connect(_update_xp_ui)
	player.leveled_up.connect(_on_player_leveled_up)
	player.health_changed.connect(_update_player_hp_ui)
	player.downed.connect(_on_player_downed)
	player.respawn_countdown_changed.connect(_on_player_respawn_countdown_changed)
	player.respawned.connect(_on_player_respawned)
	player.build_changed.connect(_update_build_ui)
	settlement_state.changed.connect(_on_settlement_state_changed)

	village_core.health_changed.connect(_update_core_hp_ui)
	village_core.destroyed.connect(_on_village_core_destroyed)

	sword_button.pressed.connect(func(): _choose_starting_weapon("sword"))
	bow_button.pressed.connect(func(): _choose_starting_weapon("bow"))
	spear_button.pressed.connect(func(): _choose_starting_weapon("spear"))

	assign_worker_button.pressed.connect(func(): _assign_villager("worker"))
	assign_guard_button.pressed.connect(func(): _assign_villager("guard"))
	assign_archer_button.pressed.connect(func(): _assign_villager("archer"))
	manage_village_button.pressed.connect(_toggle_village_management)
	skip_to_night_button.pressed.connect(_on_skip_to_night_pressed)

	upgrade_button_1.pressed.connect(func(): _choose_upgrade(0))
	upgrade_button_2.pressed.connect(func(): _choose_upgrade(1))
	upgrade_button_3.pressed.connect(func(): _choose_upgrade(2))

	restart_button.pressed.connect(_return_to_title)
	victory_restart_button.pressed.connect(_return_to_title)

	level_up_panel.hide()
	level_ready_label.hide()
	game_over_panel.hide()
	victory_panel.hide()
	downed_label.hide()
	build_panel.hide()
	village_build_panel.hide()
	fortification_panel.hide()
	shrine_panel.hide()
	boss_panel.hide()
	return_panel.hide()
	population_panel.hide()
	buildings_panel.hide()
	resource_strip.hide()
	manage_village_button.hide()
	skip_to_night_button.hide()
	element_panel.hide()
	dusk_tint.color = Color(0, 0, 0, 0)

	_setup_exploration_controller()
	_setup_shrine_manager()
	_spawn_shrine()
	_setup_hud_controller()

	_update_xp_ui(player.xp, player.xp_to_next, player.level)
	_update_player_hp_ui(player.hp, player.max_hp)
	_update_build_ui()
	_update_core_hp_ui(village_core.hp, village_core.max_hp)
	_apply_ui_style()
	_update_resource_ui()
	_update_population_ui()
	_update_buildings_ui()

	_setup_night_presentation_controller()
	_setup_world_camera()
	_setup_night_readability_visuals()
	_setup_contextual_interaction_ui()
	_setup_construction_manager()
	_setup_population_manager()
	_setup_interaction_controller()
	_setup_progression_manager()
	_setup_pause_menu()
	ui_input_contract = UI_INPUT_CONTRACT.new() as RefCounted
	ui_input_contract.configure($UI)
	if is_instance_valid(game_settings):
		game_settings.settings_changed.connect(_on_game_settings_changed)
		_on_game_settings_changed()
	_setup_title_menu()
	title_menu.open_menu(_has_valid_dawn_checkpoint())



func _show_modal_dimmer() -> void:
	modal_dimmer.show()
	if is_instance_valid(skip_to_night_button):
		skip_to_night_button.disabled = true
	_refresh_ui_input_contract()


func _hide_modal_dimmer() -> void:
	modal_dimmer.hide()
	_refresh_skip_to_night_control()
	_refresh_ui_input_contract()


func _refresh_ui_input_contract() -> void:
	if is_instance_valid(ui_input_contract):
		ui_input_contract.refresh()


func play_audio_hook(event_name: String, world_position: Vector2, intensity: float = 1.0) -> void:
	# Route all gameplay audio through the centralized generated-feedback bank.
	$AudioHooks.request(event_name, world_position, intensity)



func _apply_ui_style() -> void:
	if is_instance_valid(hud_controller):
		hud_controller.apply_visual_setup()


func _configure_interactive_controls() -> void:
	if is_instance_valid(hud_controller):
		hud_controller.configure_weapon_tooltips()


func _refresh_button_cursor(button: BaseButton) -> void:
	if is_instance_valid(hud_controller):
		hud_controller.refresh_button_cursor(button)


func _add_tiny_ui_frame(control: Control, is_button: bool) -> void:
	if is_instance_valid(hud_controller):
		hud_controller.add_tiny_ui_frame(control, is_button)


func _show_toast(message: String, tone: String = "info") -> void:
	if is_instance_valid(hud_controller):
		hud_controller.show_toast(message, tone)


func _setup_world_camera() -> void:
	if is_instance_valid(night_presentation_controller):
		world_camera = night_presentation_controller.setup_camera()


func _setup_night_readability_visuals() -> void:
	if is_instance_valid(night_presentation_controller):
		night_presentation_controller.setup_readability_visuals()
		night_lane_visuals = night_presentation_controller.lane_visuals
		night_threat_overlay = night_presentation_controller.threat_overlay


func _setup_night_presentation_controller() -> void:
	night_presentation_controller = NIGHT_PRESENTATION_CONTROLLER.new() as GloamNightPresentationController
	night_presentation_controller.name = "NightPresentationController"
	add_child(night_presentation_controller)
	night_presentation_controller.configure(
		player,
		village_core,
		$Enemies,
		$UI,
		north_gate,
		east_gate,
		north_breach_marker,
		east_breach_marker,
		world_size,
		phase_label,
		return_panel,
		return_label,
		objective_label,
		dusk_tint,
		world_light,
		Callable(self, "_presentation_phase"),
		Callable(self, "_presentation_day"),
		Callable(self, "_presentation_game_over")
	)


func _presentation_phase() -> int:
	return current_phase


func _presentation_day() -> int:
	return current_day


func _presentation_game_over() -> bool:
	return game_over


func _setup_contextual_interaction_ui() -> void:
	contextual_interaction_menu = CONTEXTUAL_INTERACTION_MENU.new() as GloamContextualInteractionMenu
	contextual_interaction_menu.name = "ContextualInteractionMenu"
	$UI.add_child(contextual_interaction_menu)
	_add_tiny_ui_frame(contextual_interaction_menu.menu_panel, false)
	_add_tiny_ui_frame(contextual_interaction_menu.prompt_button, true)


func _setup_pause_menu() -> void:
	pause_menu = PAUSE_MENU.new() as GloamPauseMenu
	pause_menu.name = "PauseMenu"
	$UI.add_child(pause_menu)
	var audio_settings: GloamAudioSettingsMenu = $AudioHooks.get("settings_menu") as GloamAudioSettingsMenu
	pause_menu.configure(self, audio_settings)


func _setup_title_menu() -> void:
	title_menu = TITLE_MENU.new() as GloamTitleMenu
	title_menu.name = "TitleMenu"
	$UI.add_child(title_menu)
	var audio_settings: GloamAudioSettingsMenu = $AudioHooks.get("settings_menu") as GloamAudioSettingsMenu
	title_menu.configure(self, audio_settings)
	_refresh_ui_input_contract()


func _has_valid_dawn_checkpoint() -> bool:
	return checkpoint_enabled and not run_checkpoint.load_latest_dawn().is_empty()


func start_new_run_from_title() -> void:
	if checkpoint_enabled:
		run_checkpoint.clear_run()
	if is_instance_valid(title_menu):
		title_menu.close_menu()
	get_tree().paused = false
	_open_weapon_choice()


func continue_run_from_title() -> void:
	if not _resume_latest_dawn():
		if is_instance_valid(title_menu):
			title_menu.open_menu(false)
		return
	if is_instance_valid(title_menu):
		title_menu.close_menu()


func _reset_run_metrics() -> void:
	run_started_at_msec = Time.get_ticks_msec()
	run_kills = 0
	run_rescues = 0
	run_structures_lost = 0


func _connect_run_structure_metrics() -> void:
	for defense: Node in $Defenses.get_children():
		if defense.has_signal("destroyed") and not defense.destroyed.is_connected(_on_run_structure_destroyed):
			defense.destroyed.connect(_on_run_structure_destroyed)


func _on_run_structure_destroyed(_structure: Node) -> void:
	run_structures_lost += 1


func _record_run_kill() -> void:
	run_kills += 1


func _run_duration_text() -> String:
	var elapsed_seconds := maxi(0, int((Time.get_ticks_msec() - run_started_at_msec) / 1000))
	return "%02d:%02d" % [elapsed_seconds / 60, elapsed_seconds % 60]


func _update_run_results(label: Label) -> void:
	if not is_instance_valid(label):
		return
	label.text = "Night reached: %d\nDuration: %s\nWeapon: %s  •  Level: %d\nKills: %d  •  Rescues: %d  •  Structures lost: %d" % [
		current_day,
		_run_duration_text(),
		str(player.weapon_type).capitalize(),
		player.level,
		run_kills,
		run_rescues,
		run_structures_lost,
	]


func _setup_run_phase_director() -> void:
	run_phase_director = RUN_PHASE_DIRECTOR.new() as GloamRunPhaseDirector
	run_phase_director.name = "RunPhaseDirector"
	run_phase_director.configure(nights_to_survive)
	add_child(run_phase_director)


func _setup_exploration_controller() -> void:
	exploration_controller = EXPLORATION_CONTROLLER.new() as GloamExplorationController
	exploration_controller.name = "ExplorationController"
	add_child(exploration_controller)
	exploration_controller.configure(
		player,
		$Resources,
		$DayEnemies,
		preload("res://scenes/resource_node.tscn"),
		preload("res://scenes/forest_enemy.tscn"),
		preload("res://scenes/mine_enemy.tscn"),
		preload("res://scenes/ruins_enemy.tscn"),
		zone_label,
		Callable(self, "_exploration_current_day"),
		Callable(self, "_exploration_seed")
	)


func _exploration_current_day() -> int:
	return current_day


func _exploration_seed() -> int:
	return exploration_seed


func _setup_hud_controller() -> void:
	hud_controller = HUD_CONTROLLER.new() as GloamHUDController
	hud_controller.name = "HUDController"
	add_child(hud_controller)
	hud_controller.configure(
		$UI,
		player,
		settlement_state,
		Callable(self, "_player_can_act"),
		Callable(self, "_is_day_phase"),
		Callable(self, "_is_player_in_village"),
		Callable(self, "_pending_upgrade_count"),
		Callable(self, "_is_village_management_open"),
		Callable(self, "_refresh_button_cursor")
	)


func _pending_upgrade_count() -> int:
	return pending_level_ups


func _is_village_management_open() -> bool:
	return village_management_open


func _setup_wave_director() -> void:
	wave_director = WAVE_DIRECTOR.new() as GloamWaveDirector
	wave_director.name = "WaveDirector"
	add_child(wave_director)
	wave_director.configure(
		Callable(self, "_spawn_enemy_in_lane"),
		Callable(self, "_spawn_grave_ox"),
		Callable(self, "_wave_director_can_progress"),
		Callable(self, "_wave_audio_position")
	)
	wave_director.wave_warning.connect(_on_wave_warning)
	wave_director.wave_progress.connect(_on_wave_progress)
	wave_director.breathing_room.connect(_on_wave_breathing_room)
	wave_director.hostile_count_changed.connect(_on_night_hostile_count_changed)
	wave_director.spawn_cap_reached.connect(_on_spawn_cap_reached)
	wave_director.spawn_work_completed.connect(_on_spawn_work_completed)
	wave_director.schedule_completed.connect(_finish_night)
	wave_director.wave_cancelled.connect(_on_wave_cancelled)


func _setup_construction_manager() -> void:
	construction_manager = CONSTRUCTION_MANAGER.new() as GloamConstructionManager
	construction_manager.name = "ConstructionManager"
	add_child(construction_manager)
	construction_manager.configure(
		settlement_state,
		player,
		$Soldiers,
		$Defenses,
		$VillageBuildings,
		$World/Regions/Village/VillageBuildSpots,
		build_prompt,
		village_build_prompt,
		{
			"archer": ARCHER_TOWER_SCENE,
			"barricade": BARRICADE_SCENE,
			"ballista": BALLISTA_SCENE,
		},
		{
			"house": HOUSE_SCENE,
			"farm": FARM_SCENE,
			"barracks": BARRACKS_BUILDING_SCENE,
			"blacksmith": BLACKSMITH_SCENE,
		},
		Callable(self, "_player_can_act"),
		Callable(self, "_is_day_phase"),
		Callable(self, "_show_toast"),
		Callable(self, "_update_resource_ui"),
		Callable(self, "_update_population_ui"),
		Callable(self, "_update_buildings_ui"),
		Callable(self, "play_audio_hook")
	)
	construction_manager.building_destroyed.connect(_on_village_building_destroyed)
	construction_manager.state_changed.connect(_on_construction_state_changed)


func _setup_population_manager() -> void:
	population_manager = POPULATION_MANAGER.new() as GloamPopulationManager
	population_manager.name = "PopulationManager"
	add_child(population_manager)
	population_manager.configure(
		settlement_state,
		player,
		$Survivors,
		$Soldiers,
		SURVIVOR_SCENE,
		GUARD_SCENE,
		ARCHER_SOLDIER_SCENE,
		world_visuals.marker_positions("survivor"),
		world_visuals.marker_positions("guard_post"),
		world_visuals.marker_positions("archer_post"),
		Callable(self, "_player_can_act"),
		Callable(self, "_is_day_phase"),
		Callable(self, "_set_objective_text"),
		Callable(self, "_show_toast"),
		Callable(self, "_update_resource_ui"),
		Callable(self, "_update_population_ui"),
		Callable(self, "play_audio_hook"),
		Callable(self, "_recalculate_settlement_state")
	)


func _setup_interaction_controller() -> void:
	interaction_controller = INTERACTION_CONTROLLER.new() as GloamInteractionController
	interaction_controller.name = "InteractionController"
	add_child(interaction_controller)
	interaction_controller.configure(
		player,
		$World/Regions/Village/DefenseBuildSpots,
		$World/Regions/Village/VillageBuildSpots,
		$Shrines,
		$World/Regions/Village/Gates,
		$World/Regions/Village/Walls,
		Callable(self, "_player_can_act"),
		Callable(self, "_is_day_phase"),
		Callable(self, "_is_contextual_menu_open"),
		contextual_interaction_menu,
		settlement_state,
		construction_manager,
		shrine_manager,
		Callable(self, "_execute_contextual_choice"),
		Callable(self, "_sync_contextual_target_references"),
		Callable(self, "_update_interaction_target"),
		Callable(self, "play_audio_hook")
	)


func _is_contextual_menu_open() -> bool:
	return interaction_menu_open


func _setup_progression_manager() -> void:
	progression_manager = PROGRESSION_MANAGER.new() as GloamProgressionManager
	progression_manager.name = "ProgressionManager"
	add_child(progression_manager)
	progression_manager.configure(
		player,
		upgrade_rng,
		[upgrade_button_1, upgrade_button_2, upgrade_button_3]
	)


func _setup_shrine_manager() -> void:
	shrine_manager = SHRINE_MANAGER.new() as GloamShrineManager
	shrine_manager.name = "ShrineManager"
	add_child(shrine_manager)
	shrine_manager.configure(
		settlement_state,
		player,
		$Shrines,
		$World/Regions/Village/Gates,
		$World/Regions/Village/Walls,
		SHRINE_SCENE,
		shrine_prompt,
		Callable(self, "_player_can_act"),
		Callable(self, "_show_toast"),
		Callable(self, "_set_objective_text"),
		Callable(self, "_update_resource_ui"),
		Callable(self, "_refresh_shrine_prompt")
	)


func _is_day_phase() -> bool:
	return current_phase == Phase.DAY


func _set_objective_text(text: String) -> void:
	objective_label.text = text


func _on_settlement_state_changed() -> void:
	# SettlementState is the source of truth; these callbacks only project its
	# current values into the visible HUD.
	_update_resource_ui()
	_update_population_ui()
	_update_buildings_ui()


func _on_construction_state_changed() -> void:
	_update_resource_ui()
	_update_population_ui()
	_update_buildings_ui()


func _wave_director_can_progress() -> bool:
	return not game_over and current_phase == Phase.NIGHT


func _on_wave_warning(
	wave_number: int,
	total_waves: int,
	lane_label: String,
	warning_text: String,
	audio_position: Vector2
) -> void:
	wave_label.text = "WAVE %d / %d  •  INCOMING  •  %s" % [wave_number, total_waves, lane_label]
	wave_label.add_theme_color_override("font_color", Color(0.96, 0.47, 0.35, 1.0))
	objective_label.text = "%s  •  Brace for impact" % warning_text
	if is_instance_valid(night_presentation_controller):
		night_presentation_controller.set_wave_telegraph(lane_label)
	_show_toast("Incoming from %s" % lane_label, "warning")
	play_audio_hook("wave_warning", audio_position, 1.0)


func _on_wave_progress(wave_number: int, total_waves: int, lane_label: String) -> void:
	wave_label.remove_theme_color_override("font_color")
	wave_label.text = "WAVE %d / %d  •  SPAWNING  •  %s" % [wave_number, total_waves, lane_label]
	objective_label.text = "Hold the passages"
	if is_instance_valid(night_presentation_controller):
		night_presentation_controller.clear_wave_telegraph()


func _on_wave_breathing_room() -> void:
	wave_label.text = "WAVE %d / %d  •  NEXT WAVE INCOMING" % [mini(wave_index + 1, wave_director.wave_plan.size()), wave_director.wave_plan.size()]
	objective_label.text = "Regroup while the next assault forms"


func _on_night_hostile_count_changed(alive: int, _pending: int) -> void:
	if current_phase == Phase.NIGHT:
		phase_time_label.text = "ENEMIES REMAINING: %d" % alive


func _on_spawn_cap_reached(alive: int, cap: int, pending: int) -> void:
	if current_phase == Phase.NIGHT:
		objective_label.text = "Pressure held at %d / %d  •  %d reinforcements waiting" % [alive, cap, pending]


func _on_spawn_work_completed() -> void:
	if current_phase != Phase.NIGHT:
		return
	wave_label.text = "WAVE %d / %d  •  ALL WAVES DEPLOYED" % [wave_director.wave_plan.size(), wave_director.wave_plan.size()]
	objective_label.text = "Eliminate every remaining hostile"


func _on_wave_cancelled(reason: String) -> void:
	print("[WaveLifecycle] pending wave work cancelled: %s" % reason)


func _on_game_settings_changed() -> void:
	if is_instance_valid(contextual_interaction_menu):
		contextual_interaction_menu.set_high_contrast(game_settings.high_contrast)
	if is_instance_valid(night_threat_overlay):
		night_threat_overlay.set_high_contrast(game_settings.high_contrast)


func can_open_settings() -> bool:
	return (
		not weapon_panel.visible
		and not level_up_panel.visible
		and not game_over_panel.visible
		and not victory_panel.visible
		and not interaction_menu_open
	)


func can_open_pause_menu() -> bool:
	return (
		run_started
		and not game_over
		and current_phase != Phase.VICTORY
		and can_open_settings()
		and not (is_instance_valid($AudioHooks.get("settings_menu")) and ($AudioHooks.get("settings_menu") as GloamAudioSettingsMenu).is_open())
	)


func _clamp_player_to_world() -> void:
	if is_instance_valid(night_presentation_controller):
		night_presentation_controller.clamp_player_to_world()


func _open_weapon_choice() -> void:
	if is_instance_valid(run_phase_director):
		run_phase_director.run_started = false

	phase_label.text = "GLOAM"
	phase_time_label.text = "--"
	objective_label.text = "Choose your starting weapon"
	weapon_label.text = "CHOOSE WEAPON"
	weapon_icon.hide()

	_show_modal_dimmer()
	weapon_panel.show()
	_refresh_ui_input_contract()
	UI_FOCUS.request(sword_button, weapon_panel.visible)
	get_tree().paused = true


func _choose_starting_weapon(weapon: String) -> void:
	# Choosing a weapon is the existing new-run boundary. Clear both generations
	# so a later reload cannot resurrect the previous run.
	if checkpoint_enabled:
		run_checkpoint.clear_run()
	_reset_run_metrics()
	if is_instance_valid(title_menu) and title_menu.menu_open:
		title_menu.close_menu()
	player.choose_weapon(weapon)
	play_audio_hook("ui_confirm", player.global_position, 0.85)
	weapon_panel.hide()
	_hide_modal_dimmer()

	get_tree().paused = false
	if is_instance_valid(run_phase_director):
		run_phase_director.start_run()

	_update_build_ui()
	_start_day()


func _process(_delta: float) -> void:
	_update_world_depth_sort()
	_refresh_skip_to_night_control()
	_refresh_manage_village_control()
	_refresh_ui_input_contract()
	_connect_run_structure_metrics()

	if not run_started or game_over or current_phase == Phase.VICTORY:
		return

	_clamp_player_to_world()
	_update_zone_status()
	_update_contextual_hud()
	_refresh_manage_village_control()
	_update_night_readability_visuals()
	_update_dusk_guidance()
	if dusk_return_pending and _is_player_in_village() and not get_tree().paused:
		_request_night_transition(false)
		return
	if skip_confirmation_time_left > 0.0:
		skip_confirmation_time_left = maxf(0.0, skip_confirmation_time_left - _delta)
		if skip_confirmation_time_left <= 0.0:
			_disarm_skip_confirmation()
	_handle_queued_upgrade_input()
	if not Input.is_action_pressed(INPUT_ACTIONS.VILLAGE_MANAGEMENT):
		village_management_input_latched = false

	if player.is_downed:
		_invalidate_contextual_interaction()

	if controls_hint_time_left > 0.0:
		controls_hint_time_left = maxf(0.0, controls_hint_time_left - _delta)
		controls_label.visible = controls_hint_time_left > 0.0

	if current_phase == Phase.DAY and phase_timer.time_left > 0.0:
		phase_time_label.text = "%02d" % int(ceil(phase_timer.time_left))

	if current_phase == Phase.DAY and not player.is_downed:
		_update_interaction_target()
	else:
		_invalidate_contextual_interaction()


func _update_world_depth_sort() -> void:
	# The gameplay managers retain their named roots for logic and tests, while
	# all visible roots share one world-space depth convention.  A foot/foundation
	# position is converted to an absolute z value so units can cross between
	# groups and pass naturally behind or in front of trees and buildings.
	for root_name: String in DEPTH_SORT_ROOTS:
		var root: Node = get_node_or_null(root_name)
		if not is_instance_valid(root):
			continue
		for child: Node in root.get_children():
			var item: CanvasItem = child as CanvasItem
			if not is_instance_valid(item) or not child is Node2D:
				continue
			item.z_as_relative = false
			item.z_index = int(round((child as Node2D).global_position.y))

	for actor: Node2D in [player, village_core]:
		if is_instance_valid(actor):
			actor.z_as_relative = false
			actor.z_index = int(round(actor.global_position.y))


func _input(event: InputEvent) -> void:
	if not INPUT_ACTIONS.observe_event(event):
		return

	if is_instance_valid(contextual_interaction_menu):
		contextual_interaction_menu.refresh_device_prompt()
	if is_instance_valid(active_interaction_target) and not interaction_menu_open:
		contextual_interaction_menu.set_prompt(_interaction_prompt_for(active_interaction_target), true)
	controls_label.text = INPUT_ACTIONS.controls_hint()
	if pending_level_ups > 0:
		level_ready_label.text = (
			"LEVEL UP READY  •  %s DURING DAY" % INPUT_ACTIONS.action_hint(INPUT_ACTIONS.LEVEL_UP)
			if current_phase == Phase.DAY
			else "LEVEL UP READY  •  CHOOSE AT DAWN"
		)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_released(INPUT_ACTIONS.VILLAGE_MANAGEMENT):
		village_management_input_latched = false

	if interaction_menu_open or not _player_can_act() or current_phase != Phase.DAY:
		return

	if event.is_action_pressed(INPUT_ACTIONS.VILLAGE_MANAGEMENT):
		if (
			_is_player_in_village()
			and not village_management_input_latched
			and not (event is InputEventKey and (event as InputEventKey).echo)
		):
			village_management_input_latched = true
			_toggle_village_management()
			get_viewport().set_input_as_handled()
		return

	if not event.is_action_pressed(INPUT_ACTIONS.INTERACT):
		return

	if is_instance_valid(active_interaction_target):
		_open_contextual_interaction()
		get_viewport().set_input_as_handled()



func _is_player_in_village() -> bool:
	return DAY_EXPLORATION_LAYOUT.is_village_position(player.global_position)


func _can_skip_to_night() -> bool:
	return _skip_to_night_block_reason().is_empty()


func _skip_to_night_block_reason() -> String:
	if not run_started:
		return "Start the run before ending the day."
	if current_phase != Phase.DAY:
		return "Skip to Night is only available during the day."
	if game_over or victory_panel.visible:
		return "The run is already complete."
	if dusk_return_pending or not _is_player_in_village():
		return "Return inside the village before starting the assault."
	if player.is_downed:
		return "You cannot end the day while downed."
	if get_tree().paused or modal_dimmer.visible:
		return "Close the current menu before ending the day."
	if village_management_open:
		return "Close village management before ending the day."
	if interaction_menu_open:
		return "Close the interaction menu before ending the day."
	if weapon_panel.visible or level_up_panel.visible or game_over_panel.visible:
		return "Close the current modal before ending the day."
	return ""


func _refresh_skip_to_night_control() -> void:
	if not is_instance_valid(skip_to_night_button):
		return
	var active_day: bool = run_started and current_phase == Phase.DAY and not game_over
	skip_to_night_button.visible = active_day
	skip_to_night_button.disabled = not _can_skip_to_night()
	if not active_day:
		_disarm_skip_confirmation()
		return
	var block_reason := _skip_to_night_block_reason()
	skip_to_night_button.tooltip_text = block_reason if not block_reason.is_empty() else "End the day early after a short confirmation."
	_refresh_button_cursor(skip_to_night_button)


func _on_skip_to_night_pressed() -> bool:
	if not _can_skip_to_night():
		_disarm_skip_confirmation()
		_show_toast(_skip_to_night_block_reason(), "warning")
		return false
	if skip_confirmation_time_left <= 0.0:
		skip_confirmation_time_left = SKIP_CONFIRMATION_SECONDS
		skip_to_night_button.text = "CONFIRM NIGHT?"
		play_audio_hook("ui_open", player.global_position, 0.55)
		return false
	_disarm_skip_confirmation()
	play_audio_hook("ui_confirm", player.global_position, 0.75)
	return _request_night_transition(true)


func _disarm_skip_confirmation() -> void:
	skip_confirmation_time_left = 0.0
	if is_instance_valid(skip_to_night_button):
		skip_to_night_button.text = "SKIP TO NIGHT"


func _request_night_transition(requested_by_skip: bool) -> bool:
	if game_over or current_phase != Phase.DAY or get_tree().paused:
		return false
	if requested_by_skip and not _is_player_in_village():
		return false
	if not _is_player_in_village():
		# Natural expiry enters the existing dusk/return loop. The phase remains
		# traversable until the player crosses back into the village.
		dusk_return_pending = true
		phase_timer.stop()
		_disarm_skip_confirmation()
		_refresh_skip_to_night_control()
		night_presentation_controller.update_dusk_guidance(0.0)
		return false
	_start_night()
	return true


func _player_can_act() -> bool:
	return (
		is_instance_valid(player)
		and not player.is_downed
		and not game_over
		and current_phase != Phase.VICTORY
	)


func can_player_respawn() -> bool:
	return (
		run_started
		and not game_over
		and current_phase != Phase.VICTORY
		and is_instance_valid(village_core)
		and village_core.hp > 0
	)


func _update_contextual_hud() -> void:
	if is_instance_valid(hud_controller):
		hud_controller.update_contextual(current_phase, player.is_downed, level_up_panel.visible)


func _toggle_village_management() -> void:
	if not _player_can_act() or not _is_player_in_village() or interaction_menu_open or modal_dimmer.visible or get_tree().paused:
		return

	village_management_open = not village_management_open
	_set_village_management_layout(village_management_open)
	_refresh_skip_to_night_control()
	play_audio_hook(
		"ui_open" if village_management_open else "ui_cancel",
		player.global_position,
		0.60
	)
	_refresh_ui_input_contract()


func _refresh_manage_village_control() -> void:
	if not is_instance_valid(manage_village_button):
		return
	var active_day := run_started and current_phase == Phase.DAY and not game_over
	manage_village_button.visible = active_day
	if not active_day:
		manage_village_button.disabled = true
		return

	var reason := ""
	if player.is_downed:
		reason = "Cannot manage the village while downed."
	elif not _is_player_in_village():
		reason = "Return to the village to manage villagers."
	elif interaction_menu_open:
		reason = "Close the interaction menu before managing the village."
	elif modal_dimmer.visible or get_tree().paused:
		reason = "Close the current menu before managing the village."

	manage_village_button.disabled = not reason.is_empty()
	manage_village_button.tooltip_text = reason if not reason.is_empty() else (
		"Close village management." if village_management_open else "Open village assignments and settlement details."
	)
	_refresh_button_cursor(manage_village_button)


func _set_village_management_layout(open: bool) -> void:
	village_management_open = open
	if is_instance_valid(hud_controller):
		hud_controller.set_village_management_layout(open)


func _handle_queued_upgrade_input() -> void:
	if not _player_can_act():
		level_up_input_latched = Input.is_action_pressed(INPUT_ACTIONS.LEVEL_UP)
		return

	if pending_level_ups <= 0 or level_up_panel.visible:
		level_up_input_latched = Input.is_action_pressed(INPUT_ACTIONS.LEVEL_UP)
		return

	var upgrade_pressed: bool = Input.is_action_pressed(INPUT_ACTIONS.LEVEL_UP)

	if not upgrade_pressed:
		level_up_input_latched = false
		return

	if not level_up_input_latched and current_phase == Phase.DAY:
		level_up_input_latched = true
		_open_level_up_panel(player.level)


func _update_dusk_guidance() -> void:
	if is_instance_valid(night_presentation_controller):
		night_presentation_controller.update_dusk_guidance(phase_timer.time_left)


func _direction_arrow(direction: Vector2) -> String:
	if is_instance_valid(night_presentation_controller):
		return night_presentation_controller._direction_arrow(direction)
	return "•"


func _set_night_readability(active: bool) -> void:
	if is_instance_valid(night_presentation_controller):
		night_presentation_controller.set_night_readability(active)


func _update_night_readability_visuals() -> void:
	if is_instance_valid(night_presentation_controller):
		night_presentation_controller.update_night_readability()


func _find_offscreen_lane_threat(gate: Node2D, lane: String) -> Dictionary:
	if is_instance_valid(night_presentation_controller):
		return night_presentation_controller._find_offscreen_lane_threat(gate, lane)
	return {}


func _start_day(resuming_checkpoint: bool = false) -> void:
	_invalidate_contextual_interaction()
	village_management_input_latched = false
	dusk_return_pending = false
	_disarm_skip_confirmation()
	if is_instance_valid(run_phase_director) and current_phase != Phase.DAY:
		run_phase_director.enter_day()
	DAY_EXPLORATION_LAYOUT.set_day_obstacles_active(day_obstacles, true)
	var safe_player_position: Vector2 = DAY_EXPLORATION_LAYOUT.get_safe_position(player.global_position)
	if safe_player_position != player.global_position:
		# Future temporary blockers may be absent at night. Permanent terrain and
		# prop collisions never switch off, so only temporary volumes need recovery.
		player.global_position = safe_player_position
		player.velocity = Vector2.ZERO
	_set_night_readability(false)
	player.begin_day_respawn_cycle()
	for soldier in $Soldiers.get_children():
		if soldier.has_method("set_night_combat_active"):
			soldier.set_night_combat_active(false)

	wave_director.reset_for_day()

	_clear_all_enemies()
	_clear_day_enemies()
	_spawn_day_resources()
	_spawn_survivors()
	_spawn_day_enemies()

	if current_day > 1 and not resuming_checkpoint:
		_apply_worker_income()

	boss_panel.hide()
	current_boss = null
	final_boss_spawned = false
	final_night_survival_complete = false
	final_boss_defeated = false

	phase_label.text = "DAY %d" % current_day
	objective_label.text = "Explore • gather • return before dusk"
	wave_label.text = "No assault"
	zone_label.text = "VILLAGE • Safe"

	controls_hint_time_left = 0.0
	controls_label.hide()
	return_panel.hide()
	_update_population_ui()
	_update_contextual_hud()
	phase_timer.start(day_duration)
	_refresh_skip_to_night_control()

	if pending_level_ups > 0:
		_show_toast("Level up ready - press L when you are ready", "success")

	# This is the only automatic write site. At this point the old night has
	# been cancelled and cleared, dawn income has settled, and the new daytime
	# world has been reconstructed.
	if run_started and not resuming_checkpoint:
		_save_dawn_checkpoint()


func _start_night() -> void:
	# The control disappears before any world mutation, regardless of whether
	# this transition came from expiry, dusk return, or confirmed skipping.
	skip_to_night_button.hide()
	_disarm_skip_confirmation()
	dusk_return_pending = false
	_invalidate_contextual_interaction()
	# Context cleanup refreshes daytime HUD controls while the phase director is
	# still on DAY; keep the transition's explicit hide authoritative.
	skip_to_night_button.hide()
	village_management_input_latched = false
	if is_instance_valid(run_phase_director):
		run_phase_director.enter_night()
	DAY_EXPLORATION_LAYOUT.set_day_obstacles_active(day_obstacles, false)
	_set_night_readability(true)
	player.begin_night_respawn_cycle()
	for soldier in $Soldiers.get_children():
		if soldier.has_method("set_night_combat_active"):
			soldier.set_night_combat_active(true)

	_clear_day_resources()
	_clear_survivors()
	_clear_day_enemies()
	build_panel.hide()
	village_build_panel.hide()
	fortification_panel.hide()
	shrine_panel.hide()
	shrine_active = false
	active_fortification = null
	active_build_spot = null
	active_village_build_spot = null
	_update_population_ui()

	_apply_shrine_ward_to_fortifications()

	phase_label.text = "NIGHT %d / %d" % [current_day, nights_to_survive]
	phase_time_label.text = "ENEMIES REMAINING: 0"
	objective_label.text = "Prepare for the first assault"
	wave_label.text = "WAVE 1 / %d  •  INCOMING" % _get_wave_plan().size()

	return_panel.hide()
	# Keep the village approach readable without turning the fight into a distant
	# strategy view. Off-screen threats are called out by the edge overlay.
	_update_contextual_hud()
	phase_timer.stop()
	wave_director.start_night(current_day, night_duration, final_boss_spawn_delay)


func _spawn_enemy_in_lane(lane: String, family: String = "") -> bool:
	if game_over or current_phase != Phase.NIGHT:
		return false

	var chosen_scene: PackedScene = _choose_enemy_scene(family)
	var enemy: GloamEnemy = chosen_scene.instantiate() as GloamEnemy
	enemy.move_speed *= NIGHT_ENEMY_MOVEMENT_MULTIPLIER
	var authored_spawn: Dictionary = world_visuals.choose_night_spawn(lane, rng)
	if authored_spawn.is_empty():
		enemy.queue_free()
		return false
	enemy.global_position = authored_spawn["position"]
	enemy.set_approach_path(authored_spawn["waypoints"])

	if enemy.has_method("set_targets"):
		enemy.set_targets(village_core, player)

	if enemy.has_method("set_lane"):
		if lane == "north":
			enemy.set_lane(north_gate, north_breach_marker)
		else:
			enemy.set_lane(east_gate, east_breach_marker)

	$Enemies.add_child(enemy)
	enemy.defeated.connect(_on_night_hostile_defeated, CONNECT_ONE_SHOT)
	if not wave_director.register_required_hostile(enemy):
		enemy.queue_free()
		return false
	if enemy.has_method("set_night_readability"):
		enemy.set_night_readability(true)
	return true


func _get_wave_plan() -> Array[Dictionary]:
	return wave_director.get_wave_plan(current_day, final_boss_spawn_delay)


func _wave_audio_position(wave: Dictionary) -> Vector2:
	return world_visuals.get_night_spawn_edge_position(str(wave.get("lane", "north")))


func _on_night_hostile_defeated(enemy: GloamEnemy) -> void:
	if is_instance_valid(wave_director):
		if wave_director.mark_required_hostile_killed(enemy):
			_record_run_kill()


func _cancel_pending_wave_work(reason: String) -> void:
	wave_director.cancel_pending_work(reason)


func _finish_night() -> void:
	if game_over or current_phase != Phase.NIGHT or night_finish_started or not night_schedule_complete:
		return

	night_finish_started = true

	if current_day == nights_to_survive:
		# The director emits only after every ordinary hostile and the boss has
		# reported its required death.
		final_night_survival_complete = true
		_try_complete_victory()
		return

	if is_instance_valid(run_phase_director):
		run_phase_director.complete_regular_night()
	_start_day()


func _on_phase_timer_timeout() -> void:
	if game_over:
		return

	match current_phase:
		Phase.DAY:
			_request_night_transition(false)
		Phase.NIGHT:
			# Night transitions come only from _complete_night_schedule(). The phase
			# timer is stopped during nights, so this branch is intentionally inert.
			return


func _spawn_grave_ox() -> bool:
	if game_over or current_phase != Phase.NIGHT or current_day != nights_to_survive:
		return false

	if final_boss_spawned or final_boss_defeated or is_instance_valid(current_boss):
		return false

	var boss: GloamGraveOx = GRAVE_OX_SCENE.instantiate() as GloamGraveOx
	boss.global_position = world_visuals.get_boss_spawn_position()
	boss.set_targets(village_core, player)
	boss.set_lane(north_gate, north_breach_marker)
	boss.set_approach_path(world_visuals.get_approach_points("north_2"))

	boss.health_changed.connect(_update_boss_hp)
	boss.defeated.connect(_on_grave_ox_defeated)

	final_boss_spawned = true
	$Enemies.add_child(boss)
	if not wave_director.register_required_hostile(boss, true):
		boss.queue_free()
		final_boss_spawned = false
		return false
	boss.set_night_readability(true)
	current_boss = boss
	play_audio_hook("boss_spawn", boss.global_position, 1.0)

	boss_panel.show()
	boss_hp_label.text = "⚠ TROLL CHIEFTAIN  •  %d / %d" % [boss.max_hp, boss.max_hp]
	objective_label.text = "TROLL CHIEFTAIN HAS ARRIVED"
	return true


func _update_boss_hp(current_hp: int, max_hp: int) -> void:
	boss_hp_label.text = "⚠ TROLL CHIEFTAIN  •  %d / %d" % [current_hp, max_hp]


func _on_grave_ox_defeated() -> void:
	if game_over or current_phase == Phase.VICTORY or final_boss_defeated:
		return

	var defeated_boss: Node = current_boss
	final_boss_defeated = true
	if is_instance_valid(wave_director) and is_instance_valid(defeated_boss):
		if wave_director.mark_required_hostile_killed(defeated_boss):
			_record_run_kill()
	current_boss = null
	boss_panel.hide()

	if final_night_survival_complete:
		_try_complete_victory()
	else:
		objective_label.text = "Chieftain defeated  •  clear the remaining horde"
		wave_label.text = "BOSS DEFEATED"


func _exit_tree() -> void:
	# Scene reloads free this node while an awaited warning/gap may still exist.
	# Invalidate the token before the node disappears so no continuation can
	# spawn into a new scene instance.
	if is_instance_valid(player):
		player.cancel_respawn()

	if wave_waiting or wave_active or night_schedule_active:
		_cancel_pending_wave_work("scene reload or scene unload")




func _bind_authored_world() -> void:
	north_gate = $World/Regions/Village/Gates/NorthGate as GloamGate
	east_gate = $World/Regions/Village/Gates/EastGate as GloamGate
	north_breach_marker = $World/NightApproaches/BreachMarkers/NorthBreachMarker
	east_breach_marker = $World/NightApproaches/BreachMarkers/EastBreachMarker
	north_gate.health_changed.connect(_update_north_gate_ui)
	north_gate.destroyed.connect(_on_gate_destroyed)
	east_gate.health_changed.connect(_update_east_gate_ui)
	east_gate.destroyed.connect(_on_gate_destroyed)
	_update_north_gate_ui(north_gate.hp, north_gate.max_hp)
	_update_east_gate_ui(east_gate.hp, east_gate.max_hp)


func _update_north_gate_ui(current_hp: int, max_hp: int) -> void:
	var state: String = ""

	if is_instance_valid(north_gate) and north_gate.is_breached:
		state = " BREACHED"

	north_gate_label.text = "North Gate Lv.%d: %d / %d%s" % [
		north_gate.level if is_instance_valid(north_gate) else 1,
		current_hp,
		max_hp,
		state
	]


func _update_east_gate_ui(current_hp: int, max_hp: int) -> void:
	var state: String = ""

	if is_instance_valid(east_gate) and east_gate.is_breached:
		state = " BREACHED"

	east_gate_label.text = "East Gate Lv.%d: %d / %d%s" % [
		east_gate.level if is_instance_valid(east_gate) else 1,
		current_hp,
		max_hp,
		state
	]


func _on_gate_destroyed(gate: Node) -> void:
	run_structures_lost += 1
	if gate == north_gate:
		_update_north_gate_ui(0, gate.max_hp)
	elif gate == east_gate:
		_update_east_gate_ui(0, gate.max_hp)

	objective_label.text = "%s has been breached!" % gate.gate_name
	_show_toast("%s BREACHED" % gate.gate_name.to_upper(), "danger")


func _update_fortification_interaction() -> void:
	_update_interaction_target()


func _update_interaction_target() -> void:
	if not is_instance_valid(interaction_controller):
		return
	var target: Node2D = interaction_controller.find_target(active_shrine)
	if target == active_interaction_target:
		if is_instance_valid(target) and _player_can_act() and current_phase == Phase.DAY:
			contextual_interaction_menu.set_prompt(_interaction_prompt_for(target), true)
		return
	_set_active_interaction_target(target)


func _set_active_interaction_target(target: Node2D) -> void:
	if target == active_interaction_target:
		return
	if interaction_menu_open:
		_close_contextual_interaction(false)

	active_interaction_target = target
	active_fortification = null
	active_build_spot = null
	active_village_build_spot = null
	active_shrine = null
	shrine_active = false
	fortification_panel.hide()
	build_panel.hide()
	village_build_panel.hide()
	shrine_panel.hide()

	if target is GloamBuildSpot:
		active_build_spot = target as GloamBuildSpot
	elif target is GloamVillageBuildSpot:
		active_village_build_spot = target as GloamVillageBuildSpot
	elif target is GloamShrine:
		active_shrine = target as GloamShrine
		shrine_active = true
	else:
		active_fortification = target

	if is_instance_valid(target) and not interaction_menu_open and _player_can_act() and current_phase == Phase.DAY:
		contextual_interaction_menu.set_prompt(_interaction_prompt_for(target), true)
	else:
		contextual_interaction_menu.hide_prompt()


func _invalidate_contextual_interaction() -> void:
	_close_contextual_interaction(false)
	_set_active_interaction_target(null)
	active_fortification = null
	active_build_spot = null
	active_village_build_spot = null
	active_shrine = null
	shrine_active = false
	fortification_panel.hide()
	build_panel.hide()
	village_build_panel.hide()
	shrine_panel.hide()


func notify_interaction_target_changed() -> void:
	if interaction_menu_open:
		_close_contextual_interaction(false)
	if current_phase == Phase.DAY and _player_can_act():
		_update_interaction_target()


func _close_contextual_interaction(update_target: bool = true) -> void:
	if is_instance_valid(interaction_controller):
		interaction_controller.close_menu(update_target)
	_refresh_skip_to_night_control()
	_refresh_manage_village_control()


func _interaction_prompt_for(target: Node2D) -> String:
	var interact_hint: String = INPUT_ACTIONS.action_hint(INPUT_ACTIONS.INTERACT)
	if target is GloamBuildSpot:
		return "INTERACT  •  DEFENSE SPOT  [%s]" % interact_hint
	if target is GloamVillageBuildSpot:
		return "INTERACT  •  VILLAGE SPOT  [%s]" % interact_hint
	if target is GloamShrine:
		return "INTERACT  •  RUIN SHRINE  [%s]" % interact_hint
	if target.is_in_group("gates") or target.is_in_group("walls"):
		return "INTERACT  •  FORTIFICATION  [%s]" % interact_hint
	return "INTERACT  [%s]" % interact_hint


func _open_contextual_interaction() -> void:
	if is_instance_valid(interaction_controller):
		_update_interaction_target()
		interaction_controller.open_menu(active_interaction_target)
	_refresh_skip_to_night_control()
	_refresh_manage_village_control()


func _sync_contextual_target_references(target: Node2D = null) -> void:
	if is_instance_valid(target):
		active_interaction_target = target
	if active_interaction_target is GloamBuildSpot:
		active_build_spot = active_interaction_target as GloamBuildSpot
		active_village_build_spot = null
		active_fortification = null
		active_shrine = null
		return
	if active_interaction_target is GloamVillageBuildSpot:
		active_village_build_spot = active_interaction_target as GloamVillageBuildSpot
		active_build_spot = null
		active_fortification = null
		active_shrine = null
		return
	if active_interaction_target is GloamShrine:
		active_shrine = active_interaction_target as GloamShrine
		active_build_spot = null
		active_village_build_spot = null
		active_fortification = null
		return
	if is_instance_valid(active_interaction_target):
		active_fortification = active_interaction_target
		active_build_spot = null
		active_village_build_spot = null
		active_shrine = null


func _execute_contextual_choice(choice_id: String) -> bool:
	match choice_id:
		"build_archer":
			return _try_build("archer")
		"build_barricade":
			return _try_build("barricade")
		"build_ballista":
			return _try_build("ballista")
		"build_house":
			return _try_build_village_building("house")
		"build_farm":
			return _try_build_village_building("farm")
		"build_barracks":
			return _try_build_village_building("barracks")
		"build_blacksmith":
			return _try_build_village_building("blacksmith")
		"repair_fortification":
			return _repair_fortification()
		"upgrade_fortification":
			return _upgrade_fortification()
		"repair_defense":
			return _repair_defense()
		"upgrade_defense":
			return _upgrade_defense()
		"repair_village_building":
			return _repair_village_building()
		"upgrade_village_building":
			return _upgrade_village_building()
		"shrine_heal":
			return _buy_shrine_heal()
		"shrine_blessing":
			return _buy_shrine_blessing()
		"shrine_ward":
			return _buy_shrine_ward()
	return false


func _contextual_choices_for(target: Node2D) -> Array[Dictionary]:
	return interaction_controller.choices_for(target) if is_instance_valid(interaction_controller) else []


func _cost_text(cost: Dictionary) -> String:
	return ECONOMY_BALANCE.cost_text(cost)


func _resource_amount(resource_name: String) -> int:
	return int(settlement_state.call("resource_amount", resource_name))


func _cost_is_available(cost: Dictionary) -> bool:
	return bool(settlement_state.call("can_afford", cost))


func is_build_spot_affordable(village_spot: bool) -> bool:
	if not is_instance_valid(construction_manager) or current_phase != Phase.DAY:
		return false
	var kinds: Array[String] = []
	if village_spot:
		kinds.assign(["house", "farm", "barracks", "blacksmith"])
	else:
		kinds.assign(["archer", "barricade", "ballista"])
	for kind: String in kinds:
		var definition: Dictionary = (
			construction_manager.village_build_definition(kind)
			if village_spot
			else construction_manager.defense_build_definition(kind)
		)
		if not definition.is_empty() and _cost_is_available(definition["cost"]):
			return true
	return false


func _charge_cost(cost: Dictionary) -> void:
	settlement_state.call("charge", cost)


func _defense_build_definition(kind: String) -> Dictionary:
	return construction_manager.defense_build_definition(kind) if is_instance_valid(construction_manager) else {}


func _village_build_definition(kind: String) -> Dictionary:
	return construction_manager.village_build_definition(kind) if is_instance_valid(construction_manager) else {}


func _fortification_repair_cost(fortification: Node2D) -> Dictionary:
	if is_instance_valid(construction_manager):
		return construction_manager.fortification_repair_cost(fortification)
	return ECONOMY_BALANCE.defense_repair_cost(
		fortification.is_in_group("gates"),
		bool(fortification.get("is_breached"))
	)


func _fortification_upgrade_cost(fortification: Node2D) -> Dictionary:
	if is_instance_valid(construction_manager):
		return construction_manager.fortification_upgrade_cost(fortification)
	return ECONOMY_BALANCE.fortification_upgrade_cost(
		fortification.is_in_group("gates"),
		int(fortification.get("level")) + 1
	)


func _defense_repair_cost() -> Dictionary:
	return construction_manager.defense_repair_cost() if is_instance_valid(construction_manager) else {}


func _defense_upgrade_cost(next_level: int = 2) -> Dictionary:
	return construction_manager.defense_upgrade_cost(next_level) if is_instance_valid(construction_manager) else {}


func _village_repair_cost() -> Dictionary:
	return construction_manager.village_repair_cost() if is_instance_valid(construction_manager) else {}


func _village_upgrade_cost(kind: String, next_level: int = 2) -> Dictionary:
	return construction_manager.village_upgrade_cost(kind, next_level) if is_instance_valid(construction_manager) else {}


func _refresh_fortification_prompt() -> void:
	if not is_instance_valid(active_fortification):
		return

	var label: String = "Fortification"
	var hp: int = int(active_fortification.get("hp"))
	var max_hp: int = int(active_fortification.get("max_hp"))
	var level: int = int(active_fortification.get("level"))
	var breached: bool = bool(active_fortification.get("is_breached"))
	var repair_cost: Dictionary = _fortification_repair_cost(active_fortification)
	var upgrade_cost: Dictionary = _fortification_upgrade_cost(active_fortification)

	if active_fortification.is_in_group("gates"):
		label = active_fortification.gate_name
	else:
		label = active_fortification.wall_name

	var repair_text: String = "Repair [%s]" % _cost_text(repair_cost)

	if breached:
		repair_text = "Rebuild [%s]" % _cost_text(repair_cost)
	elif hp >= max_hp:
		repair_text = "Repair [FULL HP]"

	var upgrade_text: String = "MAX LEVEL"

	if bool(active_fortification.call("can_upgrade")):
		upgrade_text = "Upgrade [%s]" % _cost_text(upgrade_cost)
	elif breached:
		upgrade_text = "Repair before upgrading"

	fortification_prompt.text = (
        "%s  Lv.%d\nHP: %d / %d\n%s\n%s"
		% [label, level, hp, max_hp, repair_text, upgrade_text]
	)


func _repair_fortification() -> bool:
	if not _player_can_act():
		return false

	if not is_instance_valid(active_fortification):
		return false

	if not bool(active_fortification.get("is_breached")) and int(active_fortification.get("hp")) >= int(active_fortification.get("max_hp")):
		_refresh_fortification_prompt()
		return false

	var cost: Dictionary = _fortification_repair_cost(active_fortification)
	if not _cost_is_available(cost):
		fortification_prompt.text = "NOT ENOUGH RESOURCES TO REPAIR"
		return false

	_charge_cost(cost)
	active_fortification.call("repair_full")

	_update_resource_ui()

	if active_fortification == north_gate:
		_update_north_gate_ui(north_gate.hp, north_gate.max_hp)
	elif active_fortification == east_gate:
		_update_east_gate_ui(east_gate.hp, east_gate.max_hp)

	_refresh_fortification_prompt()
	return true


func _upgrade_fortification() -> bool:
	if not _player_can_act():
		return false

	if not is_instance_valid(active_fortification):
		return false

	if not bool(active_fortification.call("can_upgrade")):
		_refresh_fortification_prompt()
		return false

	var cost: Dictionary = _fortification_upgrade_cost(active_fortification)
	if not _cost_is_available(cost):
		fortification_prompt.text = "NOT ENOUGH RESOURCES TO UPGRADE"
		return false

	_charge_cost(cost)

	active_fortification.call("upgrade")
	_update_resource_ui()

	if active_fortification == north_gate:
		_update_north_gate_ui(north_gate.hp, north_gate.max_hp)
	elif active_fortification == east_gate:
		_update_east_gate_ui(east_gate.hp, east_gate.max_hp)

	_refresh_fortification_prompt()
	return true


func set_active_village_build_spot(spot: GloamVillageBuildSpot) -> void:
	if current_phase != Phase.DAY or not _player_can_act():
		return
	spot.set("player_inside", true)
	construction_manager.set_active_village_build_spot(spot)
	_set_active_interaction_target(spot)


func clear_active_village_build_spot(spot: GloamVillageBuildSpot) -> void:
	spot.set("player_inside", false)
	construction_manager.clear_active_village_build_spot(spot)
	if active_village_build_spot == spot or active_interaction_target == spot:
		_set_active_interaction_target(null)
		_update_interaction_target()


func _try_build_village_building(kind: String) -> bool:
	if not is_instance_valid(construction_manager):
		return false
	var built: bool = construction_manager.try_build_village_building(kind)
	if built:
		village_build_panel.hide()
	return built


func set_active_build_spot(spot: GloamBuildSpot) -> void:
	if current_phase != Phase.DAY or not _player_can_act():
		return
	spot.set("player_inside", true)
	construction_manager.set_active_build_spot(spot)
	_set_active_interaction_target(spot)


func clear_active_build_spot(spot: GloamBuildSpot) -> void:
	spot.set("player_inside", false)
	construction_manager.clear_active_build_spot(spot)
	if active_build_spot == spot or active_interaction_target == spot:
		_set_active_interaction_target(null)
		_update_interaction_target()


func _try_build(kind: String) -> bool:
	if not is_instance_valid(construction_manager):
		return false
	var built: bool = construction_manager.try_build(kind)
	if built:
		build_panel.hide()
	return built



func _refresh_defense_management_prompt() -> void:
	if is_instance_valid(construction_manager):
		construction_manager.refresh_defense_prompt()


func _repair_defense() -> bool:
	return construction_manager.repair_fortification() if is_instance_valid(construction_manager) else false


func _upgrade_defense() -> bool:
	return construction_manager.upgrade_fortification() if is_instance_valid(construction_manager) else false


func _refresh_village_management_prompt() -> void:
	if is_instance_valid(construction_manager):
		construction_manager.refresh_village_prompt()


func _village_upgrade_cost_text(kind: String, next_level: int = 2) -> String:
	return "[%s]" % _cost_text(_village_upgrade_cost(kind, next_level))


func _repair_village_building() -> bool:
	return construction_manager.repair_village_building() if is_instance_valid(construction_manager) else false


func _upgrade_village_building() -> bool:
	return construction_manager.upgrade_village_building() if is_instance_valid(construction_manager) else false


func _on_village_building_destroyed(
	building: GloamVillageBuilding,
	released_spot: GloamVillageBuildSpot = null
) -> void:
	if not is_instance_valid(building):
		return
	run_structures_lost += 1

	objective_label.text = "%s was destroyed!" % building.display_name
	_show_toast("%s destroyed" % building.display_name, "danger")

	_update_population_ui()
	_update_buildings_ui()
	call_deferred("_refresh_released_village_build_spot", released_spot, building.display_name)


func _recalculate_settlement_state(destroyed_building: GloamVillageBuilding = null) -> void:
	if is_instance_valid(construction_manager):
		construction_manager.recalculate(destroyed_building)


func _refresh_released_village_build_spot(
	released_spot: GloamVillageBuildSpot,
	building_name: String
) -> void:
	if current_phase != Phase.DAY:
		return

	if is_instance_valid(released_spot) and active_village_build_spot == released_spot:
		set_active_village_build_spot(released_spot)
	elif not is_instance_valid(active_village_build_spot):
		village_build_prompt.text = "%s destroyed. Build a replacement when ready." % building_name



func _update_zone_status() -> void:
	if is_instance_valid(exploration_controller):
		exploration_controller.update_zone_status(current_phase == Phase.DAY)


func _spawn_day_enemies() -> void:
	if is_instance_valid(exploration_controller):
		exploration_controller.spawn_day_enemies()


func _clear_day_enemies() -> void:
	if is_instance_valid(exploration_controller):
		exploration_controller.clear_day_enemies()


func grant_exploration_reward(resource_type: String, amount: int) -> void:
	if not bool(settlement_state.call("grant", resource_type, amount)):
		return

	_update_resource_ui()



func _spawn_shrine() -> void:
	if is_instance_valid(shrine_manager):
		shrine_manager.spawn_shrine()


func set_shrine_active(active: bool, shrine: GloamShrine = null) -> void:
	if is_instance_valid(shrine):
		active_shrine = shrine if active else null
	elif active and not is_instance_valid(active_shrine):
		for candidate: Node in $Shrines.get_children():
			if is_instance_valid(candidate) and bool(candidate.get("player_inside")):
				active_shrine = candidate as GloamShrine
				break
	shrine_active = active and current_phase == Phase.DAY and _player_can_act()

	if shrine_active and is_instance_valid(active_shrine):
		_set_active_interaction_target(active_shrine)
	else:
		shrine_panel.hide()
		if not active:
			if active_interaction_target == shrine:
				_set_active_interaction_target(null)
			_update_interaction_target()


func _refresh_shrine_prompt() -> void:
	if is_instance_valid(shrine_manager):
		shrine_manager.refresh()


func _buy_shrine_heal() -> bool:
	return shrine_manager.buy_heal() if is_instance_valid(shrine_manager) else false


func _buy_shrine_blessing() -> bool:
	return shrine_manager.buy_blessing(upgrade_rng) if is_instance_valid(shrine_manager) else false


func _buy_shrine_ward() -> bool:
	return shrine_manager.buy_ward() if is_instance_valid(shrine_manager) else false


func _apply_shrine_ward_to_fortifications() -> void:
	if is_instance_valid(shrine_manager):
		shrine_manager.apply_ward_to_fortifications()


func _spawn_survivors() -> void:
	if is_instance_valid(population_manager):
		population_manager.spawn_survivors()


func _clear_survivors() -> void:
	if is_instance_valid(population_manager):
		population_manager.clear_survivors()


func try_rescue_villager() -> bool:
	var rescued := population_manager.try_rescue_villager() if is_instance_valid(population_manager) else false
	if rescued:
		run_rescues += 1
	return rescued


func _assign_villager(role: String) -> void:
	if is_instance_valid(population_manager):
		population_manager.assign_villager(role)


func _spawn_soldier(role: String) -> void:
	if is_instance_valid(population_manager):
		population_manager.spawn_soldier(role)


func _on_soldier_killed(role: String) -> void:
	if is_instance_valid(population_manager):
		population_manager.on_soldier_killed(role)


func _apply_worker_income() -> void:
	if is_instance_valid(population_manager):
		population_manager.apply_worker_income()


func _update_population_ui() -> void:
	if is_instance_valid(hud_controller):
		hud_controller.update_population()


func _update_buildings_ui() -> void:
	if is_instance_valid(hud_controller):
		hud_controller.update_buildings()


func _spawn_day_resources() -> void:
	if is_instance_valid(exploration_controller):
		exploration_controller.spawn_day_resources()


func _clear_day_resources() -> void:
	if is_instance_valid(exploration_controller):
		exploration_controller.clear_day_resources()


func try_collect_resource(resource_type: String, amount: int) -> bool:
	if not _player_can_act() or current_phase != Phase.DAY:
		return false
	return bool(settlement_state.call("grant", resource_type, amount))


func _update_resource_ui() -> void:
	if is_instance_valid(hud_controller):
		hud_controller.update_resource()

func _choose_enemy_scene(family: String = "") -> PackedScene:
	match family:
		"grunt": return GRUNT_SCENE
		"runner": return RUNNER_SCENE
		"brute": return BRUTE_SCENE
		"ranged": return RANGED_ENEMY_SCENE
	var roll: float = rng.randf()

	match current_day:
		1:
			return GRUNT_SCENE

		2:
			if roll < 0.70:
				return GRUNT_SCENE
			return RUNNER_SCENE

		_:
			if roll < 0.45:
				return GRUNT_SCENE
			elif roll < 0.70:
				return RUNNER_SCENE
			elif roll < 0.90:
				return BRUTE_SCENE
			return RANGED_ENEMY_SCENE


func _clear_all_enemies() -> void:
	for enemy in $Enemies.get_children():
		enemy.queue_free()




func _update_xp_ui(current_xp: int, required_xp: int, current_level: int) -> void:
	if is_instance_valid(hud_controller):
		hud_controller.update_xp(current_xp, required_xp, current_level)


func _update_player_hp_ui(current_hp: int, max_hp: int) -> void:
	if is_instance_valid(hud_controller):
		hud_controller.update_hp(current_hp, max_hp)


func _update_build_ui() -> void:
	if is_instance_valid(hud_controller):
		hud_controller.update_build()


func _update_core_hp_ui(current_hp: int, max_hp: int) -> void:
	if is_instance_valid(hud_controller):
		hud_controller.update_core(current_hp, max_hp)


func _on_player_downed() -> void:
	if game_over:
		return

	_update_downed_ui(
		player.respawn_time_left,
		player.respawn_duration,
		player.respawn_down_number,
		player.get_next_respawn_delay()
	)
	downed_label.show()


func _on_player_respawn_countdown_changed(
	time_left: float,
	duration: float,
	down_number: int,
	next_delay: float
) -> void:
	if game_over or current_phase == Phase.VICTORY or not player.is_downed:
		return

	_update_downed_ui(time_left, duration, down_number, next_delay)


func _update_downed_ui(
	time_left: float,
	duration: float,
	down_number: int,
	next_delay: float
) -> void:
	if is_instance_valid(hud_controller):
		hud_controller.update_downed(time_left, duration, down_number, next_delay)


func _on_player_respawned() -> void:
	downed_label.hide()


func _on_player_leveled_up(new_level: int) -> void:
	if game_over or current_phase == Phase.VICTORY:
		return

	if is_instance_valid(progression_manager):
		progression_manager.queue_upgrade()
	_update_contextual_hud()

	if current_phase == Phase.NIGHT:
		_show_toast("Level %d earned - choose it safely at dawn" % new_level, "success")
	else:
		_show_toast(
			"Level %d earned - use %s when ready" % [
				new_level,
				INPUT_ACTIONS.action_hint(INPUT_ACTIONS.LEVEL_UP)
			],
			"success"
		)


func _open_level_up_panel(current_level: int) -> void:
	if not _player_can_act():
		return

	level_up_title.text = "LEVEL %d  •  SAFE UPGRADE\nCHOOSE YOUR PATH" % current_level
	_roll_upgrade_choices()

	_show_modal_dimmer()
	level_up_panel.show()
	_refresh_ui_input_contract()
	UI_FOCUS.request(upgrade_button_1, level_up_panel.visible)
	get_tree().paused = true
	play_audio_hook("ui_open", player.global_position, 0.70)


func _roll_upgrade_choices() -> void:
	if is_instance_valid(progression_manager):
		progression_manager.roll_choices()

	_refresh_upgrade_buttons()


func _refresh_upgrade_buttons() -> void:
	if is_instance_valid(progression_manager):
		progression_manager.refresh_buttons()


func _choose_upgrade(index: int) -> void:
	if not _player_can_act():
		return

	if index < 0 or index >= current_upgrade_choices.size():
		return

	if not is_instance_valid(progression_manager) or not progression_manager.try_apply(index):
		_roll_upgrade_choices()
		return
	play_audio_hook("ui_confirm", player.global_position, 0.80)
	_finish_upgrade_choice()


func _finish_upgrade_choice() -> void:
	if is_instance_valid(progression_manager):
		progression_manager.consume_upgrade()
	_update_build_ui()
	_update_contextual_hud()

	if pending_level_ups > 0:
		level_up_title.text = "ANOTHER UPGRADE\nCHOOSE YOUR PATH"
		_roll_upgrade_choices()
	else:
		level_up_panel.hide()
		_hide_modal_dimmer()
		get_tree().paused = false
		_update_contextual_hud()


func _on_village_core_destroyed() -> void:
	if game_over or current_phase == Phase.VICTORY:
		return

	game_over = true
	skip_to_night_button.hide()
	_invalidate_contextual_interaction()
	_set_night_readability(false)
	player.cancel_respawn()
	_cancel_pending_wave_work("game over: village core destroyed")
	phase_timer.stop()

	_clear_day_resources()
	_clear_survivors()
	_clear_day_enemies()

	weapon_panel.hide()
	level_up_panel.hide()
	downed_label.hide()
	build_panel.hide()
	village_build_panel.hide()
	fortification_panel.hide()
	shrine_panel.hide()
	boss_panel.hide()

	_show_modal_dimmer()
	_update_run_results(game_over_results)
	game_over_panel.show()
	_refresh_ui_input_contract()
	UI_FOCUS.request(restart_button, game_over_panel.visible)
	get_tree().paused = true


func _try_complete_victory() -> void:
	if (
		game_over
		or current_phase != Phase.NIGHT
		or current_day != nights_to_survive
		or not final_night_survival_complete
		or not final_boss_defeated
	):
		return

	_win_run()


func _win_run() -> void:
	if (
		game_over
		or current_phase == Phase.VICTORY
		or current_day != nights_to_survive
		or not final_night_survival_complete
		or not final_boss_defeated
	):
		return

	if is_instance_valid(run_phase_director):
		run_phase_director.enter_victory()
	skip_to_night_button.hide()
	_invalidate_contextual_interaction()
	_set_night_readability(false)
	player.cancel_respawn()
	_cancel_pending_wave_work("victory")
	phase_timer.stop()

	_clear_all_enemies()
	_clear_day_resources()
	_clear_survivors()
	_clear_day_enemies()

	weapon_panel.hide()
	level_up_panel.hide()
	downed_label.hide()
	build_panel.hide()
	village_build_panel.hide()
	fortification_panel.hide()
	shrine_panel.hide()
	boss_panel.hide()

	_show_modal_dimmer()
	_update_run_results(victory_results)
	victory_panel.show()
	_refresh_ui_input_contract()
	UI_FOCUS.request(victory_restart_button, victory_panel.visible)
	get_tree().paused = true


func _save_dawn_checkpoint() -> bool:
	if not checkpoint_enabled or current_phase != Phase.DAY or game_over or not run_started:
		return false
	var saved := run_checkpoint.save_dawn(_capture_dawn_checkpoint())
	if not saved:
		push_warning("Run checkpoint was not saved: %s" % run_checkpoint.last_error)
	return saved


func _capture_dawn_checkpoint() -> Dictionary:
	return {
		"boundary": "dawn",
		"day": current_day,
		"completed_nights": completed_nights,
		"resources": {
			"wood": wood, "stone": stone, "iron": iron, "food": food, "essence": essence,
		},
		"population": {
			"total": total_population,
			"unassigned": unassigned_villagers,
			"workers": workers,
			"guards": guards,
			"archers": archers,
		},
		"structures": {
			"defenses": _capture_spot_structures($World/Regions/Village/DefenseBuildSpots, false),
			"village": _capture_spot_structures($World/Regions/Village/VillageBuildSpots, true),
		},
		"gates": _capture_gates(),
		"core": {"hp": village_core.hp, "max_hp": village_core.max_hp},
		"player": {
			"weapon": player.weapon_type,
			"level": player.level,
			"xp": player.xp,
			"xp_to_next": player.xp_to_next,
			"hp": maxi(1, player.hp),
			"max_hp": player.max_hp,
			"elements": player.get_elemental_levels(),
			"pending_level_ups": pending_level_ups,
		},
		"shrine": {"active_ward_bonus": shrine_night_guard_bonus},
		# Decimal strings preserve the full 64-bit RNG state through JSON.
		"seeds": {
			"exploration": str(exploration_seed),
			"combat_seed": str(rng.seed),
			"combat_state": str(rng.state),
			"upgrade_seed": str(upgrade_rng.seed),
			"upgrade_state": str(upgrade_rng.state),
		},
	}


func _capture_spot_structures(spots_root: Node, village: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for child: Node in spots_root.get_children():
		var structure: Node = child.get("building") if village else child.get("structure")
		if not is_instance_valid(structure) or structure.is_queued_for_deletion():
			continue
		result.append({
			"spot": str(child.name),
			"kind": str(child.get("building_kind") if village else child.get("structure_kind")),
			"level": int(structure.get("level")),
			"hp": int(structure.get("hp")),
			"max_hp": int(structure.get("max_hp")),
		})
	return result


func _capture_gates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for gate_node: Node in $World/Regions/Village/Gates.get_children():
		var gate := gate_node as GloamGate
		if not is_instance_valid(gate):
			continue
		result.append({
			"gate": str(gate.name),
			"level": gate.level,
			"hp": gate.hp,
			"max_hp": gate.max_hp,
			"breached": gate.is_breached,
		})
	return result


func _resume_latest_dawn() -> bool:
	var checkpoint := run_checkpoint.load_latest_dawn()
	if checkpoint.is_empty():
		if not run_checkpoint.last_error.is_empty():
			push_warning("Run checkpoint rejected: %s" % run_checkpoint.last_error)
		return false
	if not _apply_dawn_checkpoint(checkpoint):
		push_warning("Run checkpoint references unsupported game content; starting a new run instead.")
		return false
	if run_checkpoint.loaded_from_backup:
		_show_toast("Recovered the latest dawn from backup", "warning")
	return true


func _apply_dawn_checkpoint(checkpoint: Dictionary) -> bool:
	# Validate content identifiers against this build before mutating the scene.
	for entry: Dictionary in checkpoint["structures"]["defenses"]:
		var defense_spot := $World/Regions/Village/DefenseBuildSpots.get_node_or_null(NodePath(entry["spot"])) as GloamBuildSpot
		if not construction_manager.defense_scenes.has(entry["kind"]) or not is_instance_valid(defense_spot):
			return false
		if int(entry["level"]) > 3:
			return false
	for entry: Dictionary in checkpoint["structures"]["village"]:
		var village_spot := $World/Regions/Village/VillageBuildSpots.get_node_or_null(NodePath(entry["spot"])) as GloamVillageBuildSpot
		if not construction_manager.village_scenes.has(entry["kind"]) or not is_instance_valid(village_spot):
			return false
		if int(entry["level"]) > 3:
			return false
	var saved_gates: Array = checkpoint["gates"]
	if saved_gates.size() != $World/Regions/Village/Gates.get_child_count():
		return false
	for entry: Dictionary in checkpoint["gates"]:
		var saved_gate := $World/Regions/Village/Gates.get_node_or_null(NodePath(entry["gate"])) as GloamGate
		if not is_instance_valid(saved_gate) or int(entry["level"]) > saved_gate.max_level:
			return false

	current_day = int(checkpoint["day"])
	completed_nights = int(checkpoint["completed_nights"])
	run_phase_director.run_started = true
	run_phase_director.enter_day()
	var resources: Dictionary = checkpoint["resources"]
	wood = int(resources["wood"])
	stone = int(resources["stone"])
	iron = int(resources["iron"])
	food = int(resources["food"])
	essence = int(resources["essence"])
	var population: Dictionary = checkpoint["population"]
	total_population = int(population["total"])
	unassigned_villagers = int(population["unassigned"])
	workers = int(population["workers"])
	guards = int(population["guards"])
	archers = int(population["archers"])

	_restore_structures(checkpoint["structures"])
	_restore_gates(checkpoint["gates"])
	_recalculate_settlement_state()
	_restore_soldiers()

	var core: Dictionary = checkpoint["core"]
	village_core.max_hp = int(core["max_hp"])
	village_core.hp = int(core["hp"])
	village_core.health_changed.emit(village_core.hp, village_core.max_hp)
	var saved_player: Dictionary = checkpoint["player"]
	player.choose_weapon(saved_player["weapon"])
	player.level = int(saved_player["level"])
	player.xp = int(saved_player["xp"])
	player.xp_to_next = int(saved_player["xp_to_next"])
	player.max_hp = int(saved_player["max_hp"])
	player.hp = maxi(1, int(saved_player["hp"]))
	var elements: Dictionary = saved_player["elements"]
	player.fire_level = int(elements["fire"])
	player.water_level = int(elements["water"])
	player.earth_level = int(elements["earth"])
	player.air_level = int(elements["air"])
	player.call("_recalculate_combat_stats")
	player.set_settlement_damage_bonus(blacksmith_bonus_damage)
	pending_level_ups = int(saved_player["pending_level_ups"])
	shrine_night_guard_bonus = int(checkpoint["shrine"]["active_ward_bonus"])

	var seeds: Dictionary = checkpoint["seeds"]
	exploration_seed = (seeds["exploration"] as String).to_int()
	world_visuals.set_layout_seed(exploration_seed)
	rng.seed = (seeds["combat_seed"] as String).to_int()
	rng.state = (seeds["combat_state"] as String).to_int()
	upgrade_rng.seed = (seeds["upgrade_seed"] as String).to_int()
	upgrade_rng.state = (seeds["upgrade_state"] as String).to_int()

	weapon_panel.hide()
	_hide_modal_dimmer()
	_reset_run_metrics()
	get_tree().paused = false
	_start_day(true)
	_update_xp_ui(player.xp, player.xp_to_next, player.level)
	_update_player_hp_ui(player.hp, player.max_hp)
	_update_build_ui()
	_update_core_hp_ui(village_core.hp, village_core.max_hp)
	return true


func _restore_structures(saved: Dictionary) -> void:
	for child: Node in $Defenses.get_children():
		child.free()
	for child: Node in $VillageBuildings.get_children():
		child.free()
	for spot: Node in $World/Regions/Village/DefenseBuildSpots.get_children():
		spot.occupied = false
		spot.structure = null
		spot.structure_kind = ""
	for spot: Node in $World/Regions/Village/VillageBuildSpots.get_children():
		spot.occupied = false
		spot.building = null
		spot.building_kind = ""

	for entry: Dictionary in saved["defenses"]:
		var spot := $World/Regions/Village/DefenseBuildSpots.get_node(NodePath(entry["spot"])) as GloamBuildSpot
		var defense := (construction_manager.defense_scenes[entry["kind"]] as PackedScene).instantiate() as GloamDefense
		defense.global_position = spot.global_position
		$Defenses.add_child(defense)
		for _upgrade: int in range(1, int(entry["level"])):
			defense.upgrade()
		defense.max_hp = int(entry["max_hp"])
		defense.hp = int(entry["hp"])
		spot.assign_structure(defense, entry["kind"])
	for entry: Dictionary in saved["village"]:
		var spot := $World/Regions/Village/VillageBuildSpots.get_node(NodePath(entry["spot"])) as GloamVillageBuildSpot
		var building := (construction_manager.village_scenes[entry["kind"]] as PackedScene).instantiate() as GloamVillageBuilding
		building.global_position = spot.global_position
		building.destroyed.connect(construction_manager.handle_village_building_destroyed)
		$VillageBuildings.add_child(building)
		for _upgrade: int in range(1, int(entry["level"])):
			building.upgrade()
		building.max_hp = int(entry["max_hp"])
		building.hp = int(entry["hp"])
		spot.assign_building(building, entry["kind"])


func _restore_gates(saved: Array) -> void:
	for entry: Dictionary in saved:
		var gate := $World/Regions/Village/Gates.get_node(NodePath(entry["gate"])) as GloamGate
		gate.level = int(entry["level"])
		gate.max_hp = int(entry["max_hp"])
		gate.hp = int(entry["hp"])
		gate.is_breached = bool(entry["breached"])
		gate.blocker_shape.set_deferred("disabled", gate.is_breached)
		gate.call("_update_visual")
		gate.call("_update_health_bar")
		gate.health_changed.emit(gate.hp, gate.max_hp)


func _restore_soldiers() -> void:
	for child: Node in $Soldiers.get_children():
		child.free()
	for _guard: int in range(guards):
		population_manager.spawn_soldier("guard")
	for _archer: int in range(archers):
		population_manager.spawn_soldier("archer")


func _restart_game() -> void:
	if checkpoint_enabled:
		run_checkpoint.clear_run()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _return_to_title() -> void:
	# Terminal screens never replace a valid dawn silently. The title shell owns
	# the confirmation before New Run clears that checkpoint.
	get_tree().paused = false
	get_tree().reload_current_scene()
