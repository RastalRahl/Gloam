extends RefCounted
class_name GloamUIInputContract

## Runtime input contract for the UI CanvasLayer.
##
## Godot's mouse filter is per Control, so an ignored HUD panel does not make
## its default-filtered Label/Container descendants passive.  This contract
## deliberately starts every descendant as passive, then opts in only the
## controls that are allowed to receive mouse input.

const PASSIVE := Control.MOUSE_FILTER_IGNORE
const ACTIVE := Control.MOUSE_FILTER_STOP

var ui_root: Node


func configure(root: Node) -> void:
	ui_root = root
	apply()


func apply() -> void:
	if not is_instance_valid(ui_root):
		return
	_set_z_order()
	_apply_passive_defaults(ui_root)
	_refresh_modal_filters()


func refresh() -> void:
	## Call after a modal or dynamically-created menu changes visibility.
	if not is_instance_valid(ui_root):
		return
	_apply_passive_defaults(ui_root)
	_refresh_modal_filters()


func _apply_passive_defaults(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Control:
			var control := child as Control
			control.mouse_filter = PASSIVE
			if control.is_visible_in_tree() and (control is BaseButton or control is HSlider or control is VSlider):
				control.mouse_filter = ACTIVE
		_apply_passive_defaults(child)


func _refresh_modal_filters() -> void:
	# These controls are intentional blockers only while they are actually open.
	_set_filter("ModalDimmer", is_visible("ModalDimmer"))
	for path: String in ["WeaponPanel", "LevelUpPanel", "GameOverPanel", "VictoryPanel", "TitleMenu/TitlePanel", "TitleMenu/NewRunConfirmation", "TitleMenu/CreditsPanel"]:
		_set_filter(path, is_visible(path))

	# Dynamic UI roots remain passive full-screen shells. Their specific panel or
	# backdrop is the blocker, never the shell itself.
	var contextual := ui_root.get_node_or_null("ContextualInteractionMenu")
	if is_instance_valid(contextual):
		_set_filter("ContextualInteractionMenu/InteractionPrompt", is_visible("ContextualInteractionMenu/InteractionPrompt"))
		_set_filter("ContextualInteractionMenu/InteractionChoices", is_visible("ContextualInteractionMenu/InteractionChoices"))

	var pause := ui_root.get_node_or_null("PauseMenu")
	if is_instance_valid(pause):
		_set_filter("PauseMenu/PauseBackdrop", is_visible("PauseMenu/PauseBackdrop"))
		_set_filter("PauseMenu/PausePanel", is_visible("PauseMenu/PausePanel"))
		_set_filter("PauseMenu/PauseConfirmation", is_visible("PauseMenu/PauseConfirmation"))

	var settings := ui_root.get_node_or_null("AudioSettingsMenu")
	if is_instance_valid(settings):
		_set_filter("AudioSettingsMenu/AudioSettingsButton", is_visible("AudioSettingsMenu/AudioSettingsButton"))
		_set_filter("AudioSettingsMenu/AudioSettingsBackdrop", is_visible("AudioSettingsMenu/AudioSettingsBackdrop"))
		_set_filter("AudioSettingsMenu/AudioSettingsPanel", is_visible("AudioSettingsMenu/AudioSettingsPanel"))


func _set_filter(path: String, enabled: bool) -> void:
	var control := ui_root.get_node_or_null(path) as Control
	if is_instance_valid(control):
		control.mouse_filter = ACTIVE if enabled else PASSIVE


func is_visible(path: String) -> bool:
	var control := ui_root.get_node_or_null(path) as Control
	return is_instance_valid(control) and control.is_visible_in_tree()


func _set_z_order() -> void:
	# The CanvasLayer is above the world; these control z bands make the order
	# independent of scene child insertion order.
	if ui_root is CanvasLayer:
		(ui_root as CanvasLayer).layer = 10
	for child: Node in ui_root.get_children():
		if child is Control:
			(child as Control).z_index = 0
	_set_z("ContextualInteractionMenu", 20)
	_set_z("NightThreatOverlay", 25)
	_set_z("PauseMenu", 40)
	_set_z("AudioSettingsMenu", 110)
	_set_z("TitleMenu", 45)
	_set_z("ModalDimmer", 80)
	for path: String in ["WeaponPanel", "LevelUpPanel", "GameOverPanel", "VictoryPanel"]:
		_set_z(path, 90)


func _set_z(path: String, value: int) -> void:
	var item := ui_root.get_node_or_null(path) as Control
	if is_instance_valid(item):
		item.z_index = value
