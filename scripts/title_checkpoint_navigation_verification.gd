extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const RUN_CHECKPOINT := preload("res://scripts/run_checkpoint.gd")
const TEST_PATH := "res://.godot/title_checkpoint_navigation.json"

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate() as Node2D
	root.add_child(main)
	current_scene = main
	await process_frame
	var title: GloamTitleMenu = main.title_menu
	_check(title.menu_open and title.visible, "title shell owns startup")
	_check(title.continue_button.disabled, "Continue is disabled without a valid dawn checkpoint")

	main._choose_starting_weapon("sword")
	await process_frame
	main.run_checkpoint = RUN_CHECKPOINT.new(TEST_PATH)
	main.checkpoint_enabled = true
	_check(main.run_checkpoint.save_dawn(main._capture_dawn_checkpoint()), "fixture dawn checkpoint is saved")
	title.open_menu(main._has_valid_dawn_checkpoint())
	_check(not title.continue_button.disabled, "Continue is enabled only after dawn payload validation")

	_send(title, &"menu_down")
	_check(root.get_viewport().gui_get_focus_owner() == title.continue_button, "keyboard navigation reaches Continue")
	_send(title, &"menu_up")
	_check(root.get_viewport().gui_get_focus_owner() == title.new_run_button, "keyboard navigation returns to New Run")
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_DPAD_DOWN
	joy.pressed = true
	title._unhandled_input(joy)
	_check(root.get_viewport().gui_get_focus_owner() == title.continue_button, "controller navigation reaches Continue")

	title.new_run_button.emit_signal("pressed")
	_check(title.confirmation_panel.visible, "New Run confirms before replacing a checkpoint")
	_check(not main.run_checkpoint.load_latest_dawn().is_empty(), "confirmation leaves the checkpoint intact")
	title.cancel_button.emit_signal("pressed")
	_check(title.panel.visible and not title.confirmation_panel.visible, "checkpoint replacement can be cancelled")

	title.credits_button.emit_signal("pressed")
	var credit_labels := title.credits_panel.find_children("", "Label", true, false)
	var credits_text := (credit_labels[0] as Label).text if not credit_labels.is_empty() else ""
	_check(title.credits_panel.visible and "ATTRIBUTION" in credits_text, "Credits expose the attribution record")
	title.credits_close_button.emit_signal("pressed")
	_check(title.panel.visible, "Credits return to the title navigation")
	paused = false
	title.continue_button.emit_signal("pressed")
	await process_frame
	_check(main.run_started and main.current_phase == main.Phase.DAY and not title.menu_open, "Continue restores the validated dawn checkpoint")

	main.run_checkpoint.clear_run()
	main.queue_free()
	await process_frame
	print("Title checkpoint navigation verification: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _send(target: Node, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	target._unhandled_input(event)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		print("FAIL: %s" % description)
