extends SceneTree

const NIGHT_WAVE_SCHEDULE := preload("res://scripts/night_wave_schedule.gd")

const TARGET_TOTALS: Array[int] = [18, 28, 38, 50, 62, 76, 90, 106, 124, 140]
const TARGET_WAVES: Array[int] = [3, 4, 4, 5, 5, 6, 6, 7, 7, 8]

var failures: int = 0


func _init() -> void:
	print("GLOAM TEN-NIGHT WAVE VERIFICATION")
	for night: int in range(1, 11):
		var plan: Array[Dictionary] = NIGHT_WAVE_SCHEDULE.for_night(night, 15.0)
		_check(plan.size() == TARGET_WAVES[night - 1], "Night %d has %d readable waves" % [night, TARGET_WAVES[night - 1]])
		_check(NIGHT_WAVE_SCHEDULE.ordinary_total(night) == TARGET_TOTALS[night - 1], "Night %d has %d ordinary enemies" % [night, TARGET_TOTALS[night - 1]])
		_check((str(plan.back().get("lane", "")) == "boss") == (night == 10), "Night %d boss placement is correct" % night)
		_check(_all_waves_are_valid(plan), "Night %d waves have valid lanes, families, pacing, and counts" % night)
		_check(_split_pressure_grows(plan, night), "Night %d split-lane pressure matches its progression tier" % night)
		print("Night %d: waves=%d ordinary=%d cap=%d spawn-script=%.2fs" % [night, plan.size(), NIGHT_WAVE_SCHEDULE.ordinary_total(night), NIGHT_WAVE_SCHEDULE.active_enemy_cap(night), NIGHT_WAVE_SCHEDULE.duration(plan)])

	_check(NIGHT_WAVE_SCHEDULE.ACTIVE_ENEMY_CAPS == [20, 20, 20, 30, 30, 30, 40, 40, 48, 48], "active caps scale from 20 early to 48 late")
	_check(NIGHT_WAVE_SCHEDULE.for_night(10, 15.0).back().get("pre_spawn_delay") == 15.0, "final boss keeps its explicit telegraph delay")
	print("Night-wave verification: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _all_waves_are_valid(plan: Array[Dictionary]) -> bool:
	for wave: Dictionary in plan:
		if str(wave.get("lane", "")) not in ["north", "east", "split", "boss"]:
			return false
		if int(wave.get("count", 0)) <= 0 or float(wave.get("gap", -1.0)) < 0.0:
			return false
		if (wave.get("families", []) as Array).is_empty():
			return false
		if NIGHT_WAVE_SCHEDULE.pre_spawn_delay(wave) < 3.0 and str(wave.get("lane", "")) != "boss":
			return false
	return true


func _split_pressure_grows(plan: Array[Dictionary], night: int) -> bool:
	var split_count: int = 0
	for wave: Dictionary in plan:
		if str(wave.get("lane", "")) == "split":
			split_count += 1
	return split_count >= (1 if night <= 3 else 2)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		print("FAIL: %s" % description)
