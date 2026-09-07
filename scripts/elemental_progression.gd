extends RefCounted
class_name GloamElementalProgression

## Elemental progression data and derived combat rules live here so balancing
## does not require editing the main scene controller.

const ELEMENTS: Array[String] = ["fire", "water", "earth", "air"]
const CHOICE_COUNT: int = 3

const FIRE_KINDLING_DAMAGE: int = 1
const FIRE_KINDLING_TICKS: int = 2
const FIRE_LINGERING_TICKS: int = 1
const FIRE_SPREAD_RADIUS: float = 96.0
const FIRE_SPREAD_DAMAGE: int = 1
const FIRE_SPREAD_TICKS: int = 1
const FIRE_INFERNO_DAMAGE: int = 1
const FIRE_INFERNO_RADIUS: float = 16.0

const WATER_DRENCH_STRENGTH: float = 0.15
const WATER_DRENCH_DURATION: float = 1.5
const WATER_DEEP_STRENGTH: float = 0.10
const WATER_DEEP_DURATION: float = 1.0
const WATER_TORRENT_STRENGTH: float = 0.05
const WATER_TORRENT_DURATION: float = 0.25

const EARTH_FORCE_KNOCKBACK: float = 42.0
const EARTH_FORCE_STAGGER: float = 0.25
const EARTH_WEIGHT_DAMAGE: int = 1
const EARTH_WEIGHT_STAGGER: float = 0.15
const EARTH_FORTIFY_KNOCKBACK: float = 15.0
const EARTH_FORTIFY_STAGGER: float = 0.05
const EARTH_FORTIFY_DAMAGE_REDUCTION: float = 0.03
const EARTH_WATER_STAGGER: float = 0.15

const AIR_TAILWIND_MOVE: float = 1.10
const AIR_TAILWIND_SPEAR_COOLDOWN: float = 0.88
const AIR_TAILWIND_BOW_PROJECTILE_SPEED: float = 1.22
const AIR_QUICKENING_COOLDOWN: float = 0.84
const AIR_GALE_COOLDOWN: float = 0.92
const AIR_GALE_MOVE: float = 1.05
const AIR_GALE_BOW_PROJECTILE_SPEED: float = 1.08

const UPGRADE_DEFINITIONS: Array[Dictionary] = [
	{
		"id": "fire_kindling",
		"element": "FIRE",
		"tier": 1,
		"name": "Kindling",
		"prerequisites": [],
		"repeatable": false,
	},
	{
		"id": "fire_lingering",
		"element": "FIRE",
		"tier": 2,
		"name": "Lingering Flame",
		"prerequisites": ["fire_kindling"],
		"repeatable": false,
	},
	{
		"id": "fire_inferno",
		"element": "FIRE",
		"tier": 3,
		"name": "Inferno Mastery",
		"prerequisites": ["fire_lingering"],
		"repeatable": true,
	},
	{
		"id": "water_drench",
		"element": "WATER",
		"tier": 1,
		"name": "Drench",
		"prerequisites": [],
		"repeatable": false,
	},
	{
		"id": "water_deep_current",
		"element": "WATER",
		"tier": 2,
		"name": "Deep Current",
		"prerequisites": ["water_drench"],
		"repeatable": false,
	},
	{
		"id": "water_torrent",
		"element": "WATER",
		"tier": 3,
		"name": "Torrent Mastery",
		"prerequisites": ["water_deep_current"],
		"repeatable": true,
	},
	{
		"id": "earth_force",
		"element": "EARTH",
		"tier": 1,
		"name": "Stone Force",
		"prerequisites": [],
		"repeatable": false,
	},
	{
		"id": "earth_weight",
		"element": "EARTH",
		"tier": 2,
		"name": "Heavy Core",
		"prerequisites": ["earth_force"],
		"repeatable": false,
	},
	{
		"id": "earth_fortify",
		"element": "EARTH",
		"tier": 3,
		"name": "Fortify Mastery",
		"prerequisites": ["earth_weight"],
		"repeatable": true,
	},
	{
		"id": "air_tailwind",
		"element": "AIR",
		"tier": 1,
		"name": "Tailwind",
		"prerequisites": [],
		"repeatable": false,
	},
	{
		"id": "air_quickening",
		"element": "AIR",
		"tier": 2,
		"name": "Quickening",
		"prerequisites": ["air_tailwind"],
		"repeatable": false,
	},
	{
		"id": "air_gale",
		"element": "AIR",
		"tier": 3,
		"name": "Gale Mastery",
		"prerequisites": ["air_quickening"],
		"repeatable": true,
	},
]


static func get_all_definitions() -> Array[Dictionary]:
	return UPGRADE_DEFINITIONS.duplicate(true)


