extends Control
class_name GloamContextualInteractionMenu

signal prompt_pressed
signal choice_selected(choice_id: String)
signal closed

const UI_STYLE := preload("res://scripts/ui_style.gd")
const INPUT_ACTIONS := preload("res://scripts/input_actions.gd")
const UI_FOCUS := preload("res://scripts/ui_focus.gd")

var prompt_button: Button
var menu_panel: PanelContainer
var title_label: Label
var description_label: Label
var choices_container: VBoxContainer
var close_button: Button
var choice_buttons: Array[Button] = []
var choice_latched: bool = false
var prompt_reentry_locked: bool = false
var menu_accept_blocked_until_release: bool = false
var high_contrast: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	prompt_button = Button.new()
	prompt_button.name = "InteractionPrompt"
	prompt_button.focus_mode = Control.FOCUS_ALL
	prompt_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	prompt_button.custom_minimum_size = Vector2(360.0, 48.0)
	prompt_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_button.position = Vector2(-180.0, -78.0)
	prompt_button.size = Vector2(360.0, 48.0)
	prompt_button.mouse_filter = Control.MOUSE_FILTER_STOP
	prompt_button.pressed.connect(_on_prompt_pressed)
	add_child(prompt_button)

	menu_panel = PanelContainer.new()
	menu_panel.name = "InteractionChoices"
	menu_panel.custom_minimum_size = Vector2(700.0, 0.0)
	menu_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	menu_panel.position = Vector2(-350.0, -530.0)
	menu_panel.size = Vector2(700.0, 500.0)
	menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(menu_panel)

	var content := MarginContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("margin_left", 22)
	content.add_theme_constant_override("margin_top", 22)
	content.add_theme_constant_override("margin_right", 22)
	content.add_theme_constant_override("margin_bottom", 22)
	menu_panel.add_child(content)

	var menu_vbox := VBoxContainer.new()
	menu_vbox.name = "VBox"
	menu_vbox.add_theme_constant_override("separation", 8)
	content.add_child(menu_vbox)

	title_label = Label.new()
	title_label.name = "Title"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 21)
	menu_vbox.add_child(title_label)

	description_label = Label.new()
	description_label.name = "Description"
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_vbox.add_child(description_label)

	choices_container = VBoxContainer.new()
	choices_container.name = "Choices"
	choices_container.add_theme_constant_override("separation", 7)
	menu_vbox.add_child(choices_container)

	close_button = Button.new()
	close_button.name = "Close"
	close_button.custom_minimum_size = Vector2(0.0, 44.0)
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.pressed.connect(_on_close_pressed)
	menu_vbox.add_child(close_button)

	menu_panel.hide()
	prompt_button.hide()
	_sync_mouse_filters()
	refresh_device_prompt()
	_apply_local_style()


func _apply_local_style() -> void:
	var theme_resource: Theme = UI_STYLE.create_theme()
	theme = theme_resource
	menu_panel.add_theme_stylebox_override("panel", UI_STYLE.make_modal_panel_style())
	prompt_button.add_theme_stylebox_override("normal", UI_STYLE.make_asset_button_style())
	prompt_button.add_theme_stylebox_override("hover", UI_STYLE.make_asset_button_style())
	prompt_button.add_theme_stylebox_override("pressed", UI_STYLE.make_asset_button_style())
	close_button.add_theme_stylebox_override("normal", UI_STYLE.make_asset_button_style())
	close_button.add_theme_stylebox_override("hover", UI_STYLE.make_asset_button_style())
	close_button.add_theme_stylebox_override("pressed", UI_STYLE.make_asset_button_style())


func set_prompt(prompt_text: String, visible_prompt: bool = true) -> void:
	if not is_instance_valid(prompt_button) or not is_instance_valid(menu_panel):
		return
	prompt_button.text = prompt_text
	prompt_button.visible = visible_prompt and not menu_panel.visible
	if prompt_button.visible:
		UI_FOCUS.request(prompt_button, is_inside_tree() and not menu_panel.visible, true)


func hide_prompt() -> void:
	prompt_button.hide()


func set_high_contrast(enabled: bool) -> void:
	high_contrast = enabled
	if not is_instance_valid(prompt_button):
		return
	for control: Control in [prompt_button, close_button]:
		if high_contrast:
			control.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
			control.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
			control.add_theme_constant_override("outline_size", 2)
		else:
			control.remove_theme_color_override("font_color")
			control.remove_theme_color_override("font_outline_color")
			control.remove_theme_constant_override("outline_size")
	for button: Button in choice_buttons:
		if high_contrast:
			button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
			button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
			button.add_theme_constant_override("outline_size", 2)
		else:
			button.remove_theme_color_override("font_color")
			button.remove_theme_color_override("font_outline_color")
			button.remove_theme_constant_override("outline_size")


func refresh_device_prompt() -> void:
	if is_instance_valid(close_button):
		close_button.text = "CLOSE  [%s]" % INPUT_ACTIONS.action_hint(INPUT_ACTIONS.MENU_CANCEL)


