extends Control
class_name GloamPauseMenu

const UI_STYLE := preload("res://scripts/ui_style.gd")
const INPUT_ACTIONS := preload("res://scripts/input_actions.gd")
const TINY_UI_FRAME_SCENE := preload("res://scenes/components/tiny_ui_frame.tscn")
const UI_FOCUS := preload("res://scripts/ui_focus.gd")

var game_controller: Node = null
var settings_menu: GloamAudioSettingsMenu = null
var backdrop: ColorRect
var panel: PanelContainer
var title_label: Label
var hint_label: Label
var resume_button: Button
var settings_button: Button
var restart_button: Button
var quit_button: Button
var confirm_panel: PanelContainer
var confirm_label: Label
var confirm_yes_button: Button
var confirm_no_button: Button
var menu_open: bool = false
var confirmation_action: String = ""
var pause_was_active: bool = false


func configure(controller: Node, audio_settings: GloamAudioSettingsMenu) -> void:
	game_controller = controller
	settings_menu = audio_settings


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 40
	_build_ui()
	_apply_style()
	hide()


func _build_ui() -> void:
	backdrop = ColorRect.new()
	backdrop.name = "PauseBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.008, 0.012, 0.018, 0.78)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	panel = PanelContainer.new()
	panel.name = "PausePanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-230.0, -210.0)
	panel.size = Vector2(460.0, 420.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var panel_content := MarginContainer.new()
	panel_content.name = "Content"
	panel_content.add_theme_constant_override("margin_left", 22)
	panel_content.add_theme_constant_override("margin_top", 22)
	panel_content.add_theme_constant_override("margin_right", 22)
	panel_content.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(panel_content)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 10)
	panel_content.add_child(vbox)

	title_label = Label.new()
	title_label.text = "PAUSED"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title_label)

	hint_label = Label.new()
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hint_label)

	resume_button = _make_button("Resume")
	resume_button.pressed.connect(close_menu)
	vbox.add_child(resume_button)
	settings_button = _make_button("Settings")
	settings_button.pressed.connect(_open_settings)
	vbox.add_child(settings_button)
	restart_button = _make_button("Restart Run")
	restart_button.pressed.connect(func(): _ask_confirmation("restart"))
	vbox.add_child(restart_button)
	quit_button = _make_button("Quit to Desktop")
	quit_button.pressed.connect(func(): _ask_confirmation("quit"))
	vbox.add_child(quit_button)

	confirm_panel = PanelContainer.new()
	confirm_panel.name = "PauseConfirmation"
	confirm_panel.set_anchors_preset(Control.PRESET_CENTER)
	confirm_panel.position = Vector2(-260.0, -135.0)
	confirm_panel.size = Vector2(520.0, 270.0)
	confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(confirm_panel)
	var confirm_content := MarginContainer.new()
	confirm_content.name = "Content"
	confirm_content.add_theme_constant_override("margin_left", 22)
	confirm_content.add_theme_constant_override("margin_top", 22)
	confirm_content.add_theme_constant_override("margin_right", 22)
	confirm_content.add_theme_constant_override("margin_bottom", 22)
	confirm_panel.add_child(confirm_content)
	var confirm_vbox := VBoxContainer.new()
	confirm_vbox.add_theme_constant_override("separation", 12)
	confirm_content.add_child(confirm_vbox)
	confirm_label = Label.new()
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_vbox.add_child(confirm_label)
	confirm_yes_button = _make_button("Confirm")
	confirm_yes_button.pressed.connect(_confirm_action)
	confirm_vbox.add_child(confirm_yes_button)
	confirm_no_button = _make_button("Cancel")
	confirm_no_button.pressed.connect(_cancel_confirmation)
	confirm_vbox.add_child(confirm_no_button)
	confirm_panel.hide()


func _make_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_ALL
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	button.custom_minimum_size = Vector2(0.0, 52.0)
	return button


func _apply_style() -> void:
	var theme_resource: Theme = UI_STYLE.create_theme()
	theme = theme_resource
	panel.add_theme_stylebox_override("panel", UI_STYLE.make_modal_panel_style())
	confirm_panel.add_theme_stylebox_override("panel", UI_STYLE.make_modal_panel_style())
	for button: Button in [resume_button, settings_button, restart_button, quit_button, confirm_yes_button, confirm_no_button]:
		button.add_theme_stylebox_override("normal", UI_STYLE.make_asset_button_style())
		button.add_theme_stylebox_override("hover", UI_STYLE.make_asset_button_style())
		button.add_theme_stylebox_override("pressed", UI_STYLE.make_asset_button_style())
		_add_tiny_ui_frame(button)
	_add_tiny_ui_frame(panel)
	_add_tiny_ui_frame(confirm_panel)


func can_open() -> bool:
	if not is_instance_valid(game_controller) or not game_controller.has_method("can_open_pause_menu"):
		return false
	return bool(game_controller.call("can_open_pause_menu"))


func open_menu() -> void:
	if menu_open or not can_open():
		return
	menu_open = true
	confirmation_action = ""
	pause_was_active = get_tree().paused
	_refresh_hint()
	show()
	backdrop.show()
	panel.show()
	confirm_panel.hide()
	_sync_mouse_filters()
	get_tree().paused = true
	_refresh_host_hud_controls()
	UI_FOCUS.request(resume_button, menu_open and panel.visible)
	if is_instance_valid(game_controller) and game_controller.has_method("play_audio_hook"):
		game_controller.call("play_audio_hook", "ui_open", Vector2.ZERO, 0.70)


