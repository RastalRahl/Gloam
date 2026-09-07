class_name GloamNightWaveSchedule
extends RefCounted

## Ten-night assault data. Counts are ordinary enemies; Night 10 appends one
## boss wave after its 140 ordinary enemies. Runtime completion is deliberately
## not derived from these timings -- it is derived from spawn and kill state.
const DEFAULT_PRE_SPAWN_DELAY: float = 3.5
const DEFAULT_BREATHING_DELAY: float = 3.0

const ACTIVE_ENEMY_CAPS: Array[int] = [20, 20, 20, 30, 30, 30, 40, 40, 48, 48]

const NIGHT_SPECS: Array[Dictionary] = [
	{"counts": [5, 6, 7], "lanes": ["north", "east", "split"], "families": [["grunt"], ["grunt"], ["grunt", "runner"]], "gap": 0.62, "breathing": 4.2, "pre": 4.0},
	{"counts": [6, 7, 7, 8], "lanes": ["east", "north", "split", "east"], "families": [["grunt", "runner"], ["grunt"], ["grunt", "runner"], ["runner", "grunt"]], "gap": 0.56, "breathing": 4.0, "pre": 3.9},
	{"counts": [8, 9, 10, 11], "lanes": ["north", "east", "split", "north"], "families": [["grunt", "runner"], ["grunt", "ranged"], ["grunt", "runner", "ranged"], ["brute", "grunt", "runner"]], "gap": 0.51, "breathing": 3.8, "pre": 3.8},
	{"counts": [9, 9, 10, 10, 12], "lanes": ["east", "north", "split", "east", "split"], "families": [["grunt", "runner"], ["grunt", "brute"], ["grunt", "ranged"], ["runner", "ranged"], ["grunt", "brute", "runner"]], "gap": 0.47, "breathing": 3.6, "pre": 3.7},
	{"counts": [11, 12, 12, 13, 14], "lanes": ["north", "east", "split", "north", "split"], "families": [["grunt", "brute"], ["runner", "ranged"], ["grunt", "runner", "ranged"], ["brute", "grunt", "ranged"], ["grunt", "brute", "runner", "ranged"]], "gap": 0.43, "breathing": 3.4, "pre": 3.6},
	{"counts": [11, 12, 12, 13, 14, 14], "lanes": ["east", "north", "split", "east", "north", "split"], "families": [["runner", "grunt"], ["brute", "grunt"], ["ranged", "grunt", "runner"], ["runner", "ranged", "brute"], ["brute", "grunt", "ranged"], ["grunt", "runner", "brute", "ranged"]], "gap": 0.40, "breathing": 3.2, "pre": 3.5},
	{"counts": [14, 14, 15, 15, 16, 16], "lanes": ["north", "east", "split", "north", "east", "split"], "families": [["grunt", "brute", "runner"], ["runner", "ranged"], ["grunt", "runner", "ranged"], ["brute", "ranged", "grunt"], ["runner", "brute", "ranged"], ["grunt", "runner", "brute", "ranged"]], "gap": 0.37, "breathing": 3.0, "pre": 3.4},
	{"counts": [14, 15, 15, 15, 15, 16, 16], "lanes": ["east", "north", "split", "east", "north", "split", "split"], "families": [["runner", "ranged"], ["grunt", "brute"], ["grunt", "runner", "ranged"], ["brute", "ranged", "runner"], ["grunt", "brute", "ranged"], ["runner", "brute", "ranged"], ["grunt", "runner", "brute", "ranged"]], "gap": 0.34, "breathing": 2.8, "pre": 3.3},
	{"counts": [16, 17, 17, 18, 18, 19, 19], "lanes": ["north", "east", "split", "north", "east", "split", "split"], "families": [["grunt", "brute", "ranged"], ["runner", "ranged", "brute"], ["grunt", "runner", "ranged"], ["brute", "ranged", "grunt"], ["runner", "brute", "ranged"], ["grunt", "runner", "brute", "ranged"], ["runner", "ranged", "brute", "grunt"]], "gap": 0.31, "breathing": 2.6, "pre": 3.2},
	{"counts": [18, 19, 19, 20, 21, 21, 22], "lanes": ["north", "east", "split", "north", "east", "split", "split"], "families": [["grunt", "runner", "brute"], ["runner", "ranged", "brute"], ["grunt", "runner", "ranged"], ["brute", "ranged", "grunt"], ["runner", "brute", "ranged"], ["grunt", "runner", "brute", "ranged"], ["runner", "ranged", "brute", "grunt"]], "gap": 0.29, "breathing": 2.4, "pre": 3.2},
]


static func for_night(night: int, boss_spawn_delay: float) -> Array[Dictionary]:
	var night_index: int = clampi(night, 1, NIGHT_SPECS.size()) - 1
	var spec: Dictionary = NIGHT_SPECS[night_index]
	var result: Array[Dictionary] = []
	var counts: Array = spec["counts"]
	var lanes: Array = spec["lanes"]
	var family_sets: Array = spec["families"]
	for wave_index: int in range(counts.size()):
		var lane: String = str(lanes[wave_index])
		result.append({
			"lane": lane,
			"count": int(counts[wave_index]),
			"gap": float(spec["gap"]),
			"breathing_delay": float(spec["breathing"]),
			"pre_spawn_delay": float(spec["pre"]),
			"families": (family_sets[wave_index] as Array).duplicate(),
			"warning": _warning_for(lane, wave_index, counts.size()),
		})
	if night == NIGHT_SPECS.size():
		result.append({
			"lane": "boss", "count": 1, "gap": 0.0, "breathing_delay": 0.0,
			"pre_spawn_delay": maxf(0.0, boss_spawn_delay), "families": ["boss"],
			"warning": "THE TROLL CHIEFTAIN APPROACHES",
		})
	return result


static func ordinary_total(night: int) -> int:
	var total: int = 0
	for wave: Dictionary in for_night(night, 0.0):
		if str(wave.get("lane", "")) != "boss":
			total += int(wave.get("count", 0))
	return total


static func active_enemy_cap(night: int) -> int:
	return ACTIVE_ENEMY_CAPS[clampi(night, 1, ACTIVE_ENEMY_CAPS.size()) - 1]


static func pre_spawn_delay(wave: Dictionary) -> float:
	return maxf(0.0, float(wave.get("pre_spawn_delay", DEFAULT_PRE_SPAWN_DELAY)))


static func breathing_delay(wave: Dictionary) -> float:
	return maxf(0.0, float(wave.get("breathing_delay", DEFAULT_BREATHING_DELAY)))


static func duration(plan: Array[Dictionary]) -> float:
	## Spawn-script duration only; never a phase-ending countdown.
	var total: float = 0.0
	for wave_index: int in range(plan.size()):
		var wave: Dictionary = plan[wave_index]
		total += pre_spawn_delay(wave)
		var count: int = maxi(0, int(wave.get("count", 0)))
		total += float(maxi(0, count - 1)) * maxf(0.0, float(wave.get("gap", 0.0)))
		if wave_index < plan.size() - 1:
			total += breathing_delay(wave)
	return total


static func _warning_for(lane: String, wave_index: int, total_waves: int) -> String:
	var pressure: String = "FINAL PUSH" if wave_index == total_waves - 1 else "ASSAULT"
	match lane:
		"north": return "NORTH %s" % pressure
		"east": return "EAST %s" % pressure
		"split": return "BOTH GATES UNDER ATTACK"
	return "INCOMING ASSAULT"
