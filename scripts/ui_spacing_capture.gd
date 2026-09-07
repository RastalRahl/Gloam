extends SceneTree

## Focused rendered evidence for the HUD spacing pass.
## This script only instantiates the live scene, poses existing UI states, and
## saves screenshots; it does not change game rules or authored world content.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const OUTPUT_ROOT := "res://visual_comparison/ui_spacing_"

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node2D = MAIN_SCENE.instantiate() as Node2D
	main.day_duration = 999.0
	main.night_duration = 30.0
	main.final_boss_spawn_delay = 999.0
	root.add_child(main)
	current_scene = main
	await _frames(4)

	await _capture_at_size(main, Vector2i(1260, 710), "weapon_1260x710")
	await _capture_at_size(main, Vector2i(1280, 720), "weapon_1280x720")
	await _capture_at_size(main, Vector2i(1920, 1080), "weapon_1920x1080")

	main._choose_starting_weapon("sword")
	await _frames(3)
	await _capture_at_size(main, Vector2i(1260, 710), "day_1260x710")
	await _capture_at_size(main, Vector2i(1280, 720), "day_1280x720")
	await _capture_at_size(main, Vector2i(1920, 1080), "day_1920x1080")

	main.player.global_position = Vector2(320.0, 1190.0)
	main._toggle_village_management()
	await _frames(2)
	await _capture_at_size(main, Vector2i(1280, 720), "village_management_1280x720")

	main._toggle_village_management()
	main.build_prompt.text = "BUILD SPOT  •  HOUSE  •  COST 10 WOOD / 5 STONE"
	main.build_panel.show()
	await _frames(2)
	await _capture_at_size(main, Vector2i(1280, 720), "build_prompt_1280x720")
	main.build_panel.hide()

	main.pause_menu.open_menu()
	await _frames(2)
	var settings_menu: GloamAudioSettingsMenu = main.get_node("UI/AudioSettingsMenu") as GloamAudioSettingsMenu
	settings_menu.open_menu(main.pause_menu.settings_button)
	await _frames(2)
	await _capture_at_size(main, Vector2i(1280, 720), "settings_1280x720")
	settings_menu.close_menu()
	main.pause_menu.close_menu()

	main._open_level_up_panel(2)
	await _frames(2)
	await _capture_at_size(main, Vector2i(1280, 720), "level_up_1280x720")
	main.level_up_panel.hide()
	main._hide_modal_dimmer()
	paused = false

	main._start_night()
	await _frames(2)
	await _capture_at_size(main, Vector2i(1280, 720), "night_1280x720")

	main.downed_label.text = "DOWNED\nRespawning in 3.0 seconds\nNight down 1  •  5s penalty"
	main.downed_label.show()
	await _frames(2)
	await _capture_at_size(main, Vector2i(1280, 720), "downed_1280x720")
	main.downed_label.hide()

	main.current_phase = main.Phase.VICTORY
	main.victory_panel.show()
	main._show_modal_dimmer()
	paused = true
	await _capture_at_size(main, Vector2i(1280, 720), "victory_1280x720")
	main.victory_panel.hide()
	main._hide_modal_dimmer()
	paused = false
	main.current_phase = main.Phase.DAY

	main._on_village_core_destroyed()
	await _frames(2)
	await _capture_at_size(main, Vector2i(1280, 720), "game_over_1280x720")

	main.queue_free()
	await process_frame
	print("UI spacing capture: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _capture_at_size(main: Node2D, size: Vector2i, label: String) -> void:
	DisplayServer.window_set_size(size)
	await _frames(4)
	var image: Image = root.get_texture().get_image()
	_check(image.get_size() == size, "%s is %s" % [label, str(size)])
	var result := image.save_png(OUTPUT_ROOT + label + ".png")
	_check(result == OK, "%s saved" % label)


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)
