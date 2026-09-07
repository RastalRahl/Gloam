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
	if not _renderer_can_capture_viewport():
		print("UI spacing capture: SKIP (active renderer cannot capture viewport images: %s)" % _renderer_description())
		quit(0)
		return

	var main: Node2D = MAIN_SCENE.instantiate() as Node2D
	main.day_duration = 999.0
	main.night_duration = 30.0
	main.final_boss_spawn_delay = 999.0
	root.add_child(main)
	current_scene = main
	await _frames(4)

	await _capture_at_size(main, Vector2i(1260, 710), "title_1260x710")
	await _capture_at_size(main, Vector2i(1280, 720), "title_1280x720")
	await _capture_at_size(main, Vector2i(1920, 1080), "title_1920x1080")

	main.start_new_run_from_title()
	await _frames(2)
	await _capture_at_size(main, Vector2i(1280, 720), "weapon_1280x720")

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
	await _capture_at_size(main, Vector2i(1260, 710), "settings_1260x710")
	await _capture_at_size(main, Vector2i(1280, 720), "settings_1280x720")
	await _capture_at_size(main, Vector2i(1920, 1080), "settings_1920x1080")
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
	await RenderingServer.frame_post_draw

	var viewport_texture: Texture2D = root.get_texture() as Texture2D
	if not is_instance_valid(viewport_texture):
		_check(false, "%s has no valid viewport texture" % label)
		return

	var image: Image = viewport_texture.get_image()
	if not is_instance_valid(image) or image.is_empty():
		_check(false, "%s produced no viewport image" % label)
		return
	if image.get_size() != size:
		_check(false, "%s is %s" % [label, str(size)])
		return
	_check(_save_verified_image(image, OUTPUT_ROOT + label + ".png"), "%s saved" % label)


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		print("FAIL: %s" % description)


func _renderer_can_capture_viewport() -> bool:
	var display_name := DisplayServer.get_name().to_lower()
	var adapter_name := RenderingServer.get_video_adapter_name().to_lower()
	return (
		not display_name.contains("headless")
		and not display_name.contains("dummy")
		and not adapter_name.contains("dummy")
	)


func _renderer_description() -> String:
	return "display=%s adapter=%s" % [DisplayServer.get_name(), RenderingServer.get_video_adapter_name()]


func _save_verified_image(image: Image, target_path: String) -> bool:
	var token := str(Time.get_ticks_usec())
	var temporary_path := "%s.capture_tmp_%s.png" % [target_path, token]
	var backup_path := "%s.capture_backup_%s.png" % [target_path, token]
	var temporary_absolute := ProjectSettings.globalize_path(temporary_path)
	var target_absolute := ProjectSettings.globalize_path(target_path)
	var backup_absolute := ProjectSettings.globalize_path(backup_path)

	var save_result: Error = image.save_png(temporary_path)
	if save_result != OK:
		_remove_absolute(temporary_absolute)
		return false

	var verification_image := Image.new()
	var load_result: Error = verification_image.load(temporary_path)
	if load_result != OK or verification_image.is_empty() or verification_image.get_size() != image.get_size():
		_remove_absolute(temporary_absolute)
		return false

	var had_existing_target := FileAccess.file_exists(target_absolute)
	if had_existing_target and DirAccess.rename_absolute(target_absolute, backup_absolute) != OK:
		_remove_absolute(temporary_absolute)
		return false

	var commit_result: Error = DirAccess.rename_absolute(temporary_absolute, target_absolute)
	if commit_result != OK:
		if had_existing_target:
			DirAccess.rename_absolute(backup_absolute, target_absolute)
		_remove_absolute(temporary_absolute)
		return false

	if had_existing_target:
		_remove_absolute(backup_absolute)
	return true


func _remove_absolute(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
