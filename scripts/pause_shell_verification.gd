extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const INPUT_ACTIONS := preload("res://scripts/input_actions.gd")
const TEST_SETTINGS_PATH: String = "res://.godot/gloam_pause_shell_verification.cfg"

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node2D = MAIN_SCENE.instantiate() as Node2D
	root.add_child(main)
	current_scene = main
	await process_frame

	var pause_menu: GloamPauseMenu = main.pause_menu
	var settings_menu: GloamAudioSettingsMenu = main.get_node("UI/AudioSettingsMenu") as GloamAudioSettingsMenu
	var game_settings: GloamGameSettings = main.game_settings
	_check(InputMap.has_action("pause"), "pause action exists")
	_check(not pause_menu.can_open() and paused, "pause is blocked by the starting weapon modal")

	main._choose_starting_weapon("sword")
	await process_frame
	paused = false
	var phase_before: int = main.current_phase
	var phase_time_before: float = main.phase_timer.time_left
	_send_key(pause_menu, KEY_ESCAPE)
	_check(pause_menu.is_open() and paused, "pause menu opens in a live run")
	await create_timer(0.18).timeout
	_check(main.current_phase == phase_before, "paused run does not advance phase")
	_check(is_equal_approx(main.phase_timer.time_left, phase_time_before), "day timer freezes while paused")

	_send_action(pause_menu, INPUT_ACTIONS.MENU_DOWN)
	_check(main.get_viewport().gui_get_focus_owner() == pause_menu.settings_button, "pause menu navigates with named menu input")
	_send_action(pause_menu, INPUT_ACTIONS.MENU_ACCEPT)
	_check(settings_menu.is_open() and paused and pause_menu.is_open(), "Settings opens without losing pause ownership")
	_check(settings_menu.sliders.size() == 4, "Settings exposes Master, Music, SFX, and UI volume")
	_check(is_instance_valid(settings_menu.fullscreen_button), "Settings exposes fullscreen/windowed mode")
	_check(is_instance_valid(settings_menu.reduce_shake_button), "Settings exposes screen-shake reduction")
	_check(is_instance_valid(settings_menu.high_contrast_button), "Settings exposes high-contrast mode")
	_check(settings_menu.remap_buttons.size() >= 7, "Settings exposes basic input remapping")
	var settings_focus_before: Control = main.get_viewport().gui_get_focus_owner() as Control
	_send_action(settings_menu, INPUT_ACTIONS.MENU_DOWN)
	_check(main.get_viewport().gui_get_focus_owner() != settings_focus_before, "Settings navigates without a mouse")

	game_settings.settings_path = TEST_SETTINGS_PATH
	game_settings.set_fullscreen(true)
	game_settings.set_reduce_screen_shake(true)
	game_settings.set_high_contrast(true)
	settings_menu._start_remap(INPUT_ACTIONS.ATTACK)
	var remap_event := InputEventKey.new()
	remap_event.physical_keycode = KEY_Q
	remap_event.keycode = KEY_Q
	remap_event.pressed = true
	settings_menu._input(remap_event)
	_check(game_settings.action_binding_text(INPUT_ACTIONS.ATTACK) == "Q", "input remapping changes the named action")
	Input.parse_input_event(remap_event)
	await process_frame
	_check(Input.is_action_pressed(INPUT_ACTIONS.ATTACK), "remapped key drives the named action")
	var remap_release := remap_event.duplicate() as InputEventKey
	remap_release.pressed = false
	Input.parse_input_event(remap_release)

	var reloaded_settings: GloamGameSettings = GAME_SETTINGS.new() as GloamGameSettings
	reloaded_settings.settings_path = TEST_SETTINGS_PATH
	root.add_child(reloaded_settings)
	await process_frame
	_check(reloaded_settings.fullscreen and reloaded_settings.reduce_screen_shake and reloaded_settings.high_contrast, "display and accessibility settings persist")
	_check(reloaded_settings.action_binding_text(INPUT_ACTIONS.ATTACK) == "Q", "input remapping persists")
	reloaded_settings.queue_free()
	game_settings.set_fullscreen(false)

	settings_menu.close_menu()
	_check(settings_menu.is_open() == false and pause_menu.is_open() and paused, "closing Settings returns to the pause menu")
	_send_action(pause_menu, INPUT_ACTIONS.MENU_CANCEL)
	_check(not pause_menu.is_open() and not paused, "Resume restores the unpaused run")

	_send_joy(pause_menu, JOY_BUTTON_START)
	_send_joy(pause_menu, JOY_BUTTON_DPAD_DOWN)
	_check(main.get_viewport().gui_get_focus_owner() == pause_menu.settings_button, "controller navigates the pause menu")
	_send_joy(pause_menu, JOY_BUTTON_A)
	_check(settings_menu.is_open() and paused, "controller opens Settings")
	settings_menu.close_menu()
	pause_menu.close_menu()

	_send_action(pause_menu, INPUT_ACTIONS.PAUSE)
	_send_action(pause_menu, INPUT_ACTIONS.MENU_DOWN)
	_send_action(pause_menu, INPUT_ACTIONS.MENU_DOWN)
	_send_action(pause_menu, INPUT_ACTIONS.MENU_ACCEPT)
	_check(pause_menu.confirmation_action == "restart", "Restart Run requires confirmation")
	_send_action(pause_menu, INPUT_ACTIONS.MENU_CANCEL)
	_check(pause_menu.is_open() and pause_menu.confirmation_action.is_empty(), "restart confirmation cancels safely")
	_send_action(pause_menu, INPUT_ACTIONS.MENU_DOWN)
	_send_action(pause_menu, INPUT_ACTIONS.MENU_ACCEPT)
	_check(pause_menu.confirmation_action == "quit", "Quit to Desktop requires confirmation")
	_send_action(pause_menu, INPUT_ACTIONS.MENU_CANCEL)

	# Confirm that pause is unavailable while another gameplay modal owns the pause.
	main.level_up_panel.show()
	_check(not pause_menu.can_open() and not main.can_open_settings(), "pause and Settings do not stack over the upgrade modal")
	main.level_up_panel.hide()
	main.victory_panel.show()
	_check(not pause_menu.can_open() and not main.can_open_settings(), "pause and Settings do not stack over the victory modal")
	main.victory_panel.hide()
	pause_menu.close_menu()

	# Night wave pacing uses gameplay time and therefore freezes under pause.
	main._start_night()
	await process_frame
	_send_action(pause_menu, INPUT_ACTIONS.PAUSE)
	_check(pause_menu.is_open() and paused, "pause menu opens during a night")
	await create_timer(0.18).timeout
	_check(main.wave_waiting and not main.wave_active, "incoming wave telegraph freezes while paused")
	_check(main.wave_index == 0, "paused night does not advance its wave index")
	_send_action(pause_menu, INPUT_ACTIONS.PAUSE)

	main._on_village_core_destroyed()
	await process_frame
	_check(main.game_over and not pause_menu.can_open(), "game over prevents opening the pause menu")
	_check(not main.can_open_settings(), "game-over modal blocks Settings stacking")

	_restore_keyboard_binding(INPUT_ACTIONS.ATTACK, KEY_SPACE)
	main.queue_free()
	await process_frame
	# Let the audio mixer release any UI voice playback before the test exits.
	await create_timer(0.25, true).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
	print("Pause shell verification: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _send_action(target: Node, action_name: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	target._unhandled_input(event)


func _send_key(target: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = true
	target._unhandled_input(event)


func _send_joy(target: Node, button_index: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = true
	target._unhandled_input(event)


func _restore_keyboard_binding(action_name: StringName, physical_keycode: Key) -> void:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			InputMap.action_erase_event(action_name, event)
	var keyboard_event := InputEventKey.new()
	keyboard_event.physical_keycode = physical_keycode
	keyboard_event.keycode = physical_keycode
	InputMap.action_add_event(action_name, keyboard_event)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		print("FAIL: %s" % description)
