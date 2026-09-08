extends Control
class_name GloamAudioSettingsMenu

const UI_STYLE := preload("res://scripts/ui_style.gd")
const INPUT_ACTIONS := preload("res://scripts/input_actions.gd")
const TINY_UI_FRAME_SCENE := preload("res://scenes/components/tiny_ui_frame.tscn")
const UI_FOCUS := preload("res://scripts/ui_focus.gd")

const BUS_NAMES: Array[String] = ["Master", "Music", "SFX", "UI"]
const REMAP_ACTIONS: Array[StringName] = [
	&"move_up",
	&"move_down",
	&"move_left",
	&"move_right",
	&"attack",
	&"interact",
	&"pause",
]

var audio_router: GloamAudioHooks = null
var game_settings: GloamGameSettings = null
var open_button: Button
var backdrop: ColorRect
var panel: PanelContainer
var close_button: Button
var sliders: Dictionary = {}
var mute_buttons: Dictionary = {}
var value_labels: Dictionary = {}
var remap_buttons: Dictionary = {}
var fullscreen_button: CheckButton
var reduce_shake_button: CheckButton
var high_contrast_button: CheckButton
var remap_status_label: Label
var menu_open: bool = false
var was_paused: bool = false
var return_focus: Control = null
var listening_action: StringName = &""


func configure(router: GloamAudioHooks, settings: GloamGameSettings = null) -> void:
	audio_router = router
	game_settings = settings


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	_build_ui()
	_apply_style()
	_refresh_values()
	_sync_open_button_visibility()
	_sync_mouse_filters()


func _build_ui() -> void:
	open_button = Button.new()
	open_button.name = "AudioSettingsButton"
	open_button.text = "⚙"
	open_button.tooltip_text = "Settings"
	open_button.focus_mode = Control.FOCUS_ALL
	open_button.custom_minimum_size = Vector2(44.0, 36.0)
	open_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	open_button.offset_left = -58.0
	open_button.offset_top = -50.0
	open_button.offset_right = -14.0
	open_button.offset_bottom = -14.0
	open_button.mouse_filter = Control.MOUSE_FILTER_STOP
	open_button.pressed.connect(_open_menu)
	add_child(open_button)

	backdrop = ColorRect.new()
	backdrop.name = "AudioSettingsBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.01, 0.015, 0.022, 0.55)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	backdrop.hide()
	add_child(backdrop)

	panel = PanelContainer.new()
	panel.name = "AudioSettingsPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	# Leave a safe margin at 1280×720 and permit scrolling on shorter windows.
	panel.position = Vector2(-340.0, -290.0)
	panel.size = Vector2(680.0, 580.0)
	panel.custom_minimum_size = Vector2(0.0, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.hide()
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.name = "SettingsScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var content := MarginContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("margin_left", 22)
	content.add_theme_constant_override("margin_top", 22)
	content.add_theme_constant_override("margin_right", 22)
	content.add_theme_constant_override("margin_bottom", 22)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	content.add_child(vbox)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 21)
	vbox.add_child(title)

	var description := Label.new()
	description.text = "Audio controls\nChanges are saved locally."
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(description)

	for bus_name: String in BUS_NAMES:
		var row := HBoxContainer.new()
		row.name = "%sRow" % bus_name
		row.custom_minimum_size = Vector2(0.0, 42.0)
		vbox.add_child(row)

		var label := Label.new()
		var music_unavailable: bool = bus_name == "Music"
		label.text = "MUSIC (NO TRACK)" if music_unavailable else bus_name
		label.custom_minimum_size = Vector2(72.0, 0.0)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)

		var slider := HSlider.new()
		slider.name = "%sVolume" % bus_name
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.custom_minimum_size = Vector2(132.0, 32.0)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.focus_mode = Control.FOCUS_ALL
		slider.value_changed.connect(_on_volume_changed.bind(bus_name))
		slider.editable = not music_unavailable
		slider.focus_mode = Control.FOCUS_NONE if music_unavailable else Control.FOCUS_ALL
		slider.mouse_filter = Control.MOUSE_FILTER_IGNORE if music_unavailable else Control.MOUSE_FILTER_STOP
		row.add_child(slider)
		sliders[bus_name] = slider

		var value_label := Label.new()
		value_label.name = "%sPercent" % bus_name
		value_label.custom_minimum_size = Vector2(58.0, 0.0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(value_label)
		value_labels[bus_name] = value_label

		var mute_button := CheckButton.new()
		mute_button.name = "%sMute" % bus_name
		mute_button.text = "Mute"
		mute_button.focus_mode = Control.FOCUS_ALL
		mute_button.toggled.connect(_on_mute_toggled.bind(bus_name))
		mute_button.disabled = music_unavailable
		row.add_child(mute_button)
		mute_buttons[bus_name] = mute_button

	var display_heading := Label.new()
	display_heading.text = "DISPLAY & ACCESSIBILITY"
	display_heading.add_theme_font_size_override("font_size", 16)
	display_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(display_heading)

	fullscreen_button = CheckButton.new()
	fullscreen_button.name = "Fullscreen"
	fullscreen_button.text = "Fullscreen / windowed mode"
	fullscreen_button.focus_mode = Control.FOCUS_ALL
	fullscreen_button.toggled.connect(_on_fullscreen_toggled)
	vbox.add_child(fullscreen_button)

	reduce_shake_button = CheckButton.new()
	reduce_shake_button.name = "ReduceScreenShake"
	reduce_shake_button.text = "Reduce screen shake"
	reduce_shake_button.focus_mode = Control.FOCUS_ALL
	reduce_shake_button.toggled.connect(_on_reduce_shake_toggled)
	vbox.add_child(reduce_shake_button)

	high_contrast_button = CheckButton.new()
	high_contrast_button.name = "HighContrast"
	high_contrast_button.text = "High contrast threat indicators and prompts"
	high_contrast_button.focus_mode = Control.FOCUS_ALL
	high_contrast_button.toggled.connect(_on_high_contrast_toggled)
	vbox.add_child(high_contrast_button)

	var input_heading := Label.new()
	input_heading.text = "INPUT REMAPPING"
	input_heading.add_theme_font_size_override("font_size", 16)
	input_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(input_heading)

	for action_name: StringName in REMAP_ACTIONS:
		var row := HBoxContainer.new()
		row.name = "%sRemapRow" % str(action_name).capitalize()
		row.custom_minimum_size = Vector2(0.0, 34.0)
		vbox.add_child(row)

		var label := Label.new()
		label.text = _action_display_name(action_name)
		label.custom_minimum_size = Vector2(190.0, 0.0)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)

		var remap_button := Button.new()
		remap_button.name = "%sRemap" % str(action_name).capitalize()
		remap_button.focus_mode = Control.FOCUS_ALL
		remap_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		remap_button.pressed.connect(_start_remap.bind(action_name))
		row.add_child(remap_button)
		remap_buttons[action_name] = remap_button

	remap_status_label = Label.new()
	remap_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	remap_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(remap_status_label)

	close_button = Button.new()
	close_button.name = "Close"
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.custom_minimum_size = Vector2(0.0, 44.0)
	close_button.pressed.connect(_close_menu)
	vbox.add_child(close_button)

	_refresh_close_prompt()


