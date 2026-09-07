extends Node
class_name GloamProgressionManager

## Owns upgrade choice generation and upgrade-card presentation.
##
## The root still owns when a level-up modal opens and when its pause state is
## released; this component owns the data-backed choices shown in that modal.

const ELEMENTAL_PROGRESSION := preload("res://scripts/elemental_progression.gd")

var player_actor: GloamPlayer
var upgrade_rng: RandomNumberGenerator
var upgrade_buttons: Array[Button] = []
var current_choices: Array[String] = []
var pending_level_ups: int = 0


func configure(
	player: GloamPlayer,
	random_source: RandomNumberGenerator,
	buttons: Array[Button]
) -> void:
	player_actor = player
	upgrade_rng = random_source
	upgrade_buttons = buttons.duplicate()


func roll_choices() -> Array[String]:
	if not is_instance_valid(player_actor) or not is_instance_valid(upgrade_rng):
		current_choices.clear()
		return current_choices
	current_choices = ELEMENTAL_PROGRESSION.roll_choices(
		player_actor.get_elemental_levels(),
		player_actor.weapon_type,
		upgrade_rng
	)
	refresh_buttons()
	return current_choices


func try_apply(index: int) -> bool:
	if not is_instance_valid(player_actor) or index < 0 or index >= current_choices.size():
		return false
	return player_actor.apply_upgrade(current_choices[index])


func queue_upgrade() -> void:
	pending_level_ups += 1


func consume_upgrade() -> bool:
	if pending_level_ups <= 0:
		return false
	pending_level_ups -= 1
	return true


func refresh_buttons() -> void:
	var levels: Dictionary = player_actor.get_elemental_levels()
	for index: int in range(upgrade_buttons.size()):
		var button: Button = upgrade_buttons[index]
		var has_choice: bool = index < current_choices.size()
		button.visible = has_choice
		button.disabled = not has_choice
		if not has_choice:
			continue

		var upgrade_id: String = current_choices[index]
		var data: Dictionary = ELEMENTAL_PROGRESSION.get_definition(upgrade_id)
		var description: String = ELEMENTAL_PROGRESSION.describe_upgrade(
			upgrade_id,
			player_actor.weapon_type,
			levels
		)
		button.text = "%s • %s\n%s" % [
			data.get("element", "ELEMENT"),
			data.get("name", "Upgrade"),
			description
		]
		button.tooltip_text = description