static func get_definition(upgrade_id: String) -> Dictionary:
	for definition: Dictionary in UPGRADE_DEFINITIONS:
		if str(definition.get("id", "")) == upgrade_id:
			return definition.duplicate(true)
	return {}


static func get_available_upgrades(levels: Dictionary, weapon_type: String) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for definition: Dictionary in UPGRADE_DEFINITIONS:
		if _is_available(definition, levels):
			available.append(definition.duplicate(true))

	# A valid build always has the four mastery choices after its tier-two
	# branches are complete. Keep this fallback defensive for debug-created
	# states that skip a prerequisite level.
	if available.is_empty():
		for definition: Dictionary in UPGRADE_DEFINITIONS:
			if bool(definition.get("repeatable", false)):
				available.append(definition.duplicate(true))

	return available


static func roll_choices(
	levels: Dictionary,
	weapon_type: String,
	rng: RandomNumberGenerator,
	count: int = CHOICE_COUNT
) -> Array[String]:
	var available: Array[Dictionary] = get_available_upgrades(levels, weapon_type)
	var ids: Array[String] = []
	for definition: Dictionary in available:
		ids.append(str(definition.get("id", "")))

	var safe_count: int = mini(count, ids.size())
	for index in range(ids.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index) if is_instance_valid(rng) else randi_range(0, index)
		var value: String = ids[index]
		ids[index] = ids[swap_index]
		ids[swap_index] = value

	var choices: Array[String] = []
	for index in range(safe_count):
		choices.append(ids[index])
	return choices


static func is_upgrade_available(upgrade_id: String, levels: Dictionary) -> bool:
	var definition: Dictionary = get_definition(upgrade_id)
	return not definition.is_empty() and _is_available(definition, levels)


static func describe_upgrade(upgrade_id: String, weapon_type: String, levels: Dictionary = {}) -> String:
	var definition: Dictionary = get_definition(upgrade_id)
	if definition.is_empty():
		return "Unavailable upgrade."

	var description: String = ""
	match upgrade_id:
		"fire_kindling":
			description = "Burn: %d damage/tick for %d ticks." % [FIRE_KINDLING_DAMAGE, FIRE_KINDLING_TICKS]
			match weapon_type:
				"sword": description += " Sword cleave: %d burn ticks." % (FIRE_KINDLING_TICKS + 1)
				"spear": description += " Spear reach: %d damage/tick." % (FIRE_KINDLING_DAMAGE + 1)
				_: description += " Bow arrows ignite on hit."

		"fire_lingering":
			var radius: float = FIRE_SPREAD_RADIUS + (24.0 if weapon_type == "bow" else 0.0)
			if weapon_type == "sword":
				radius += 16.0
			if _level(levels, "air") > 0:
				radius += 24.0
			description = "+%d burn tick; spreads %d damage/tick to enemies within %dpx." % [
				FIRE_LINGERING_TICKS,
				FIRE_SPREAD_DAMAGE,
				int(round(radius)),
			]
			if weapon_type == "sword":
				description += " Cleave spread radius: %dpx." % int(round(radius))
			elif weapon_type == "spear":
				description += " Long thrust carries the burn through the front line."
			if _level(levels, "air") > 0:
				description += " Updraft synergy: +24px spread radius."

		"fire_inferno":
			description = "+%d burn damage/tick and +%dpx spread radius per mastery." % [
				FIRE_INFERNO_DAMAGE,
				int(round(FIRE_INFERNO_RADIUS)),
			]
			if _level(levels, "air") > 0:
				description += " Updraft synergy: +24px spread radius."

		"water_drench":
			description = "Slow: %d%% for %0.1fs." % [int(round(WATER_DRENCH_STRENGTH * 100.0)), WATER_DRENCH_DURATION]
			match weapon_type:
				"sword": description += " Sword cleave: %d%% slow." % int(round((WATER_DRENCH_STRENGTH + 0.05) * 100.0))
				"spear": description += " Spear reach: %0.1fs slow." % (WATER_DRENCH_DURATION + 0.5)
				_: description += " Bow arrows: +%0.2fs slow duration at range." % 0.25

		"water_deep_current":
			description = "+%d%% slow strength and +%0.1fs duration." % [
				int(round(WATER_DEEP_STRENGTH * 100.0)),
				WATER_DEEP_DURATION,
			]
			if _level(levels, "earth") > 0:
				description += " Mudlock synergy: +%0.1fs stagger." % EARTH_WATER_STAGGER

		"water_torrent":
			description = "+%d%% slow strength and +%0.2fs duration per mastery." % [
				int(round(WATER_TORRENT_STRENGTH * 100.0)),
				WATER_TORRENT_DURATION,
			]

		"earth_force":
			description = "+%d knockback and %0.2fs stagger." % [int(round(EARTH_FORCE_KNOCKBACK)), EARTH_FORCE_STAGGER]
			match weapon_type:
				"sword": description += " Sword force: +20% knockback."
				"spear": description += " Spear force: +35% knockback."
				_: description += " Bow impact: +12 knockback."

		"earth_weight":
			description = "+%d damage and +%0.2fs stagger." % [EARTH_WEIGHT_DAMAGE, EARTH_WEIGHT_STAGGER]
			if _level(levels, "water") > 0:
				description += " Mudlock synergy: +%0.1fs stagger on slowed targets." % EARTH_WATER_STAGGER

		"earth_fortify":
			description = "+%d knockback, +%0.2fs stagger, and -%d%% damage taken per mastery (max -15%%)." % [
				int(round(EARTH_FORTIFY_KNOCKBACK)),
				EARTH_FORTIFY_STAGGER,
				int(round(EARTH_FORTIFY_DAMAGE_REDUCTION * 100.0)),
			]

		"air_tailwind":
			match weapon_type:
				"sword": description = "+%d%% movement speed." % int(round((AIR_TAILWIND_MOVE - 1.0) * 100.0))
				"spear": description = "%d%% faster spear thrusts (cooldown x%0.2f)." % [
					int(round((1.0 / AIR_TAILWIND_SPEAR_COOLDOWN - 1.0) * 100.0)),
					AIR_TAILWIND_SPEAR_COOLDOWN,
				]
				_: description = "+%d%% projectile speed." % int(round((AIR_TAILWIND_BOW_PROJECTILE_SPEED - 1.0) * 100.0))

		"air_quickening":
			description = "%d%% faster attacks (cooldown x%0.2f)." % [
				int(round((1.0 / AIR_QUICKENING_COOLDOWN - 1.0) * 100.0)),
				AIR_QUICKENING_COOLDOWN,
			]

		"air_gale":
			description = "%d%% shorter cooldown per mastery (cooldown x%0.2f)." % [
				int(round((1.0 / AIR_GALE_COOLDOWN - 1.0) * 100.0)),
				AIR_GALE_COOLDOWN,
			]
			if weapon_type == "sword":
				description += " Also +5% movement speed."
			elif weapon_type == "bow":
				description += " Also +8% projectile speed."

		_:
			description = "No effect defined."

	var tier: int = int(definition.get("tier", 1))
	if tier > 1:
		description = "Tier %d • Requires %s. %s" % [tier, _prerequisite_text(definition), description]
	else:
		description = "Tier 1 • %s" % description
	return description