func close_menu() -> void:
	if not menu_open:
		return
	if not confirmation_action.is_empty():
		_cancel_confirmation()
		return
	menu_open = false
	hide()
	backdrop.hide()
	panel.hide()
	confirm_panel.hide()
	_sync_mouse_filters()
	get_tree().paused = pause_was_active
	_refresh_host_hud_controls()
	if is_instance_valid(game_controller) and game_controller.has_method("play_audio_hook"):
		game_controller.call("play_audio_hook", "ui_cancel", Vector2.ZERO, 0.60)


func is_open() -> bool:
	return menu_open


func _sync_mouse_filters() -> void:
	# Pause's full-screen shell is passive; its backdrop and the active panel are
	# the only intentional blockers while the menu is open.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP if backdrop.visible else Control.MOUSE_FILTER_IGNORE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP if panel.visible else Control.MOUSE_FILTER_IGNORE
	confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP if confirm_panel.visible else Control.MOUSE_FILTER_IGNORE
	_set_interactive_filters(self, menu_open)


func _refresh_host_hud_controls() -> void:
	if is_instance_valid(game_controller) and game_controller.has_method("_refresh_skip_to_night_control"):
		game_controller.call("_refresh_skip_to_night_control")
	if is_instance_valid(game_controller) and game_controller.has_method("_refresh_manage_village_control"):
		game_controller.call("_refresh_manage_village_control")


func _set_interactive_filters(node: Node, enabled: bool) -> void:
	for child: Node in node.get_children():
		if child is BaseButton or child is HSlider or child is VSlider:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_STOP if enabled and (child as Control).visible else Control.MOUSE_FILTER_IGNORE
		_set_interactive_filters(child, enabled)


func _open_settings() -> void:
	if not menu_open or not is_instance_valid(settings_menu):
		return
	settings_menu.open_menu(settings_button)


func _ask_confirmation(action: String) -> void:
	if not menu_open or action not in ["restart", "quit"]:
		return
	confirmation_action = action
	panel.hide()
	confirm_panel.show()
	confirm_panel.z_index = 1
	_sync_mouse_filters()
	confirm_label.text = (
		"Restart this run? All progress will be lost."
		if action == "restart"
		else "Quit to desktop? Your active run will be lost."
	)
	confirm_yes_button.text = "CONFIRM %s" % action.to_upper()
	confirm_no_button.text = "CANCEL  [%s]" % INPUT_ACTIONS.action_hint(INPUT_ACTIONS.MENU_CANCEL)
	UI_FOCUS.request(confirm_yes_button, menu_open and confirm_panel.visible)


func _confirm_action() -> void:
	if confirmation_action == "restart":
		if is_instance_valid(game_controller) and game_controller.has_method("_restart_game"):
			game_controller.call("_restart_game")
	elif confirmation_action == "quit":
		get_tree().quit()


func _cancel_confirmation() -> void:
	confirmation_action = ""
	confirm_panel.hide()
	panel.show()
	_sync_mouse_filters()
	UI_FOCUS.request(restart_button, menu_open and panel.visible)


func _refresh_hint() -> void:
	hint_label.text = "Game simulation is paused\n%s to resume" % INPUT_ACTIONS.action_hint(INPUT_ACTIONS.PAUSE)


func _unhandled_input(event: InputEvent) -> void:
	if INPUT_ACTIONS.observe_event(event):
		_refresh_hint()
	if not menu_open:
		if event.is_action_pressed(INPUT_ACTIONS.PAUSE) and not _is_echo(event):
			open_menu()
			get_viewport().set_input_as_handled()
		return

	if not confirmation_action.is_empty():
		if event.is_action_pressed(INPUT_ACTIONS.MENU_CANCEL) or event.is_action_pressed(INPUT_ACTIONS.PAUSE):
			_cancel_confirmation()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(INPUT_ACTIONS.MENU_ACCEPT):
			_confirm_action()
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed(INPUT_ACTIONS.PAUSE) or event.is_action_pressed(INPUT_ACTIONS.MENU_CANCEL):
		close_menu()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(INPUT_ACTIONS.MENU_ACCEPT):
		_activate_focused_control()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(INPUT_ACTIONS.MENU_UP):
		_move_focus(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(INPUT_ACTIONS.MENU_DOWN):
		_move_focus(1)
		get_viewport().set_input_as_handled()


func _activate_focused_control() -> void:
	var focused := get_viewport().gui_get_focus_owner() as Button
	if not is_instance_valid(focused):
		return
	focused.pressed.emit()


func _move_focus(direction: int) -> void:
	var focusable: Array[Button] = []
	if not confirmation_action.is_empty():
		for button: Button in [confirm_yes_button, confirm_no_button]:
			if UI_FOCUS.can_request(button):
				focusable.append(button)
	else:
		for button: Button in [resume_button, settings_button, restart_button, quit_button]:
			if UI_FOCUS.can_request(button):
				focusable.append(button)
	if focusable.is_empty():
		return
	var current := get_viewport().gui_get_focus_owner() as Button
	var index: int = focusable.find(current)
	if index < 0:
		index = 0
	else:
		index = posmod(index + direction, focusable.size())
	UI_FOCUS.request(
		focusable[index],
		menu_open and (confirm_panel.visible if not confirmation_action.is_empty() else panel.visible)
	)


func _is_echo(event: InputEvent) -> bool:
	return event is InputEventKey and (event as InputEventKey).echo


func _add_tiny_ui_frame(control: Control) -> void:
	var frame: Control = TINY_UI_FRAME_SCENE.instantiate() as Control
	frame.name = "TinyUIFrame"
	frame.set("button_frame", control is Button)
	frame.z_index = 0
	frame.show_behind_parent = true
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(frame)
	control.move_child(frame, 0)
