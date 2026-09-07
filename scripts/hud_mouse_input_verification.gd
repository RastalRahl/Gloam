extends SceneTree

## Focused GUI-level verification for the HUD mouse contract.
##
## This deliberately feeds real mouse motion/button events through the input
## pipeline and checks the live Control hit-test state before clicking.
## It is separate from the logic-only regression suite because hit testing and
## modal stacking are scene/runtime behavior.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var failures: int = 0
var main: Node2D
var hit_best: Control
var hit_best_score := Vector3(-INF, -INF, -INF)
var hit_order: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	main = MAIN_SCENE.instantiate() as Node2D
	root.add_child(main)
	current_scene = main
	await process_frame

	# Complete the intentional starting modal through its existing game path so
	# the rest of the checks represent a normal live run.
	main._choose_starting_weapon("sword")
	paused = false
	main.player.global_position = Vector2(300.0, 1100.0)
	main._set_active_interaction_target(null)
	await _frames(3)

	_check(not main.modal_dimmer.visible, "normal run has no true modal dimmer")
	_audit_visible_ui_contract()
	await _check_no_fullscreen_hit_target("normal gameplay")

	var settings: GloamAudioSettingsMenu = main.get_node("UI/AudioSettingsMenu") as GloamAudioSettingsMenu
	var settings_button: Button = settings.open_button
	_check(settings_button.visible, "Settings is visible in a normal live run")
	await _click_control(settings_button, settings_button, "Settings opens from a real mouse click")
	_check(settings.is_open(), "Settings opened from the real mouse click")

	# The settings backdrop must intentionally own the full-screen hit area.
	var manage: Button = main.manage_village_button
	await _move_mouse_to(manage.get_global_rect().get_center())
	var settings_backdrop := settings.backdrop as Control
	_check(_hit_target(manage.get_global_rect().get_center()) == settings_backdrop, "open Settings backdrop is the topmost hit target")
	_log_target_if_unexpected(settings_backdrop, manage.get_global_rect().get_center(), "settings backdrop")
	var management_before: bool = main.village_management_open
	await _click_at(manage.get_global_rect().get_center(), settings_backdrop, "open Settings blocks Manage Village")
	_check(main.village_management_open == management_before, "open Settings prevents underlying Manage Village activation")
	_check(not settings.is_open(), "the intentional Settings backdrop click closes Settings")
	_check(not main.village_management_open, "closing Settings restores the live run without activating Manage Village")

	# Manage Village is tested in the safe village state, then closed again.
	await _frames(2)
	_check(manage.visible and not manage.disabled, "Manage Village is enabled safely inside the village")
	await _click_control(manage, manage, "Manage Village opens from a real mouse click")
	_check(main.village_management_open, "Manage Village opened from the real mouse click")
	_check(main.skip_to_night_button.disabled, "Skip to Night is disabled while management is open")
	_check(main.skip_to_night_button.tooltip_text.contains("village management"), "Skip tooltip names the management restriction")
	await _click_control(manage, manage, "Manage Village closes from a real mouse click")
	_check(not main.village_management_open, "Manage Village closes from the real mouse click")

	# Skip is valid in the village. One real click arms the existing confirmation.
	await _frames(2)
	var skip: Button = main.skip_to_night_button
	_check(skip.visible and not skip.disabled, "Skip to Night is enabled in its valid state")
	await _click_control(skip, skip, "Skip to Night receives a real mouse click")
	_check(skip.text == "CONFIRM NIGHT?", "Skip to Night click arms its existing confirmation")
	main._disarm_skip_confirmation()

	# Outside the village, the button remains visible but explains the actual
	# restriction instead of silently disappearing or accepting a click.
	main.player.global_position = Vector2(1200.0, 1000.0)
	await _frames(2)
	_check(skip.visible and skip.disabled, "Skip to Night is visibly disabled outside the village")
	_check(skip.tooltip_text.contains("Return inside the village"), "Skip tooltip explains the outside-village restriction")
	_check(manage.visible and manage.disabled, "Manage Village is visibly disabled outside the village")
	_check(manage.tooltip_text.contains("Return to the village"), "Manage Village tooltip explains the outside-village restriction")

	# Restore a safe position and open a true blocking modal. The underlying HUD
	# must not receive the click, and closing the modal must restore it immediately.
	main.player.global_position = Vector2(300.0, 1100.0)
	await _frames(2)
	main._open_level_up_panel(main.player.level)
	await _frames(2)
	var modal_dimmer: ColorRect = main.modal_dimmer
	_check(modal_dimmer.visible and modal_dimmer.mouse_filter == Control.MOUSE_FILTER_STOP, "true modal dimmer intentionally blocks input")
	await _move_mouse_to(settings_button.get_global_rect().get_center())
	_check(_hit_target(settings_button.get_global_rect().get_center()) == modal_dimmer, "true modal dimmer is topmost over the HUD")
	_log_target_if_unexpected(modal_dimmer, settings_button.get_global_rect().get_center(), "true modal")
	await _click_at(settings_button.get_global_rect().get_center(), modal_dimmer, "true modal blocks Settings")
	_check(not settings.is_open(), "true modal prevents Settings activation")

	var upgrade_button: Button = main.upgrade_button_1
	_check(upgrade_button.visible and not upgrade_button.disabled, "level-up modal exposes a live choice button")
	await _click_control(upgrade_button, upgrade_button, "closing modal uses a real choice click")
	await _frames(2)
	_check(not main.modal_dimmer.visible and not main.level_up_panel.visible, "closing modal removes the blocker immediately")
	await _click_control(settings_button, settings_button, "HUD Settings is restored immediately after modal close")
	_check(settings.is_open(), "Settings is clickable immediately after modal close")
	await _click_at(main.manage_village_button.get_global_rect().get_center(), settings.backdrop, "Settings closes after modal restoration")

	_audit_visible_ui_contract()
	await _check_no_fullscreen_hit_target("restored normal gameplay")

	main.queue_free()
	await process_frame
	print("HUD mouse-input verification: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _click_control(control: Control, expected: Control, description: String) -> void:
	await _click_at(control.get_global_rect().get_center(), expected, description)


func _click_at(position: Vector2, expected: Control, description: String) -> void:
	await _move_mouse_to(position)
	var target := _hit_target(position)
	_check(target == expected, description + " hit-tests the intended Control")
	_log_target_if_unexpected(expected, position, description)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	press.global_position = position
	main.get_viewport().push_input(press, true)
	await process_frame
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	main.get_viewport().push_input(release, true)
	await process_frame


func _move_mouse_to(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	main.get_viewport().push_input(motion, true)
	await process_frame


func _check_no_fullscreen_hit_target(context: String) -> void:
	var viewport_size: Vector2 = main.get_viewport().get_visible_rect().size
	await _move_mouse_to(viewport_size * 0.5)
	var target := _hit_target(viewport_size * 0.5)
	_check(target == null, "%s has no passive/full-screen hit target" % context)
	if target != null:
		_log_target_if_unexpected(null, viewport_size * 0.5, context)


func _audit_visible_ui_contract() -> void:
	var violations: Array[String] = []
	_audit_node(main.get_node("UI"), violations)
	_check(violations.is_empty(), "every visible passive UI Control follows the mouse contract")
	for violation: String in violations:
		print("UI CONTRACT VIOLATION: %s" % violation)


func _audit_node(node: Node, violations: Array[String]) -> void:
	for child: Node in node.get_children():
		if child is Control:
			var control := child as Control
			if control.is_visible_in_tree() and not _is_intentional_input_control(control) and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				violations.append("%s visible=%s mouse_filter=%d z=%d" % [_path(control), control.visible, control.mouse_filter, control.z_index])
		_audit_node(child, violations)


func _is_intentional_input_control(control: Control) -> bool:
	if control is BaseButton or control is HSlider or control is VSlider:
		return true
	var path := _path(control)
	for allowed: String in [
		"ModalDimmer", "WeaponPanel", "LevelUpPanel", "GameOverPanel", "VictoryPanel",
		"ContextualInteractionMenu/InteractionPrompt", "ContextualInteractionMenu/InteractionChoices",
		"PauseMenu/PauseBackdrop", "PauseMenu/PausePanel", "PauseMenu/PauseConfirmation",
		"AudioSettingsMenu/AudioSettingsBackdrop", "AudioSettingsMenu/AudioSettingsPanel"
	]:
		if path.ends_with("UI/" + allowed):
			return true
	return false


func _log_target_if_unexpected(expected: Control, position: Vector2, context: String) -> void:
	var actual := _hit_target(position)
	if actual == expected:
		return
	print("HUD INPUT BLOCKED: %s at %s expected=%s actual=%s" % [context, position, _describe(expected), _describe(actual)])
	if actual != null:
		print("  actual path=%s visible=%s mouse_filter=%d z=%d parent_chain=%s" % [
			_path(actual), actual.visible, actual.mouse_filter, actual.z_index, _parent_chain(actual)
		])


func _describe(control: Control) -> String:
	return "<none>" if control == null else _path(control)


func _path(node: Node) -> String:
	var parts: Array[String] = []
	var current: Node = node
	while is_instance_valid(current) and current != main.get_parent():
		parts.push_front(str(current.name))
		if current == main:
			break
		current = current.get_parent()
	return "/".join(parts)


func _parent_chain(node: Node) -> String:
	var parts: Array[String] = []
	var current: Node = node
	while is_instance_valid(current):
		parts.append("%s(visible=%s filter=%s z=%s)" % [current.name, str(current is Control and (current as Control).visible), str(current.get("mouse_filter") if current is Control else "n/a"), str(current.get("z_index") if current is CanvasItem else "n/a")])
		if current == main:
			break
		current = current.get_parent()
	return " <- ".join(parts)


func _hit_target(position: Vector2) -> Control:
	# Headless Godot does not update gui_get_hovered_control from pushed motion
	# events on every renderer. This mirrors Control hit testing using the live
	# scene's visibility, filter, global rect, depth band, and parent chain; the
	# click itself is still delivered through Viewport.push_input below.
	hit_best = null
	hit_best_score = Vector3(-INF, -INF, -INF)
	hit_order = 0
	_visit_for_hit(main, position, 0, 0)
	return hit_best


func _visit_for_hit(node: Node, position: Vector2, depth: int, z_total: int) -> void:
	for child: Node in node.get_children():
		hit_order += 1
		var child_z: int = z_total
		if child is Control:
			var control := child as Control
			child_z = z_total + control.z_index
			if control.is_visible_in_tree() and control.mouse_filter != Control.MOUSE_FILTER_IGNORE and control.get_global_rect().has_point(position):
				var score := Vector3(float(child_z), float(depth), float(hit_order))
				if score > hit_best_score:
					hit_best_score = score
					hit_best = control
		_visit_for_hit(child, position, depth + 1, child_z if child is CanvasItem else z_total)


func _frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		print("FAIL: %s" % description)