static func get_combat_profile(levels: Dictionary, weapon_type: String) -> Dictionary:
	var fire_level: int = _level(levels, "fire")
	var water_level: int = _level(levels, "water")
	var earth_level: int = _level(levels, "earth")
	var air_level: int = _level(levels, "air")

	var profile: Dictionary = {
		"burn_damage": 0,
		"burn_ticks": 0,
		"fire_spread_radius": 0.0,
		"fire_spread_damage": 0,
		"fire_spread_ticks": 0,
		"slow_strength": 0.0,
		"slow_duration": 0.0,
		"knockback_force": 0.0,
		"stagger_duration": 0.0,
		"damage_bonus": 0,
		"damage_taken_multiplier": 1.0,
		"move_speed_multiplier": 1.0,
		"attack_cooldown_multiplier": 1.0,
		"projectile_speed_multiplier": 1.0,
		"knockback_multiplier": 1.0,
	}

	if fire_level >= 1:
		profile["burn_damage"] = FIRE_KINDLING_DAMAGE + maxi(0, fire_level - 2) * FIRE_INFERNO_DAMAGE
		profile["burn_ticks"] = FIRE_KINDLING_TICKS
	if fire_level >= 2:
		profile["burn_ticks"] += FIRE_LINGERING_TICKS
		profile["fire_spread_radius"] = FIRE_SPREAD_RADIUS + maxi(0, fire_level - 2) * FIRE_INFERNO_RADIUS
		profile["fire_spread_damage"] = FIRE_SPREAD_DAMAGE
		profile["fire_spread_ticks"] = FIRE_SPREAD_TICKS

	if weapon_type == "sword" and fire_level >= 1:
		profile["burn_ticks"] += 1
	if weapon_type == "spear" and fire_level >= 1:
		profile["burn_damage"] += 1
	if weapon_type == "sword" and fire_level >= 2:
		profile["fire_spread_radius"] += 16.0
	if weapon_type == "bow" and fire_level >= 2:
		profile["fire_spread_radius"] += 24.0

	if water_level >= 1:
		profile["slow_strength"] = WATER_DRENCH_STRENGTH
		profile["slow_duration"] = WATER_DRENCH_DURATION
	if water_level >= 2:
		profile["slow_strength"] += WATER_DEEP_STRENGTH
		profile["slow_duration"] += WATER_DEEP_DURATION
	if water_level >= 3:
		profile["slow_strength"] += maxi(0, water_level - 2) * WATER_TORRENT_STRENGTH
		profile["slow_duration"] += maxi(0, water_level - 2) * WATER_TORRENT_DURATION

	if weapon_type == "sword" and water_level >= 1:
		profile["slow_strength"] += 0.05
	if weapon_type == "spear" and water_level >= 1:
		profile["slow_duration"] += 0.50
	if weapon_type == "bow" and water_level >= 1:
		profile["slow_duration"] += 0.25

	if earth_level >= 1:
		profile["knockback_force"] = EARTH_FORCE_KNOCKBACK
		profile["stagger_duration"] = EARTH_FORCE_STAGGER
	if earth_level >= 2:
		profile["damage_bonus"] = EARTH_WEIGHT_DAMAGE
		profile["stagger_duration"] += EARTH_WEIGHT_STAGGER
	if earth_level >= 3:
		var mastery_count: int = earth_level - 2
		profile["knockback_force"] += mastery_count * EARTH_FORTIFY_KNOCKBACK
		profile["stagger_duration"] += mastery_count * EARTH_FORTIFY_STAGGER
		profile["damage_taken_multiplier"] = 1.0 - minf(0.15, mastery_count * EARTH_FORTIFY_DAMAGE_REDUCTION)

	if weapon_type == "sword" and earth_level >= 1:
		profile["knockback_multiplier"] = 1.20
	elif weapon_type == "spear" and earth_level >= 1:
		profile["knockback_multiplier"] = 1.35
	elif weapon_type == "bow" and earth_level >= 1:
		profile["knockback_force"] += 12.0

	if water_level >= 1 and earth_level >= 1:
		profile["stagger_duration"] += EARTH_WATER_STAGGER

	if air_level >= 1:
		match weapon_type:
			"sword": profile["move_speed_multiplier"] = AIR_TAILWIND_MOVE
			"spear": profile["attack_cooldown_multiplier"] = AIR_TAILWIND_SPEAR_COOLDOWN
			_: profile["projectile_speed_multiplier"] = AIR_TAILWIND_BOW_PROJECTILE_SPEED
	if air_level >= 2:
		profile["attack_cooldown_multiplier"] *= AIR_QUICKENING_COOLDOWN
	if air_level >= 3:
		var gale_count: int = air_level - 2
		profile["attack_cooldown_multiplier"] *= pow(AIR_GALE_COOLDOWN, gale_count)
		if weapon_type == "sword":
			profile["move_speed_multiplier"] *= pow(AIR_GALE_MOVE, gale_count)
		elif weapon_type == "bow":
			profile["projectile_speed_multiplier"] *= pow(AIR_GALE_BOW_PROJECTILE_SPEED, gale_count)
	profile["attack_cooldown_multiplier"] = maxf(0.55, profile["attack_cooldown_multiplier"])

	if fire_level >= 2 and air_level >= 1:
		profile["fire_spread_radius"] += 24.0

	return profile


