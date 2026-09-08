extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const AUDIO_HOOKS := preload("res://scripts/audio_hooks.gd")
const AUDIO_MANIFEST := preload("res://scripts/audio_asset_manifest.gd")

const TEST_SETTINGS_PATH: String = "user://gloam_audio_verification.cfg"
const BUS_NAMES: Array[String] = ["Master", "Music", "SFX", "UI"]
const MAJOR_EVENTS: Array[String] = [
	"player_attack",
	"defense_attack",
	"enemy_hit",
	"enemy_death",
	"player_hit",
	"player_downed",
	"gate_damage",
	"gate_destroyed",
	"structure_damage",
	"structure_destroyed",
	"core_damage",
	"core_destroyed",
	"resource_collect",
	"survivor_rescued",
	"soldier_death",
	"wave_warning",
	"boss_spawn",
	"boss_hit",
	"boss_death"
]

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var router: GloamAudioHooks = AUDIO_HOOKS.new() as GloamAudioHooks
	router.settings_path = TEST_SETTINGS_PATH
	root.add_child(router)
	await process_frame

	for bus_name: String in BUS_NAMES:
		_check(AudioServer.get_bus_index(bus_name) >= 0, "audio bus exists: %s" % bus_name)
	_check(AudioServer.get_bus_send(AudioServer.get_bus_index("SFX")) == "Master", "SFX sends to Master")
	_check(AudioServer.get_bus_send(AudioServer.get_bus_index("UI")) == "Master", "UI sends to Master")

	var missing_events: Array[String] = []
	router.asset_missing.connect(func(event_name: String): missing_events.append(event_name))
	for event_name: String in MAJOR_EVENTS:
		router.request(event_name, Vector2(120.0, 220.0), 1.0)
		_check(missing_events.has(event_name), "uninstalled production asset is explicitly reported: %s" % event_name)
	_check(AUDIO_MANIFEST.REQUIRED_EVENTS.size() >= MAJOR_EVENTS.size() + 10, "manifest covers transitions, ambience, and restrained music")

	await create_timer(0.1).timeout
	var before_throttle: int = missing_events.size()
	router.request("enemy_hit", Vector2.ZERO, 1.0)
	for index in range(29):
		router.request("enemy_hit", Vector2(index * 8.0, 220.0), 1.0)
	_check(missing_events.size() <= before_throttle + 1, "rapid missing-asset requests are throttled")

	var old_sfx_volume: float = router.get_bus_volume("SFX")
	var old_sfx_mute: bool = router.is_bus_muted("SFX")
	router.set_bus_volume("SFX", 0.42)
	router.set_bus_muted("SFX", true)

	var reloaded_router: GloamAudioHooks = AUDIO_HOOKS.new() as GloamAudioHooks
	reloaded_router.settings_path = TEST_SETTINGS_PATH
	root.add_child(reloaded_router)
	await process_frame
	print("DEBUG loaded audio settings: %f / %s" % [reloaded_router.get_bus_volume("SFX"), reloaded_router.is_bus_muted("SFX")])
	_check(absf(reloaded_router.get_bus_volume("SFX") - 0.42) < 0.02, "SFX volume persists across router reload")
	_check(reloaded_router.is_bus_muted("SFX"), "SFX mute persists across router reload")
	reloaded_router.set_bus_volume("SFX", old_sfx_volume)
	reloaded_router.set_bus_muted("SFX", old_sfx_mute)
	reloaded_router.queue_free()
	router.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))

	var main: Node2D = MAIN_SCENE.instantiate() as Node2D
	root.add_child(main)
	current_scene = main
	await process_frame
	paused = false
	main._choose_starting_weapon("sword")
	await process_frame

	var settings_menu: GloamAudioSettingsMenu = main.get_node("UI/AudioSettingsMenu") as GloamAudioSettingsMenu
	_check(is_instance_valid(settings_menu.open_button), "settings button is created")
	_check(settings_menu.open_button.visible, "settings button is visible")
	_check(settings_menu.sliders.size() == BUS_NAMES.size(), "settings exposes one volume control per bus")
	_check(settings_menu.mute_buttons.size() == BUS_NAMES.size(), "settings exposes one mute toggle per bus")
	settings_menu._open_menu()
	_check(settings_menu.is_open() and paused, "settings menu pauses gameplay")
	settings_menu._close_menu()
	_check(not settings_menu.is_open() and not paused, "settings menu restores gameplay pause state")

	main.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	print("Audio verification: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		print("FAIL: %s" % description)
