extends SceneTree

const NIGHT_WAVE_SCHEDULE := preload("res://scripts/night_wave_schedule.gd")
const RUNNER_SCENE := preload("res://scenes/enemy_runner.tscn")
const BRUTE_SCENE := preload("res://scenes/enemy_brute.tscn")
const RANGED_SCENE := preload("res://scenes/enemy_ranged.tscn")

const TARGET_TOTALS: Array[int] = [18, 28, 38, 42, 45, 48, 54, 56, 62, 72]
const TARGET_WAVES: Array[int] = [3, 4, 4, 5, 5, 6, 6, 7, 7, 8]
const ALLOWED_FAMILIES: Array[String] = ["grunt", "runner", "brute", "ranged", "boss"]
const ALLOWED_BEHAVIORS: Array[String] = ["", "bulwark", "charger", "deadeye"]

var failures: int = 0


func _init() -> void:
	print("GLOAM TEN-NIGHT ENCOUNTER VERIFICATION")
	for night: int in range(1, 11):
		var plan: Array[Dictionary] = NIGHT_WAVE_SCHEDULE.for_night(night, 15.0)
		_check(plan.size() == TARGET_WAVES[night - 1], "Night %d has %d readable waves" % [night, TARGET_WAVES[night - 1]])
		_check(NIGHT_WAVE_SCHEDULE.ordinary_total(night) == TARGET_TOTALS[night - 1], "Night %d has %d ordinary enemies" % [night, TARGET_TOTALS[night - 1]])
		_check((str(plan.back().get("lane", "")) == "boss") == (night == 10), "Night %d boss placement is correct" % night)
		_check(_all_waves_are_valid(plan), "Night %d waves have valid families, telegraphs, pacing, and deterministic entries" % night)
		print("Night %d: waves=%d ordinary=%d cap=%d spawn-script=%.2fs modifiers=%s" % [night, plan.size(), NIGHT_WAVE_SCHEDULE.ordinary_total(night), NIGHT_WAVE_SCHEDULE.active_enemy_cap(night), NIGHT_WAVE_SCHEDULE.duration(plan), str(_modifier_ids(plan))])

	_check(_modifier_ids(NIGHT_WAVE_SCHEDULE.for_night(1, 15.0)) == ["standard"], "Night 1 begins without elite rules")
	_check(_modifier_ids(NIGHT_WAVE_SCHEDULE.for_night(2, 15.0)) == ["standard"], "Night 2 remains a family-composition lesson")
	_check(_modifier_ids(NIGHT_WAVE_SCHEDULE.for_night(3, 15.0)) == ["standard"], "Night 3 introduces all ordinary families before elites")
	_check(_modifier_ids(NIGHT_WAVE_SCHEDULE.for_night(4, 15.0)) == ["standard", "armored_vanguard"], "Night 4 introduces only armored vanguards")
	_check(_modifier_ids(NIGHT_WAVE_SCHEDULE.for_night(5, 15.0)) == ["standard", "hunting_pack"], "Night 5 introduces only hunting packs")
	_check(_modifier_ids(NIGHT_WAVE_SCHEDULE.for_night(6, 15.0)) == ["armored_vanguard", "hunting_pack", "standard"], "Night 6 alternates learned rules without combining them")
	_check(_modifier_ids(NIGHT_WAVE_SCHEDULE.for_night(7, 15.0)) == ["standard", "screened_volley"], "Night 7 introduces only screened volleys")
	_check(not _modifier_ids(NIGHT_WAVE_SCHEDULE.for_night(8, 15.0)).has("combined_arms"), "Night 8 rehearses known rules in separate waves")
	_check(_modifier_ids(NIGHT_WAVE_SCHEDULE.for_night(9, 15.0)).has("combined_arms"), "Night 9 explicitly introduces combined arms")
	_check(_has_standard_recovery_waves(4) and _has_standard_recovery_waves(9), "Nights 4-9 retain standard recovery waves")
	_check(_pressure_waves_have_breathing_room(), "every elite or burst wave before the boss grants at least 7 seconds of breathing room")
	_check(_elite_packages_preserve_build_answers(), "elite packages contain no immunity, resistance, targeting, or range override")
	_check(_expected_spawn_examples(), "elite placement and family order are deterministic")
	_check(_runtime_profiles_apply(), "schedule-authored elite multipliers apply to the existing enemy families")
	_check(NIGHT_WAVE_SCHEDULE.ACTIVE_ENEMY_CAPS == [20, 20, 20, 24, 24, 26, 28, 30, 32, 36], "active caps grow gradually and stay bounded")
	_check(NIGHT_WAVE_SCHEDULE.for_night(10, 15.0).back().get("pre_spawn_delay") == 15.0, "final boss keeps its explicit telegraph delay")
	print("Night-wave verification: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _all_waves_are_valid(plan: Array[Dictionary]) -> bool:
	for wave: Dictionary in plan:
		if str(wave.get("lane", "")) not in ["north", "east", "split", "boss"]:
			return false
		if int(wave.get("count", 0)) <= 0:
			return false
		if (wave.get("families", []) as Array).is_empty() or str(wave.get("warning", "")).is_empty():
			return false
		if NIGHT_WAVE_SCHEDULE.pre_spawn_delay(wave) < 3.8 and str(wave.get("lane", "")) != "boss":
			return false
		for spawn_index: int in range(int(wave["count"])):
			var first: Dictionary = NIGHT_WAVE_SCHEDULE.spawn_entry(wave, spawn_index)
			var second: Dictionary = NIGHT_WAVE_SCHEDULE.spawn_entry(wave, spawn_index)
			if first != second or str(first["family"]) not in ALLOWED_FAMILIES:
				return false
			if str((first["behavior"] as Dictionary).get("id", "")) not in ALLOWED_BEHAVIORS:
				return false
	return true


func _modifier_ids(plan: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for wave: Dictionary in plan:
		var modifier_id: String = str(wave.get("modifier", "standard"))
		if modifier_id == "boss" or result.has(modifier_id):
			continue
		result.append(modifier_id)
	return result


func _has_standard_recovery_waves(night: int) -> bool:
	for wave: Dictionary in NIGHT_WAVE_SCHEDULE.for_night(night, 15.0):
		if str(wave.get("modifier", "")) == "standard":
			return true
	return false


func _pressure_waves_have_breathing_room() -> bool:
	for night: int in range(4, 11):
		for wave: Dictionary in NIGHT_WAVE_SCHEDULE.for_night(night, 15.0):
			if str(wave.get("modifier", "standard")) not in ["standard", "boss"] and NIGHT_WAVE_SCHEDULE.breathing_delay(wave) < 7.0:
				return false
	return true


func _elite_packages_preserve_build_answers() -> bool:
	var forbidden_keys: Array[String] = ["immunity", "resistance", "target_priority", "attack_range", "slow_immunity", "stagger_immunity"]
	for behavior: Dictionary in NIGHT_WAVE_SCHEDULE.ELITE_BEHAVIORS.values():
		for key: String in forbidden_keys:
			if behavior.has(key):
				return false
	return true


func _expected_spawn_examples() -> bool:
	var n4: Dictionary = NIGHT_WAVE_SCHEDULE.for_night(4, 15.0)[1]
	var n5: Dictionary = NIGHT_WAVE_SCHEDULE.for_night(5, 15.0)[1]
	var n7: Dictionary = NIGHT_WAVE_SCHEDULE.for_night(7, 15.0)[1]
	return (
		str(NIGHT_WAVE_SCHEDULE.spawn_entry(n4, 0)["family"]) == "brute"
		and str((NIGHT_WAVE_SCHEDULE.spawn_entry(n4, 0)["behavior"] as Dictionary).get("id", "")) == "bulwark"
		and str((NIGHT_WAVE_SCHEDULE.spawn_entry(n4, 1)["behavior"] as Dictionary).get("id", "")) == ""
		and str((NIGHT_WAVE_SCHEDULE.spawn_entry(n5, 0)["behavior"] as Dictionary).get("id", "")) == "charger"
		and is_equal_approx(NIGHT_WAVE_SCHEDULE.spawn_gap(n5, 0), 0.18)
		and is_equal_approx(NIGHT_WAVE_SCHEDULE.spawn_gap(n5, 2), 1.05)
		and str((NIGHT_WAVE_SCHEDULE.spawn_entry(n7, 1)["behavior"] as Dictionary).get("id", "")) == "deadeye"
	)


func _runtime_profiles_apply() -> bool:
	var bulwark: GloamEnemy = BRUTE_SCENE.instantiate() as GloamEnemy
	var charger: GloamEnemy = RUNNER_SCENE.instantiate() as GloamEnemy
	var deadeye: GloamEnemy = RANGED_SCENE.instantiate() as GloamEnemy
	bulwark.apply_encounter_behavior(NIGHT_WAVE_SCHEDULE.ELITE_BEHAVIORS["bulwark"])
	charger.apply_encounter_behavior(NIGHT_WAVE_SCHEDULE.ELITE_BEHAVIORS["charger"])
	deadeye.apply_encounter_behavior(NIGHT_WAVE_SCHEDULE.ELITE_BEHAVIORS["deadeye"])
	root.add_child(bulwark)
	root.add_child(charger)
	root.add_child(deadeye)
	bulwark._setup_elite_marker()
	charger._setup_elite_marker()
	deadeye._setup_elite_marker()
	bulwark.set_night_readability(true)
	charger.set_night_readability(true)
	deadeye.set_night_readability(true)
	var valid: bool = (
		bulwark.max_hp == 15 and bulwark.move_speed < 48.0
		and charger.max_hp == 1 and charger.move_speed > 145.0
		and deadeye.max_hp == 3 and deadeye.attack_damage == 10
		and str(bulwark.get_meta("encounter_behavior", "")) == "bulwark"
		and str(charger.get_meta("encounter_behavior", "")) == "charger"
		and str(deadeye.get_meta("encounter_behavior", "")) == "deadeye"
		and bulwark.has_node("EliteMarker") and bulwark.get_node("EliteMarker").visible
		and charger.has_node("EliteMarker") and charger.get_node("EliteMarker").visible
		and deadeye.has_node("EliteMarker") and deadeye.get_node("EliteMarker").visible
	)
	if not valid:
		print("Elite runtime diagnostics: bulwark=%d/%.2f charger=%d/%.2f deadeye=%d/%d markers=%s/%s/%s" % [bulwark.max_hp, bulwark.move_speed, charger.max_hp, charger.move_speed, deadeye.max_hp, deadeye.attack_damage, bulwark.has_node("EliteMarker"), charger.has_node("EliteMarker"), deadeye.has_node("EliteMarker")])
	bulwark.free()
	charger.free()
	deadeye.free()
	return valid


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		print("FAIL: %s" % description)