func _apply_style() -> void:
	var theme_resource: Theme = UI_STYLE.create_theme()
	theme = theme_resource
	panel.add_theme_stylebox_override("panel", UI_STYLE.make_modal_panel_style())
	open_button.add_theme_stylebox_override("normal", UI_STYLE.make_asset_button_style())
	open_button.add_theme_stylebox_override("hover", UI_STYLE.make_asset_button_style())
	open_button.add_theme_stylebox_override("pressed", UI_STYLE.make_asset_button_style())
	close_button.add_theme_stylebox_override("normal", UI_STYLE.make_asset_button_style())
	close_button.add_theme_stylebox_override("hover", UI_STYLE.make_asset_button_style())
	close_button.add_theme_stylebox_override("pressed", UI_STYLE.make_asset_button_style())
	for button: Button in [open_button, close_button]:
		_add_tiny_ui_frame(button)
	for remap_button: Button in remap_buttons.values():
		remap_button.add_theme_stylebox_override("normal", UI_STYLE.make_asset_button_style())
		remap_button.add_theme_stylebox_override("hover", UI_STYLE.make_asset_button_style())
		remap_button.add_theme_stylebox_override("pressed", UI_STYLE.make_asset_button_style())
		_add_tiny_ui_frame(remap_button)


func _refresh_values() -> void:
	if not is_instance_valid(audio_router):
		return
	for bus_name: String in BUS_NAMES:
		var slider: HSlider = sliders[bus_name] as HSlider
		var mute_button: CheckButton = mute_buttons[bus_name] as CheckButton
		slider.set_value_no_signal(audio_router.get_bus_volume(bus_name))
		mute_button.set_pressed_no_signal(audio_router.is_bus_muted(bus_name))
		_update_value_label(bus_name, slider.value)
	if is_instance_valid(game_settings):
		fullscreen_button.set_pressed_no_signal(game_settings.fullscreen)
		reduce_shake_button.set_pressed_no_signal(game_settings.reduce_screen_shake)
		high_contrast_button.set_pressed_no_signal(game_settings.high_contrast)
	for action_name: StringName in REMAP_ACTIONS:
		var remap_button: Button = remap_buttons[action_name] as Button
		remap_button.text = "%s  •  REMAP" % _action_binding_text(action_name)
	remap_status_label.text = (
		"Press a keyboard key, mouse button, or controller button to replace this device binding.\n"
		+ "Press %s to cancel."
		% INPUT_ACTIONS.action_hint(INPUT_ACTIONS.MENU_CANCEL)
		if not listening_action.is_empty()
		else ""
	)


