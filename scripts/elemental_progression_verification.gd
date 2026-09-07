extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const ELEMENTAL_PROGRESSION := preload("res://scripts/elemental_progression.gd")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var empty_levels: Dictionary = {"fire": 0, "water": 0, "earth": 0, "air": 0}

	for weapon_type: String in ["sword", "spear", "bow"]:
		var initial_choices: Array[Dictionary] = ELEMENTAL_PROGRESSION.get_available_upgrades(empty_levels, weapon_type)
		_check(initial_choices.size() >= 3, "%s has at least three valid first-tier choices" % weapon_type)
		for choice: Dictionary in initial_choices:
			var upgrade_id: String = str(choice.get("id", ""))
			var description: String = ELEMENTAL_PROGRESSION.describe_upgrade(upgrade_id, weapon_type, empty_levels)
			_check(not ELEMENTAL_PROGRESSION.get_definition(upgrade_id).is_empty(), "%s choice is defined for %s" % [upgrade_id, weapon_type])
			_check(description.contains("Tier") and not description.contains("No effect"), "%s choice has a concrete description" % upgrade_id)

	_check(
		_not_available("fire_lingering", empty_levels),
		"Fire tier 2 is hidden until Kindling is enabled"
	)
	_check(
		ELEMENTAL_PROGRESSION.is_upgrade_available("fire_lingering", {"fire": 1}),
		"Fire tier 2 unlocks after Kindling"
	)
	_check(
		_not_available("fire_inferno", {"fire": 1}),
		"Fire mastery is hidden until the spreading tier is enabled"
	)
	_check(
		ELEMENTAL_PROGRESSION.is_upgrade_available("fire_inferno", {"fire": 2}),
		"Fire mastery unlocks after the spreading tier"
	)

	var fire_profile: Dictionary = ELEMENTAL_PROGRESSION.get_combat_profile({"fire": 2}, "bow")
	var water_profile: Dictionary = ELEMENTAL_PROGRESSION.get_combat_profile({"water": 2}, "bow")
	_check(fire_profile["burn_damage"] > 0 and fire_profile["burn_ticks"] > 0, "Fire provides damage over time")
	_check(fire_profile["fire_spread_radius"] > 0.0, "Fire tier 2 provides spreading pressure")
	_check(water_profile["slow_strength"] > 0.0 and water_profile["slow_duration"] > 0.0, "Water provides measurable control")
	_check(fire_profile["burn_damage"] != water_profile["slow_strength"], "Fire and Water profiles are observably different")
	_check(
		ELEMENTAL_PROGRESSION.describe_upgrade("fire_kindling", "bow", empty_levels).contains("1 damage/tick for 2 ticks"),
		"Fire description reports runtime tick values"
	)
	_check(
		ELEMENTAL_PROGRESSION.describe_upgrade("water_drench", "bow", empty_levels).contains("+0.25s slow duration"),
		"Bow Water description reports its numeric duration interaction"
	)
	_check(
		ELEMENTAL_PROGRESSION.describe_upgrade("earth_fortify", "bow", {"earth": 2}).contains("max -15%"),
		"Earth defense description reports its runtime cap"
	)

	var water_earth_profile: Dictionary = ELEMENTAL_PROGRESSION.get_combat_profile({"water": 1, "earth": 1}, "sword")
	_check(water_earth_profile["stagger_duration"] > 0.25, "Water plus Earth activates the limited Mudlock synergy")
	var fire_air_profile: Dictionary = ELEMENTAL_PROGRESSION.get_combat_profile({"fire": 2, "air": 1}, "bow")
	_check(fire_air_profile["fire_spread_radius"] > fire_profile["fire_spread_radius"], "Fire plus Air activates the limited Updraft synergy")

	var sword_fire: Dictionary = ELEMENTAL_PROGRESSION.get_combat_profile({"fire": 1}, "sword")
	var spear_fire: Dictionary = ELEMENTAL_PROGRESSION.get_combat_profile({"fire": 1}, "spear")
	var bow_fire: Dictionary = ELEMENTAL_PROGRESSION.get_combat_profile({"fire": 1}, "bow")
	_check(sword_fire["burn_ticks"] > bow_fire["burn_ticks"], "Sword has a Fire-specific cleave interaction")
	_check(spear_fire["burn_damage"] > bow_fire["burn_damage"], "Spear has a Fire-specific reach interaction")

	var sword_water: Dictionary = ELEMENTAL_PROGRESSION.get_combat_profile({"water": 1}, "sword")
	var spear_water: Dictionary = ELEMENTAL_PROGRESSION.get_combat_profile({"water": 1}, "spear")
	var bow_water: Dictionary = ELEMENTAL_PROGRESSION.get_combat_profile({"water": 1}, "bow")
	_check(sword_water["slow_strength"] > bow_water["slow_strength"], "Sword has a Water-specific cleave interaction")
	_check(spear_water["slow_duration"] > bow_water["slow_duration"], "Spear has a Water-specific reach interaction")

	var sword_earth: Dictionary = ELEMENTAL_PROGRESSION.get_combat_profile({"earth": 1}, "sword")
	var spear_earth: Dictionary = ELEMENTAL_PROGRESSION.get_combat_profile({"earth": 1}, "spear")
	_check(sword_earth["knockback_multiplier"] > 1.0, "Sword has an Earth-specific force interaction")
	_check(spear_earth["knockback_multiplier"] > sword_earth["knockback_multiplier"], "Spear has an Earth-specific reach interaction")

	var bow_air: Dictionary = ELEMENTAL_PROGRESSION.get_combat_profile({"air": 1}, "bow")
	var spear_air: Dictionary = ELEMENTAL_PROGRESSION.get_combat_profile({"air": 1}, "spear")
	var sword_air: Dictionary = ELEMENTAL_PROGRESSION.get_combat_profile({"air": 1}, "sword")
	_check(bow_air["projectile_speed_multiplier"] > 1.0, "Bow has an Air-specific projectile interaction")
	_check(spear_air["attack_cooldown_multiplier"] < 1.0, "Spear has an Air-specific cadence interaction")
	_check(sword_air["move_speed_multiplier"] > 1.0, "Sword has an Air-specific mobility interaction")

	var mastery_choices: Array[Dictionary] = ELEMENTAL_PROGRESSION.get_available_upgrades(
		{"fire": 2, "water": 2, "earth": 2, "air": 2},
		"bow"
	)
	_check(mastery_choices.size() >= 3, "completed branches still produce valid repeatable choices")
	_check(
		mastery_choices.all(func(choice: Dictionary) -> bool: return bool(choice.get("repeatable", false))),
		"completed branches expose only repeatable mastery choices"
	)

	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 24680
	rng_b.seed = 24680
	_check(
		ELEMENTAL_PROGRESSION.roll_choices(empty_levels, "bow", rng_a) == ELEMENTAL_PROGRESSION.roll_choices(empty_levels, "bow", rng_b),
		"seeded upgrade rolls are reproducible"
	)

	var main: Node2D = MAIN_SCENE.instantiate() as Node2D
	main.upgrade_debug_seed = 13579
	root.add_child(main)
	current_scene = main
	await process_frame
	paused = false
	main._choose_starting_weapon("bow")
	_check(not main.player.apply_upgrade("fire_lingering"), "player rejects a prerequisite-locked upgrade")
	_check(main.player.apply_upgrade("fire_kindling"), "player accepts a valid first-tier upgrade")
	_check(main.player.apply_upgrade("fire_lingering"), "player accepts the newly unlocked spreading tier")
	_check(main.player.fire_spread_radius > 0.0, "player combat profile exposes Fire spreading values")

	var first_main_roll: Array[String] = []
	main.upgrade_rng.seed = 13579
	main._roll_upgrade_choices()
	first_main_roll = main.current_upgrade_choices.duplicate()
	main.upgrade_rng.seed = 13579
	main._roll_upgrade_choices()
	_check(main.current_upgrade_choices == first_main_roll, "main controller uses the reproducible debug seed")
	_check(main.current_upgrade_choices.size() == 3, "main controller never opens an empty upgrade choice")
	var upgrade_buttons: Array[Button] = [
		main.upgrade_button_1,
		main.upgrade_button_2,
		main.upgrade_button_3,
	]
	for index in range(main.current_upgrade_choices.size()):
		var upgrade_id: String = main.current_upgrade_choices[index]
		var definition: Dictionary = ELEMENTAL_PROGRESSION.get_definition(upgrade_id)
		var description: String = ELEMENTAL_PROGRESSION.describe_upgrade(
			upgrade_id,
			main.player.weapon_type,
			main.player.get_elemental_levels()
		)
		var expected_button_text: String = "%s • %s\n%s" % [
			definition.get("element", "ELEMENT"),
			definition.get("name", "Upgrade"),
			description,
		]
		_check(
			upgrade_buttons[index].text == expected_button_text
				and upgrade_buttons[index].tooltip_text == description,
			"level-up UI matches the authoritative upgrade description for %s" % upgrade_id
		)

	var enemy_a: GloamEnemy = ENEMY_SCENE.instantiate() as GloamEnemy
	var enemy_b: GloamEnemy = ENEMY_SCENE.instantiate() as GloamEnemy
	enemy_a.global_position = Vector2(900.0, 500.0)
	enemy_b.global_position = Vector2(950.0, 500.0)
	main.get_node("Enemies").add_child(enemy_a)
	main.get_node("Enemies").add_child(enemy_b)
	await process_frame
	main.player._apply_fire_spread(enemy_a)
	_check(enemy_b.burn_ticks_left > 0, "Fire spread applies a burn to a nearby enemy")

	main.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("Elemental progression verification: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _not_available(upgrade_id: String, levels: Dictionary) -> bool:
	return not ELEMENTAL_PROGRESSION.is_upgrade_available(upgrade_id, levels)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		print("FAIL: %s" % description)
