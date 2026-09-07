extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const INPUT_ACTIONS := preload("res://scripts/input_actions.gd")

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var required_actions: Array[StringName] = [
		INPUT_ACTIONS.MOVE_UP,
		INPUT_ACTIONS.MOVE_DOWN,
		INPUT_ACTIONS.MOVE_LEFT,
		INPUT_ACTIONS.MOVE_RIGHT,
		INPUT_ACTIONS.AIM_UP,
		INPUT_ACTIONS.AIM_DOWN,
		INPUT_ACTIONS.AIM_LEFT,
		INPUT_ACTIONS.AIM_RIGHT,
		INPUT_ACTIONS.ATTACK,
		INPUT_ACTIONS.INTERACT,
		INPUT_ACTIONS.REPAIR,
		INPUT_ACTIONS.UPGRADE,
		INPUT_ACTIONS.LEVEL_UP,
		INPUT_ACTIONS.VILLAGE_MANAGEMENT,
		INPUT_ACTIONS.MENU_UP,
		INPUT_ACTIONS.MENU_DOWN,
		INPUT_ACTIONS.MENU_LEFT,
		INPUT_ACTIONS.MENU_RIGHT,
		INPUT_ACTIONS.MENU_ACCEPT,
		INPUT_ACTIONS.MENU_CANCEL
	]
	for action_name: StringName in required_actions:
		_check(InputMap.has_action(action_name), "named action exists: %s" % action_name)
		_check(not InputMap.action_get_events(action_name).is_empty(), "named action has a binding: %s" % action_name)

	_check(_has_event_type(INPUT_ACTIONS.MOVE_RIGHT, InputEventJoypadMotion), "movement has analog controller input")
	_check(_has_event_type(INPUT_ACTIONS.AIM_RIGHT, InputEventJoypadMotion), "aiming has right-stick input")
	_check(_has_event_type(INPUT_ACTIONS.ATTACK, InputEventMouseButton), "attack retains mouse input")
	_check(_has_event_type(INPUT_ACTIONS.ATTACK, InputEventJoypadButton), "attack has controller input")
	_check(_has_event_type(INPUT_ACTIONS.INTERACT, InputEventKey), "interact has keyboard input")
	_check(_has_event_type(INPUT_ACTIONS.INTERACT, InputEventJoypadButton), "interact has controller input")

	var main: Node2D = MAIN_SCENE.instantiate() as Node2D
	root.add_child(main)
	current_scene = main
	await process_frame
	paused = false
	main._choose_starting_weapon("sword")
	await process_frame

	var spot: GloamBuildSpot = main.get_node("World/Regions/Village/DefenseBuildSpots").get_child(0) as GloamBuildSpot
	spot.player_inside = true
	main.player.global_position = spot.global_position
	main.wood = 100
	main.stone = 100
	main.iron = 100
	main._set_active_interaction_target(spot)
	var controller_attack_event := InputEventJoypadButton.new()
	controller_attack_event.button_index = JOY_BUTTON_RIGHT_SHOULDER
	controller_attack_event.pressed = true
	main.player._input(controller_attack_event)
	_check(main.player.preferred_aim_device == "controller", "controller attack selects controller aim")
	Input.action_press(INPUT_ACTIONS.AIM_RIGHT, 1.0)
	main.player._input(InputEventJoypadMotion.new())
	_check(main.player._get_aim_direction().x > 0.90, "right-stick action provides a usable aim direction")
	Input.action_release(INPUT_ACTIONS.AIM_RIGHT)

	var controller_event := InputEventJoypadButton.new()
	controller_event.button_index = JOY_BUTTON_A
	controller_event.pressed = true
	main._input(controller_event)
	_check(main.contextual_interaction_menu.prompt_button.text.contains("A"), "interaction prompt follows controller input")

	var keyboard_event := InputEventKey.new()
	keyboard_event.physical_keycode = 4194309
	keyboard_event.pressed = true
	main._input(keyboard_event)
	_check(main.contextual_interaction_menu.prompt_button.text.contains("Enter"), "interaction prompt follows keyboard input")

	main._open_contextual_interaction()
	var first_focus: Control = main.get_viewport().gui_get_focus_owner() as Control
	var menu_down := InputEventAction.new()
	menu_down.action = "menu_down"
	menu_down.pressed = true
	main.contextual_interaction_menu._unhandled_input(menu_down)
	await process_frame
	var second_focus: Control = main.get_viewport().gui_get_focus_owner() as Control
	_check(first_focus != second_focus, "named menu navigation moves focus")

	var menu_accept := InputEventAction.new()
	menu_accept.action = "menu_accept"
	menu_accept.pressed = true
	main.contextual_interaction_menu._unhandled_input(menu_accept)
	await process_frame
	_check(not main.interaction_menu_open and not paused, "named menu accept selects and unpauses")
	_check(main.get_node("Defenses").get_child_count() == 1, "controller menu accept executes one contextual choice")

	var held_enter_spot: GloamBuildSpot = main.get_node("World/Regions/Village/DefenseBuildSpots").get_child(1) as GloamBuildSpot
	main.player.global_position = held_enter_spot.global_position
	main._set_active_interaction_target(held_enter_spot)
	main._open_contextual_interaction()
	var enter_press := InputEventKey.new()
	enter_press.physical_keycode = 4194309
	enter_press.pressed = true
	main._unhandled_input(enter_press)
	var enter_echo := InputEventKey.new()
	enter_echo.physical_keycode = 4194309
	enter_echo.pressed = true
	enter_echo.echo = true
	main._unhandled_input(enter_echo)
	main.contextual_interaction_menu._unhandled_input(enter_echo)
	_check(main.interaction_menu_open, "held Enter cannot activate a choice while opening the menu")
	var enter_release := InputEventKey.new()
	enter_release.physical_keycode = 4194309
	enter_release.pressed = false
	main.contextual_interaction_menu._input(enter_release)
	main.contextual_interaction_menu.close_menu()

	main.player.global_position = Vector2(300, 1100)
	main._set_active_interaction_target(null)
	var management_press := InputEventAction.new()
	management_press.action = "village_management"
	management_press.pressed = true
	main._unhandled_input(management_press)
	var management_state: bool = main.village_management_open
	main._unhandled_input(management_press)
	_check(main.village_management_open == management_state, "held management input does not toggle twice")
	var management_release := InputEventAction.new()
	management_release.action = "village_management"
	management_release.pressed = false
	main._unhandled_input(management_release)

	main.queue_free()
	await process_frame
	var reloaded_main: Node2D = MAIN_SCENE.instantiate() as Node2D
	root.add_child(reloaded_main)
	current_scene = reloaded_main
	await process_frame
	_check(
		is_instance_valid(reloaded_main.contextual_interaction_menu)
		and not reloaded_main.contextual_interaction_menu.is_menu_open(),
		"input UI reloads without stale menu state"
	)
	reloaded_main.queue_free()
	await process_frame
	print("Input actions verification: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _has_event_type(action_name: StringName, event_type: Variant) -> bool:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if is_instance_of(event, event_type):
			return true
	return false


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		print("FAIL: %s" % description)