func _update_value_label(bus_name: String, value: float) -> void:
	var value_label: Label = value_labels[bus_name] as Label
	# Music currently has no active stream; a percentage would imply otherwise.
	value_label.text = "—" if bus_name == "Music" else "%d%%" % int(round(value * 100.0))


func _on_volume_changed(value: float, bus_name: String) -> void:
	if not is_instance_valid(audio_router):
		return
	_update_value_label(bus_name, value)
	audio_router.set_bus_volume(bus_name, value)


func _on_mute_toggled(muted: bool, bus_name: String) -> void:
	if not is_instance_valid(audio_router):
		return
	audio_router.set_bus_muted(bus_name, muted)


func _on_fullscreen_toggled(enabled: bool) -> void:
	if is_instance_valid(game_settings):
		game_settings.set_fullscreen(enabled)


func _on_reduce_shake_toggled(enabled: bool) -> void:
	if is_instance_valid(game_settings):
		game_settings.set_reduce_screen_shake(enabled)


func _on_high_contrast_toggled(enabled: bool) -> void:
	if is_instance_valid(game_settings):
		game_settings.set_high_contrast(enabled)


func _start_remap(action_name: StringName) -> void:
	if not is_instance_valid(game_settings) or not game_settings.begin_remap(action_name):
		return
	listening_action = action_name
	remap_status_label.text = (
		"Listening for %s. Press a key, mouse button, or controller button.\nPress %s to cancel."
		% [_action_display_name(action_name), INPUT_ACTIONS.action_hint(INPUT_ACTIONS.MENU_CANCEL)]
	)
	var focused: Control = get_viewport().gui_get_focus_owner() as Control
	if is_instance_valid(focused):
		focused.release_focus()


func _cancel_remap() -> void:
	listening_action = &""
	_refresh_values()


func open_menu(focus_return: Control = null) -> void:
	if menu_open or not _can_open_menu():
		return
	menu_open = true
	return_focus = focus_return
	listening_action = &""
	was_paused = get_tree().paused
	_refresh_values()
	_refresh_close_prompt()
	backdrop.show()
	panel.show()
	open_button.hide()
	_sync_mouse_filters()
	get_tree().paused = true
	_refresh_host_hud_controls()
	_grab_first_focus()
	if is_instance_valid(audio_router):
		audio_router.request("ui_open", Vector2.ZERO, 0.8)


func _open_menu() -> void:
	open_menu()


func close_menu() -> void:
	if not menu_open:
		return
	menu_open = false
	listening_action = &""
	panel.hide()
	backdrop.hide()
	open_button.show()
	get_tree().paused = was_paused
	_sync_open_button_visibility()
	_sync_mouse_filters()
	_refresh_host_hud_controls()
	if is_instance_valid(return_focus) and UI_FOCUS.can_request(return_focus):
		UI_FOCUS.request(return_focus, not menu_open)
	else:
		UI_FOCUS.request(open_button, not menu_open and open_button.visible)
	return_focus = null
	if is_instance_valid(audio_router):
		audio_router.request("ui_cancel", Vector2.ZERO, 0.7)


func _close_menu() -> void:
	close_menu()


func is_open() -> bool:
	return menu_open


func _refresh_close_prompt() -> void:
	if is_instance_valid(close_button):
		close_button.text = "CLOSE  [%s]" % INPUT_ACTIONS.action_hint(INPUT_ACTIONS.MENU_CANCEL)


func _grab_first_focus() -> void:
	if sliders.has("Master") and UI_FOCUS.can_request(sliders["Master"] as Control):
		UI_FOCUS.request(sliders["Master"] as Control, menu_open and panel.visible)
	else:
		UI_FOCUS.request(close_button, menu_open and panel.visible)


func _focusable_controls() -> Array[Control]:
	var controls: Array[Control] = []
	for bus_name: String in BUS_NAMES:
		controls.append(sliders[bus_name] as Control)
		controls.append(mute_buttons[bus_name] as Control)
	controls.append(fullscreen_button)
	controls.append(reduce_shake_button)
	controls.append(high_contrast_button)
	for action_name: StringName in REMAP_ACTIONS:
		controls.append(remap_buttons[action_name] as Control)
	controls.append(close_button)
	return controls


func _move_focus(direction: int) -> void:
	var controls: Array[Control] = []
	for control: Control in _focusable_controls():
		if UI_FOCUS.can_request(control):
			controls.append(control)
	if controls.is_empty():
		return
	var current: Control = get_viewport().gui_get_focus_owner() as Control
	var index: int = controls.find(current)
	if index < 0:
		index = 0
	else:
		index = posmod(index + direction, controls.size())
	UI_FOCUS.request(controls[index], menu_open and panel.visible)