static func _is_available(definition: Dictionary, levels: Dictionary) -> bool:
	var element: String = str(definition.get("element", "")).to_lower()
	var tier: int = int(definition.get("tier", 1))
	var current_level: int = _level(levels, element)
	if bool(definition.get("repeatable", false)):
		if current_level < tier - 1:
			return false
	else:
		if current_level != tier - 1:
			return false

	for prerequisite: String in definition.get("prerequisites", []):
		var prerequisite_definition: Dictionary = get_definition(prerequisite)
		if prerequisite_definition.is_empty():
			return false
		if _level(levels, str(prerequisite_definition.get("element", "")).to_lower()) < int(prerequisite_definition.get("tier", 1)):
			return false
	return true


static func _level(levels: Dictionary, element: String) -> int:
	return maxi(0, int(levels.get(element.to_lower(), levels.get(element.to_upper(), 0))))


static func _prerequisite_text(definition: Dictionary) -> String:
	var prerequisites: Array = definition.get("prerequisites", [])
	if prerequisites.is_empty():
		return "previous tier"
	var names: Array[String] = []
	for prerequisite: String in prerequisites:
		var prerequisite_definition: Dictionary = get_definition(prerequisite)
		names.append(str(prerequisite_definition.get("name", prerequisite)))
	return "+".join(names)
