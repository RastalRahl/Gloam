extends RefCounted
class_name GloamUIFocus

## Centralized focus lifecycle guard for dynamically-created UI.

static var _request_generation: int = 0

static func can_request(control: Control) -> bool:
	return (
		is_instance_valid(control)
		and control.is_inside_tree()
		and control.is_visible_in_tree()
		and control.focus_mode != Control.FOCUS_NONE
		and not (control is BaseButton and (control as BaseButton).disabled)
	)


static func request(control: Control, active_ui_state: bool, deferred: bool = false) -> void:
	_request_generation += 1
	var request_generation := _request_generation
	if not active_ui_state or not can_request(control):
		return
	if deferred:
		var control_ref: WeakRef = weakref(control)
		control.get_tree().process_frame.connect(
			func() -> void:
				if _request_generation != request_generation:
					return
				var deferred_control: Control = control_ref.get_ref() as Control
				if can_request(deferred_control):
					deferred_control.grab_focus(),
			CONNECT_ONE_SHOT
		)
	else:
		control.grab_focus()
