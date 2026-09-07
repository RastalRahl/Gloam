extends RefCounted
class_name GloamInputActions

const MOVE_UP: StringName = &"move_up"
const MOVE_DOWN: StringName = &"move_down"
const MOVE_LEFT: StringName = &"move_left"
const MOVE_RIGHT: StringName = &"move_right"
const AIM_UP: StringName = &"aim_up"
const AIM_DOWN: StringName = &"aim_down"
const AIM_LEFT: StringName = &"aim_left"
const AIM_RIGHT: StringName = &"aim_right"
const ATTACK: StringName = &"attack"
const INTERACT: StringName = &"interact"
const REPAIR: StringName = &"repair"
const UPGRADE: StringName = &"upgrade"
const LEVEL_UP: StringName = &"level_up"
const VILLAGE_MANAGEMENT: StringName = &"village_management"
const MENU_UP: StringName = &"menu_up"
const MENU_DOWN: StringName = &"menu_down"
const MENU_LEFT: StringName = &"menu_left"
const MENU_RIGHT: StringName = &"menu_right"
const MENU_ACCEPT: StringName = &"menu_accept"
const MENU_CANCEL: StringName = &"menu_cancel"
const PAUSE: StringName = &"pause"
const TOGGLE_COLLISION_DEBUG: StringName = &"toggle_collision_debug"

static var active_device: String = "keyboard"


static func observe_event(event: InputEvent) -> bool:
	var next_device: String = active_device
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		next_device = "controller"
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		next_device = "mouse"
	elif event is InputEventKey:
		next_device = "keyboard"

	if next_device == active_device:
		return false
	active_device = next_device
	return true


static func action_hint(action_name: StringName) -> String:
	if active_device == "mouse" and action_name == INTERACT:
		return "CLICK"

	var events: Array[InputEvent] = InputMap.action_get_events(action_name)
	var preferred: InputEvent = _first_event_for_device(events, active_device)
	if is_instance_valid(preferred):
		return _event_label(preferred, action_name)

	var fallback: InputEvent = _first_event_for_device(events, "keyboard")
	if is_instance_valid(fallback):
		return _event_label(fallback, action_name)

	return str(action_name).capitalize()


static func movement_hint() -> String:
	if active_device == "controller":
		return "LEFT STICK"
	return "%s%s%s%s" % [
		action_hint(MOVE_UP),
		action_hint(MOVE_LEFT),
		action_hint(MOVE_DOWN),
		action_hint(MOVE_RIGHT)
	]


static func controls_hint() -> String:
	return "%s MOVE   •   %s ATTACK   •   %s INTERACT   •   %s PAUSE" % [
		movement_hint(),
		action_hint(ATTACK),
		action_hint(INTERACT),
		action_hint(PAUSE)
	]


static func _first_event_for_device(events: Array[InputEvent], device_name: String) -> InputEvent:
	for event: InputEvent in events:
		if device_name == "keyboard" and event is InputEventKey:
			return event
		if device_name == "mouse" and event is InputEventMouseButton:
			return event
		if device_name == "controller" and (
			event is InputEventJoypadButton or event is InputEventJoypadMotion
		):
			return event
	return null


static func _event_label(event: InputEvent, action_name: StringName) -> String:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		var key_code: Key = key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
		return OS.get_keycode_string(key_code)

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		match mouse_event.button_index:
			MOUSE_BUTTON_LEFT:
				return "LMB"
			MOUSE_BUTTON_RIGHT:
				return "RMB"
			MOUSE_BUTTON_MIDDLE:
				return "MMB"
			_:
				return "MOUSE %d" % mouse_event.button_index

	if event is InputEventJoypadButton:
		return _joypad_button_label((event as InputEventJoypadButton).button_index)

	if event is InputEventJoypadMotion:
		if action_name in [AIM_UP, AIM_DOWN, AIM_LEFT, AIM_RIGHT]:
			return "RIGHT STICK"
		return "LEFT STICK"

	return str(action_name).capitalize()


static func _joypad_button_label(button_index: JoyButton) -> String:
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
		JOY_BUTTON_DPAD_UP:
			return "D-PAD UP"
		JOY_BUTTON_DPAD_DOWN:
			return "D-PAD DOWN"
		JOY_BUTTON_DPAD_LEFT:
			return "D-PAD LEFT"
		JOY_BUTTON_DPAD_RIGHT:
			return "D-PAD RIGHT"
		_:
			return "BUTTON %d" % button_index