func open_menu(menu_title: String, menu_description: String, choices: Array[Dictionary]) -> void:
	choice_latched = false
	title_label.text = menu_title
	description_label.text = menu_description
	_clear_choices()

	for choice: Dictionary in choices:
		var button := Button.new()
		button.focus_mode = Control.FOCUS_ALL
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0.0, 72.0)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = str(choice.get("text", ""))
		button.disabled = not bool(choice.get("enabled", false))
		button.tooltip_text = str(choice.get("tooltip", button.text))
		button.set_meta("choice_id", str(choice.get("id", "")))
		button.mouse_default_cursor_shape = (
			Control.CURSOR_ARROW if button.disabled else Control.CURSOR_POINTING_HAND
		)
		button.add_theme_stylebox_override("normal", UI_STYLE.make_asset_button_style())
		button.add_theme_stylebox_override("hover", UI_STYLE.make_asset_button_style())
		button.add_theme_stylebox_override("pressed", UI_STYLE.make_asset_button_style())
		button.add_theme_stylebox_override("disabled", UI_STYLE.make_asset_button_style())
		var frame := preload("res://scenes/components/tiny_ui_frame.tscn").instantiate() as Control
		frame.name = "TinyUIFrame"
		frame.set("button_frame", true)
		frame.z_index = 0
		frame.show_behind_parent = true
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(frame)
		button.move_child(frame, 0)
		button.pressed.connect(_on_choice_pressed.bind(button))
		choices_container.add_child(button)
		choice_buttons.append(button)
		set_high_contrast(high_contrast)

	menu_panel.show()
	prompt_button.hide()
	_sync_mouse_filters()
	_grab_first_available_focus()


func close_menu(notify: bool = true) -> void:
	choice_latched = false
	menu_panel.hide()
	_sync_mouse_filters()
	if notify:
		closed.emit()


func is_menu_open() -> bool:
	return menu_panel.visible


func allow_choice_retry() -> void:
	choice_latched = false


func _clear_choices() -> void:
	for button: Button in choice_buttons:
		if is_instance_valid(button):
			choices_container.remove_child(button)
			button.free()
	choice_buttons.clear()


func _grab_first_available_focus() -> void:
	if not is_instance_valid(menu_panel) or not menu_panel.visible:
		return
	for button: Button in choice_buttons:
		if not button.disabled and UI_FOCUS.can_request(button):
			UI_FOCUS.request(button, menu_panel.visible)
			return
	UI_FOCUS.request(close_button, menu_panel.visible)


func _on_prompt_pressed() -> void:
	if prompt_reentry_locked:
		return
	menu_accept_blocked_until_release = true
	prompt_pressed.emit()


func _on_choice_pressed(button: Button) -> void:
	if choice_latched or button.disabled:
		return
	choice_latched = true
	prompt_reentry_locked = true
	choice_selected.emit(str(button.get_meta("choice_id", "")))


func _on_close_pressed() -> void:
	close_menu(true)


func _sync_mouse_filters() -> void:
	# The full-screen menu shell is passive. Its prompt/panel and the live
	# buttons inside the panel are the only controls that may hit-test.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_button.mouse_filter = Control.MOUSE_FILTER_STOP if prompt_button.visible else Control.MOUSE_FILTER_IGNORE
	menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP if menu_panel.visible else Control.MOUSE_FILTER_IGNORE
	_set_interactive_filters(menu_panel, menu_panel.visible)


func _set_interactive_filters(node: Node, enabled: bool) -> void:
	for child: Node in node.get_children():
		if child is BaseButton or child is HSlider or child is VSlider:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_STOP if enabled and (child as Control).visible else Control.MOUSE_FILTER_IGNORE
		_set_interactive_filters(child, enabled)


func _unhandled_input(event: InputEvent) -> void:
	if INPUT_ACTIONS.observe_event(event):
		refresh_device_prompt()

	if menu_panel.visible:
		if event.is_action_pressed(INPUT_ACTIONS.MENU_CANCEL):
			get_viewport().set_input_as_handled()
			close_menu(true)
			return

		if event.is_action_pressed(INPUT_ACTIONS.MENU_UP):
			_move_focus(-1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(INPUT_ACTIONS.MENU_DOWN):
			_move_focus(1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(INPUT_ACTIONS.MENU_LEFT):
			_move_focus(-1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(INPUT_ACTIONS.MENU_RIGHT):
			_move_focus(1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(INPUT_ACTIONS.MENU_ACCEPT):
			if menu_accept_blocked_until_release:
				get_viewport().set_input_as_handled()
				return
			_activate_focused_control()
			get_viewport().set_input_as_handled()
			return
		return

	if prompt_button.visible and event.is_action_pressed(INPUT_ACTIONS.INTERACT) and not prompt_reentry_locked:
		get_viewport().set_input_as_handled()
		_on_prompt_pressed()


func _move_focus(direction: int) -> void:
	var focusable: Array[Button] = []
	for button: Button in choice_buttons:
		if not button.disabled and UI_FOCUS.can_request(button):
			focusable.append(button)
	if UI_FOCUS.can_request(close_button):
		focusable.append(close_button)
	if focusable.is_empty():
		return

	var current: Control = get_viewport().gui_get_focus_owner() as Control
	var current_index: int = focusable.find(current as Button)
	if current_index < 0:
		current_index = 0 if direction > 0 else focusable.size() - 1
	else:
		current_index = posmod(current_index + direction, focusable.size())
	UI_FOCUS.request(focusable[current_index], menu_panel.visible)


func _activate_focused_control() -> void:
	var focused: Button = get_viewport().gui_get_focus_owner() as Button
	if not is_instance_valid(focused):
		return
	if focused == close_button:
		_on_close_pressed()
	elif choice_buttons.has(focused) and not focused.disabled:
		_on_choice_pressed(focused)


func _input(event: InputEvent) -> void:
	if INPUT_ACTIONS.observe_event(event):
		refresh_device_prompt()
	if menu_panel.visible and menu_accept_blocked_until_release and event.is_action_pressed(INPUT_ACTIONS.MENU_ACCEPT):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_released(INPUT_ACTIONS.INTERACT) or event.is_action_released(INPUT_ACTIONS.MENU_ACCEPT):
		menu_accept_blocked_until_release = false
		prompt_reentry_locked = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			menu_accept_blocked_until_release = false
			prompt_reentry_locked = false