func _can_open_menu() -> bool:
	if not is_instance_valid(game_settings):
		return true
	var host: Node = get_parent().get_parent()
	if not is_instance_valid(host):
		return true
	if not host.is_node_ready():
		return true
	return not host.has_method("can_open_settings") or bool(host.call("can_open_settings"))


func _sync_open_button_visibility() -> void:
	if is_instance_valid(open_button) and not menu_open:
		open_button.visible = _can_open_menu()


func _sync_mouse_filters() -> void:
	# The full-screen shell is passive. Only the live settings button, backdrop,
	# and panel are allowed to participate in mouse hit testing.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	open_button.mouse_filter = Control.MOUSE_FILTER_STOP if open_button.visible else Control.MOUSE_FILTER_IGNORE
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP if backdrop.visible else Control.MOUSE_FILTER_IGNORE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP if panel.visible else Control.MOUSE_FILTER_IGNORE
	_set_interactive_filters(panel, panel.visible)


func _refresh_host_hud_controls() -> void:
	var host := get_parent().get_parent()
	if is_instance_valid(host) and host.has_method("_refresh_skip_to_night_control"):
		host.call("_refresh_skip_to_night_control")
	if is_instance_valid(host) and host.has_method("_refresh_manage_village_control"):
		host.call("_refresh_manage_village_control")


func _set_interactive_filters(node: Node, enabled: bool) -> void:
	for child: Node in node.get_children():
		if child is BaseButton or child is HSlider or child is VSlider:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_STOP if enabled and (child as Control).visible else Control.MOUSE_FILTER_IGNORE
		_set_interactive_filters(child, enabled)


func _process(_delta: float) -> void:
	_sync_open_button_visibility()
	_sync_mouse_filters()


func _action_display_name(action_name: StringName) -> String:
	match action_name:
		&"move_up":
			return "Move up"
		&"move_down":
			return "Move down"
		&"move_left":
			return "Move left"
		&"move_right":
			return "Move right"
		&"attack":
			return "Attack"
		&"interact":
			return "Interact"
		&"pause":
			return "Pause"
	return str(action_name).capitalize()


func _action_binding_text(action_name: StringName) -> String:
	if is_instance_valid(game_settings):
		return game_settings.action_binding_text(action_name)
	return INPUT_ACTIONS.action_hint(action_name)


func _add_tiny_ui_frame(button: Button) -> void:
	var frame: Control = TINY_UI_FRAME_SCENE.instantiate() as Control
	frame.name = "TinyUIFrame"
	frame.set("button_frame", true)
	frame.z_index = 0
	frame.show_behind_parent = true
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(frame)
	button.move_child(frame, 0)


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_close_menu()


func _input(event: InputEvent) -> void:
	if INPUT_ACTIONS.observe_event(event):
		_refresh_close_prompt()
	if not menu_open:
		return
	if not listening_action.is_empty():
		if event.is_action_pressed(INPUT_ACTIONS.MENU_CANCEL):
			get_viewport().set_input_as_handled()
			_cancel_remap()
			return
		if event is InputEventKey and (event as InputEventKey).echo:
			return
		if event.is_pressed() and is_instance_valid(game_settings) and game_settings.remap_action(listening_action, event):
			get_viewport().set_input_as_handled()
			listening_action = &""
			_refresh_values()
		return
	if event.is_action_pressed(INPUT_ACTIONS.MENU_CANCEL) or event.is_action_pressed(INPUT_ACTIONS.PAUSE):
		get_viewport().set_input_as_handled()
		close_menu()


func _unhandled_input(event: InputEvent) -> void:
	if not menu_open:
		return
	var focused: Control = get_viewport().gui_get_focus_owner() as Control
	if focused is HSlider and event.is_action_pressed(INPUT_ACTIONS.MENU_LEFT):
		var slider: HSlider = focused as HSlider
		slider.value = maxf(slider.min_value, slider.value - slider.step)
		get_viewport().set_input_as_handled()
	elif focused is HSlider and event.is_action_pressed(INPUT_ACTIONS.MENU_RIGHT):
		var slider: HSlider = focused as HSlider
		slider.value = minf(slider.max_value, slider.value + slider.step)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(INPUT_ACTIONS.MENU_UP):
		_move_focus(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(INPUT_ACTIONS.MENU_DOWN):
		_move_focus(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(INPUT_ACTIONS.MENU_ACCEPT):
		if focused is BaseButton:
			(focused as BaseButton).pressed.emit()
		elif focused is HSlider:
			pass
		get_viewport().set_input_as_handled()
