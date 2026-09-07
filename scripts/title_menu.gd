extends Control
class_name GloamTitleMenu

## The title shell owns only navigation. Run state remains owned by Main.

const UI_STYLE := preload("res://scripts/ui_style.gd")
const INPUT_ACTIONS := preload("res://scripts/input_actions.gd")
const UI_FOCUS := preload("res://scripts/ui_focus.gd")

var game_controller: Node = null
var settings_menu: GloamAudioSettingsMenu = null
var panel: PanelContainer
var confirmation_panel: PanelContainer
var credits_panel: PanelContainer
var new_run_button: Button
var continue_button: Button
var settings_button: Button
var credits_button: Button
var quit_button: Button
var confirm_button: Button
var cancel_button: Button
var credits_close_button: Button
var has_checkpoint: bool = false
var menu_open: bool = false


func configure(controller: Node, audio_settings: GloamAudioSettingsMenu) -> void:
	game_controller = controller
	settings_menu = audio_settings


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 70
	_build_ui()
	_apply_style()
	hide()


func open_menu(checkpoint_available: bool) -> void:
	has_checkpoint = checkpoint_available
	menu_open = true
	continue_button.disabled = not has_checkpoint
	show()
	panel.show()
	confirmation_panel.hide()
	credits_panel.hide()
	get_tree().paused = true
	UI_FOCUS.request(new_run_button, true)


func close_menu() -> void:
	menu_open = false
	hide()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.008, 0.012, 0.018, 0.88)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	panel = _make_panel("TitlePanel", Vector2(480, 510))
	var box := _content_box(panel)
	var title := Label.new()
	title.text = "GLOAM"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Hold the village through the long night."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	new_run_button = _button("NEW RUN")
	new_run_button.pressed.connect(_new_run)
	box.add_child(new_run_button)
	continue_button = _button("CONTINUE")
	continue_button.pressed.connect(_continue_run)
	box.add_child(continue_button)
	settings_button = _button("SETTINGS")
	settings_button.pressed.connect(_open_settings)
	box.add_child(settings_button)
	credits_button = _button("CREDITS")
	credits_button.pressed.connect(_open_credits)
	box.add_child(credits_button)
	quit_button = _button("QUIT")
	quit_button.pressed.connect(func(): get_tree().quit())
	box.add_child(quit_button)

	confirmation_panel = _make_panel("NewRunConfirmation", Vector2(480, 255))
	var confirm_box := _content_box(confirmation_panel)
	var warning := Label.new()
	warning.text = "REPLACE DAWN CHECKPOINT?\nStarting a new run permanently replaces the saved dawn."
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_box.add_child(warning)
	confirm_button = _button("START NEW RUN")
	confirm_button.pressed.connect(_confirm_new_run)
	confirm_box.add_child(confirm_button)
	cancel_button = _button("CANCEL")
	cancel_button.pressed.connect(_cancel_confirmation)
	confirm_box.add_child(cancel_button)
	confirmation_panel.hide()

	credits_panel = _make_panel("CreditsPanel", Vector2(540, 350))
	var credits_box := _content_box(credits_panel)
	var credits := Label.new()
	credits.text = "CREDITS & ATTRIBUTION\n\nGloam\nGame design and implementation\n\nTiny Swords artwork\nGloam uses curated runtime derivatives from the supplied Tiny Swords source pack.\n\nAttribution record: assets/generated/tiny_swords/ATTRIBUTION.md\nThe supplied pack included no license or attribution terms; this screen intentionally makes no unverified licensing claim."
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credits_box.add_child(credits)
	credits_close_button = _button("BACK")
	credits_close_button.pressed.connect(_close_credits)
	credits_box.add_child(credits_close_button)
	credits_panel.hide()


func _make_panel(panel_name: String, size_value: Vector2) -> PanelContainer:
	var result := PanelContainer.new()
	result.name = panel_name
	result.set_anchors_preset(Control.PRESET_CENTER)
	result.position = -size_value * 0.5
	result.size = size_value
	result.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(result)
	return result


func _content_box(parent: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	parent.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	return box


func _button(label: String) -> Button:
	var result := Button.new()
	result.text = label
	result.focus_mode = Control.FOCUS_ALL
	result.custom_minimum_size = Vector2(0, 48)
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return result


func _apply_style() -> void:
	theme = UI_STYLE.create_theme()
	for modal: PanelContainer in [panel, confirmation_panel, credits_panel]:
		modal.add_theme_stylebox_override("panel", UI_STYLE.make_modal_panel_style())
	for button: Button in [new_run_button, continue_button, settings_button, credits_button, quit_button, confirm_button, cancel_button, credits_close_button]:
		var style := UI_STYLE.make_asset_button_style()
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)


func _new_run() -> void:
	if has_checkpoint:
		panel.hide()
		confirmation_panel.show()
		UI_FOCUS.request(confirm_button, true)
	else:
		_confirm_new_run()


func _confirm_new_run() -> void:
	if is_instance_valid(game_controller) and game_controller.has_method("start_new_run_from_title"):
		game_controller.call("start_new_run_from_title")


func _continue_run() -> void:
	if has_checkpoint and is_instance_valid(game_controller) and game_controller.has_method("continue_run_from_title"):
		game_controller.call("continue_run_from_title")


func _open_settings() -> void:
	if is_instance_valid(settings_menu):
		settings_menu.open_menu(settings_button)


func _open_credits() -> void:
	panel.hide()
	credits_panel.show()
	UI_FOCUS.request(credits_close_button, true)


func _close_credits() -> void:
	credits_panel.hide()
	panel.show()
	UI_FOCUS.request(credits_button, true)


func _cancel_confirmation() -> void:
	confirmation_panel.hide()
	panel.show()
	UI_FOCUS.request(new_run_button, true)


func _unhandled_input(event: InputEvent) -> void:
	if not menu_open or (is_instance_valid(settings_menu) and settings_menu.is_open()):
		return
	if event.is_action_pressed(INPUT_ACTIONS.MENU_CANCEL):
		if credits_panel.visible:
			_close_credits()
		elif confirmation_panel.visible:
			_cancel_confirmation()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(INPUT_ACTIONS.MENU_ACCEPT):
		var focused := get_viewport().gui_get_focus_owner() as BaseButton
		if is_instance_valid(focused) and not focused.disabled:
			focused.emit_signal("pressed")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(INPUT_ACTIONS.MENU_UP) or event.is_action_pressed(INPUT_ACTIONS.MENU_DOWN):
		var active_panel := credits_panel if credits_panel.visible else confirmation_panel if confirmation_panel.visible else panel
		var buttons: Array[Button] = []
		for candidate: Node in active_panel.find_children("", "Button", true, false):
			if candidate is Button and not (candidate as Button).disabled:
				buttons.append(candidate as Button)
		var current := get_viewport().gui_get_focus_owner() as Button
		var index := buttons.find(current)
		var direction := -1 if event.is_action_pressed(INPUT_ACTIONS.MENU_UP) else 1
		if not buttons.is_empty():
			UI_FOCUS.request(buttons[posmod(index + direction if index >= 0 else 0, buttons.size())], true)
		get_viewport().set_input_as_handled()
