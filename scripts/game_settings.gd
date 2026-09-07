extends Node
class_name GloamGameSettings

## Persistent non-audio shell settings. Audio buses remain owned by AudioHooks;
## this service owns display, accessibility, and user-remappable actions.

signal settings_changed
signal remap_started(action_name: StringName)
signal remap_finished(action_name: StringName, success: bool)

const SETTINGS_PATH: String = "user://gloam_game_settings.cfg"
const REMAPPABLE_ACTIONS: Array[StringName] = [
	&"move_up",
	&"move_down",
	&"move_left",
	&"move_right",
	&"attack",
	&"interact",
	&"pause",
]

var settings_path: String = SETTINGS_PATH
var fullscreen: bool = false
var reduce_screen_shake: bool = false
var high_contrast: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_apply_display_mode()


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	_apply_display_mode()
	_save_settings()
	settings_changed.emit()


func set_reduce_screen_shake(enabled: bool) -> void:
	reduce_screen_shake = enabled
	_save_settings()
	settings_changed.emit()


func set_high_contrast(enabled: bool) -> void:
	high_contrast = enabled
	_save_settings()
	settings_changed.emit()


func screen_shake_scale() -> float:
	return 0.0 if reduce_screen_shake else 1.0


func begin_remap(action_name: StringName) -> bool:
	return action_name in REMAPPABLE_ACTIONS


func remap_action(action_name: StringName, event: InputEvent) -> bool:
	if action_name not in REMAPPABLE_ACTIONS or not _is_supported_remap_event(event):
		return false

	var copied_event: InputEvent = event.duplicate() as InputEvent
	# InputMap stores the binding, not the transient button state that was
	# present while the user was listening for a remap.
	if copied_event is InputEventKey:
		(copied_event as InputEventKey).pressed = false
		(copied_event as InputEventKey).echo = false
	elif copied_event is InputEventMouseButton:
		(copied_event as InputEventMouseButton).pressed = false
	elif copied_event is InputEventJoypadButton:
		(copied_event as InputEventJoypadButton).pressed = false
	var device_class: String = _event_device_class(copied_event)
	for existing_event: InputEvent in InputMap.action_get_events(action_name):
		if _event_device_class(existing_event) == device_class:
			InputMap.action_erase_event(action_name, existing_event)
	InputMap.action_add_event(action_name, copied_event)
	_save_action_binding(action_name, copied_event)
	_save_settings()
	settings_changed.emit()
	return true


func action_binding_text(action_name: StringName) -> String:
	var events: Array[InputEvent] = InputMap.action_get_events(action_name)
	for event: InputEvent in events:
		if event is InputEventKey:
			return _event_text(event)
	for event: InputEvent in events:
		if event is InputEventMouseButton:
			return _event_text(event)
	for event: InputEvent in events:
		if event is InputEventJoypadButton:
			return _event_text(event)
	return "UNBOUND"


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return

	fullscreen = bool(config.get_value("display", "fullscreen", false))
	reduce_screen_shake = bool(config.get_value("accessibility", "reduce_screen_shake", false))
	high_contrast = bool(config.get_value("accessibility", "high_contrast", false))

	for action_name: StringName in REMAPPABLE_ACTIONS:
		var value: Variant = config.get_value("input", str(action_name), {})
		if value is Dictionary:
			var event: InputEvent = _event_from_data(value as Dictionary)
			if is_instance_valid(event):
				var device_class: String = _event_device_class(event)
				for existing_event: InputEvent in InputMap.action_get_events(action_name):
					if _event_device_class(existing_event) == device_class:
						InputMap.action_erase_event(action_name, existing_event)
				InputMap.action_add_event(action_name, event)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("accessibility", "reduce_screen_shake", reduce_screen_shake)
	config.set_value("accessibility", "high_contrast", high_contrast)
	for action_name: StringName in REMAPPABLE_ACTIONS:
		var preferred_event: InputEvent = _preferred_event(action_name)
		if is_instance_valid(preferred_event):
			config.set_value("input", str(action_name), _event_to_data(preferred_event))
	config.save(settings_path)


func _save_action_binding(action_name: StringName, event: InputEvent) -> void:
	var config := ConfigFile.new()
	config.load(settings_path)
	config.set_value("input", str(action_name), _event_to_data(event))
	config.save(settings_path)


func _apply_display_mode() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _preferred_event(action_name: StringName) -> InputEvent:
	var events: Array[InputEvent] = InputMap.action_get_events(action_name)
	for event: InputEvent in events:
		if event is InputEventKey:
			return event
	for event: InputEvent in events:
		if event is InputEventMouseButton:
			return event
	for event: InputEvent in events:
		if event is InputEventJoypadButton:
			return event
	return null


func _is_supported_remap_event(event: InputEvent) -> bool:
	return event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton


func _event_device_class(event: InputEvent) -> String:
	if event is InputEventKey:
		return "keyboard"
	if event is InputEventMouseButton:
		return "mouse"
	if event is InputEventJoypadButton:
		return "controller"
	return "other"


func _event_to_data(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		return {
			"type": "key",
			"physical_keycode": int(key_event.physical_keycode),
			"keycode": int(key_event.keycode),
		}
	if event is InputEventMouseButton:
		return {
			"type": "mouse",
			"button_index": int((event as InputEventMouseButton).button_index),
		}
	if event is InputEventJoypadButton:
		return {
			"type": "joypad",
			"button_index": int((event as InputEventJoypadButton).button_index),
		}
	return {}


func _event_from_data(data: Dictionary) -> InputEvent:
	match str(data.get("type", "")):
		"key":
			var key_event := InputEventKey.new()
			key_event.physical_keycode = int(data.get("physical_keycode", 0))
			key_event.keycode = int(data.get("keycode", 0))
			return key_event
		"mouse":
			var mouse_event := InputEventMouseButton.new()
			mouse_event.button_index = int(data.get("button_index", 0))
			return mouse_event
		"joypad":
			var joypad_event := InputEventJoypadButton.new()
			joypad_event.button_index = int(data.get("button_index", -1))
			return joypad_event
	return null


func _event_text(event: InputEvent) -> String:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		var code: Key = key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
		return OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		return "LMB" if event.button_index == MOUSE_BUTTON_LEFT else "MOUSE %d" % event.button_index
	if event is InputEventJoypadButton:
		return _joypad_button_text((event as InputEventJoypadButton).button_index)
	return "UNBOUND"


func _joypad_button_text(button_index: JoyButton) -> String:
	match button_index:
		JOY_BUTTON_A:
			return "A"
		JOY_BUTTON_B:
			return "B"
		JOY_BUTTON_X:
			return "X"
		JOY_BUTTON_Y:
			return "Y"
		JOY_BUTTON_BACK:
			return "BACK"
		JOY_BUTTON_START:
			return "START"
		JOY_BUTTON_LEFT_SHOULDER:
			return "LB"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "RB"
		_:
			return "BUTTON %d" % button_index
