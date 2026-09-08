class_name GloamNightWaveSchedule
extends RefCounted

## The complete ten-night assault grammar lives here: wave composition,
## telegraphs, rest windows, burst cadence, and elite stat packages. Runtime
## completion is still derived only from required spawn and kill state.
const DEFAULT_PRE_SPAWN_DELAY: float = 3.8
const DEFAULT_BREATHING_DELAY: float = 4.5

const ACTIVE_ENEMY_CAPS: Array[int] = [20, 20, 20, 24, 24, 26, 28, 30, 32, 36]

# Elite packages deliberately contain no immunity, resistance, target-priority,
# or range changes. Every build can answer them using its existing strengths.
const ELITE_BEHAVIORS: Dictionary = {
	"bulwark": {
		"id": "bulwark", "label": "BULWARK", "hp_multiplier": 1.5,
		"speed_multiplier": 0.82, "damage_multiplier": 1.0,
		"attack_interval_multiplier": 1.0, "marker_color": Color(1.0, 0.72, 0.22, 1.0),
	},
	"charger": {
		"id": "charger", "label": "CHARGER", "hp_multiplier": 0.5,
		"speed_multiplier": 1.18, "damage_multiplier": 1.0,
		"attack_interval_multiplier": 1.0, "marker_color": Color(1.0, 0.36, 0.18, 1.0),
	},
	"deadeye": {
		"id": "deadeye", "label": "DEADEYE", "hp_multiplier": 0.75,
		"speed_multiplier": 1.0, "damage_multiplier": 1.25,
		"attack_interval_multiplier": 1.12, "marker_color": Color(0.78, 0.46, 1.0, 1.0),
	},
}

# A modifier is a readable encounter rule, not an opaque difficulty scalar.
# elite_every/offset make elite placement deterministic. gap_pattern creates
# audible/visible packs while retaining a generous pause after the wave.
const MODIFIERS: Dictionary = {
	"standard": {
		"label": "STANDARD ASSAULT", "detail": "NO ELITES",
	},
	"armored_vanguard": {
		"label": "ARMORED VANGUARD", "detail": "SLOW BULWARKS LEAD",
		"elite_every": 4, "elite_offset": 0,
		"behavior_by_family": {"grunt": "bulwark", "brute": "bulwark"},
	},
	"hunting_pack": {
		"label": "HUNTING PACK", "detail": "FRAGILE CHARGERS ARRIVE IN BURSTS",
		"elite_every": 3, "elite_offset": 0,
		"behavior_by_family": {"runner": "charger"},
		"gap_pattern": [0.18, 0.18, 1.05],
	},
	"screened_volley": {
		"label": "SCREENED VOLLEY", "detail": "FRAGILE DEADEYES BEHIND A SCREEN",
		"elite_every": 3, "elite_offset": 1,
		"behavior_by_family": {"ranged": "deadeye"},
	},
	"combined_arms": {
		"label": "COMBINED ARMS", "detail": "MARKED ELITES; NO IMMUNITIES",
		"elite_every": 3, "elite_offset": 0,
		"behavior_by_family": {"brute": "bulwark", "runner": "charger", "ranged": "deadeye"},
		"gap_pattern": [0.30, 0.30, 0.72, 0.72],
	},
}

# Nights 1-3 teach the four ordinary families. Nights 4-9 each have a distinct
# lesson and alternate pressure waves with standard recovery waves. Night 10
# is the combined-arms exam followed by the existing boss.
const NIGHT_SPECS: Array[Dictionary] = [
	{"gap": 0.62, "pre": 4.0, "breathing": 5.0, "waves": [
		{"lane": "north", "count": 5, "families": ["grunt"]},
		{"lane": "east", "count": 6, "families": ["grunt"]},
		{"lane": "split", "count": 7, "families": ["grunt", "runner"]},
	]},
	{"gap": 0.56, "pre": 4.0, "breathing": 5.0, "waves": [
		{"lane": "east", "count": 6, "families": ["grunt", "runner"]},
		{"lane": "north", "count": 7, "families": ["grunt"]},
		{"lane": "split", "count": 7, "families": ["grunt", "runner"]},
		{"lane": "east", "count": 8, "families": ["runner", "grunt"]},
	]},
	{"gap": 0.52, "pre": 4.0, "breathing": 5.0, "waves": [
		{"lane": "north", "count": 8, "families": ["grunt", "runner"]},
		{"lane": "east", "count": 9, "families": ["grunt", "ranged"]},
		{"lane": "split", "count": 10, "families": ["grunt", "runner", "ranged"]},
		{"lane": "north", "count": 11, "families": ["brute", "grunt", "runner"]},
	]},
	{"gap": 0.56, "pre": 4.4, "breathing": 5.5, "waves": [
		{"lane": "east", "count": 8, "families": ["grunt", "runner"]},
		{"lane": "north", "count": 8, "families": ["brute", "grunt"], "modifier": "armored_vanguard", "breathing_delay": 7.0},
		{"lane": "east", "count": 9, "families": ["grunt", "ranged"]},
		{"lane": "north", "count": 8, "families": ["grunt", "brute", "grunt"], "modifier": "armored_vanguard", "breathing_delay": 7.0},
		{"lane": "split", "count": 9, "families": ["grunt", "runner", "ranged"]},
	]},
	{"gap": 0.60, "pre": 4.3, "breathing": 5.5, "waves": [
		{"lane": "north", "count": 8, "families": ["grunt", "brute"]},
		{"lane": "east", "count": 9, "families": ["runner", "runner", "grunt"], "modifier": "hunting_pack", "breathing_delay": 7.0},
		{"lane": "north", "count": 9, "families": ["grunt", "ranged"]},
		{"lane": "east", "count": 9, "families": ["runner", "grunt", "runner"], "modifier": "hunting_pack", "breathing_delay": 7.0},
		{"lane": "split", "count": 10, "families": ["grunt", "brute", "ranged"]},
	]},
	{"gap": 0.55, "pre": 4.2, "breathing": 5.8, "waves": [
		{"lane": "north", "count": 8, "families": ["brute", "grunt"], "modifier": "armored_vanguard", "breathing_delay": 7.0},
		{"lane": "east", "count": 8, "families": ["runner", "runner", "grunt"], "modifier": "hunting_pack", "breathing_delay": 7.0},
		{"lane": "split", "count": 8, "families": ["grunt", "ranged"]},
		{"lane": "north", "count": 8, "families": ["grunt", "brute"]},
		{"lane": "east", "count": 8, "families": ["runner", "grunt", "runner"], "modifier": "hunting_pack", "breathing_delay": 7.0},
		{"lane": "split", "count": 8, "families": ["grunt", "runner", "ranged"]},
	]},
	{"gap": 0.62, "pre": 4.4, "breathing": 6.0, "waves": [
		{"lane": "east", "count": 8, "families": ["grunt", "ranged"]},
		{"lane": "north", "count": 8, "families": ["brute", "ranged", "ranged"], "modifier": "screened_volley", "breathing_delay": 7.5},
		{"lane": "split", "count": 9, "families": ["grunt", "runner"]},
		{"lane": "east", "count": 9, "families": ["grunt", "ranged", "ranged"], "modifier": "screened_volley", "breathing_delay": 7.5},
		{"lane": "north", "count": 10, "families": ["brute", "grunt"]},
		{"lane": "split", "count": 10, "families": ["grunt", "runner", "ranged"]},
	]},
	{"gap": 0.57, "pre": 4.3, "breathing": 6.0, "waves": [
		{"lane": "north", "count": 8, "families": ["brute", "grunt"], "modifier": "armored_vanguard", "breathing_delay": 7.0},
		{"lane": "east", "count": 8, "families": ["runner", "grunt", "runner"], "modifier": "hunting_pack", "breathing_delay": 7.0},
		{"lane": "split", "count": 8, "families": ["grunt", "ranged"]},
		{"lane": "north", "count": 8, "families": ["brute", "ranged", "ranged"], "modifier": "screened_volley", "breathing_delay": 7.5},
		{"lane": "east", "count": 8, "families": ["grunt", "runner"]},
		{"lane": "split", "count": 8, "families": ["runner", "runner", "grunt"], "modifier": "hunting_pack", "breathing_delay": 7.0},
		{"lane": "split", "count": 8, "families": ["grunt", "brute", "ranged"]},
	]},
	{"gap": 0.54, "pre": 4.5, "breathing": 6.2, "waves": [
		{"lane": "east", "count": 8, "families": ["runner", "grunt", "runner"], "modifier": "hunting_pack", "breathing_delay": 7.0},
		{"lane": "north", "count": 8, "families": ["brute", "grunt"], "modifier": "armored_vanguard", "breathing_delay": 7.0},
		{"lane": "split", "count": 9, "families": ["grunt", "runner", "ranged"]},
		{"lane": "east", "count": 9, "families": ["brute", "ranged", "ranged"], "modifier": "screened_volley", "breathing_delay": 7.5},
		{"lane": "north", "count": 9, "families": ["grunt", "brute"]},
		{"lane": "split", "count": 9, "families": ["brute", "runner", "ranged", "grunt"], "modifier": "combined_arms", "breathing_delay": 8.0},
		{"lane": "split", "count": 10, "families": ["grunt", "runner", "brute", "ranged"]},
	]},
	{"gap": 0.52, "pre": 4.5, "breathing": 6.2, "waves": [
		{"lane": "north", "count": 9, "families": ["brute", "grunt"], "modifier": "armored_vanguard", "breathing_delay": 7.0},
		{"lane": "east", "count": 9, "families": ["runner", "grunt", "runner"], "modifier": "hunting_pack", "breathing_delay": 7.0},
		{"lane": "split", "count": 10, "families": ["grunt", "ranged"]},
		{"lane": "north", "count": 10, "families": ["brute", "ranged", "ranged"], "modifier": "screened_volley", "breathing_delay": 7.5},
		{"lane": "east", "count": 10, "families": ["grunt", "runner"]},
		{"lane": "split", "count": 11, "families": ["brute", "runner", "ranged", "grunt"], "modifier": "combined_arms", "breathing_delay": 8.0},
		{"lane": "split", "count": 13, "families": ["grunt", "runner", "brute", "ranged"], "modifier": "combined_arms", "breathing_delay": 9.0},
	]},
]


static func for_night(night: int, boss_spawn_delay: float) -> Array[Dictionary]:
	var night_index: int = clampi(night, 1, NIGHT_SPECS.size()) - 1
	var spec: Dictionary = NIGHT_SPECS[night_index]
	var result: Array[Dictionary] = []
	for authored_wave: Dictionary in spec["waves"]:
		var wave: Dictionary = authored_wave.duplicate(true)
		wave["gap"] = float(wave.get("gap", spec["gap"]))
		wave["breathing_delay"] = float(wave.get("breathing_delay", spec["breathing"]))
		wave["pre_spawn_delay"] = float(wave.get("pre_spawn_delay", spec["pre"]))
		wave["modifier"] = str(wave.get("modifier", "standard"))
		var modifier: Dictionary = modifier_data(str(wave["modifier"]))
		wave["gap_pattern"] = (modifier.get("gap_pattern", []) as Array).duplicate()
		wave["warning"] = _warning_for(wave, modifier)
		result.append(wave)
	if night == NIGHT_SPECS.size():
		result.append({
			"lane": "boss", "count": 1, "gap": 0.0, "gap_pattern": [],
			"breathing_delay": 0.0, "pre_spawn_delay": maxf(0.0, boss_spawn_delay),
			"families": ["boss"], "modifier": "boss",
			"warning": "THE TROLL CHIEFTAIN APPROACHES",
		})
	return result


static func modifier_data(modifier_id: String) -> Dictionary:
	return (MODIFIERS.get(modifier_id, MODIFIERS["standard"]) as Dictionary).duplicate(true)


static func spawn_entry(wave: Dictionary, spawn_index: int) -> Dictionary:
	var families: Array = wave.get("families", ["grunt"]) as Array
	var family: String = str(families[spawn_index % maxi(1, families.size())]) if not families.is_empty() else "grunt"
	var result: Dictionary = {"family": family, "behavior": {}}
	var modifier: Dictionary = modifier_data(str(wave.get("modifier", "standard")))
	var every: int = maxi(0, int(modifier.get("elite_every", 0)))
	var offset: int = int(modifier.get("elite_offset", 0))
	if every <= 0 or posmod(spawn_index - offset, every) != 0:
		return result
	var behavior_id: String = str((modifier.get("behavior_by_family", {}) as Dictionary).get(family, ""))
	if ELITE_BEHAVIORS.has(behavior_id):
		result["behavior"] = (ELITE_BEHAVIORS[behavior_id] as Dictionary).duplicate(true)
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


static func spawn_gap(wave: Dictionary, spawn_index: int) -> float:
	var pattern: Array = wave.get("gap_pattern", []) as Array
	if not pattern.is_empty():
		return maxf(0.0, float(pattern[spawn_index % pattern.size()]))
	return maxf(0.0, float(wave.get("gap", 0.0)))


static func duration(plan: Array[Dictionary]) -> float:
	## Spawn-script duration only; never a phase-ending countdown.
	var total: float = 0.0
	for wave_index: int in range(plan.size()):
		var wave: Dictionary = plan[wave_index]
		total += pre_spawn_delay(wave)
		for spawn_index: int in range(maxi(0, int(wave.get("count", 0)) - 1)):
			total += spawn_gap(wave, spawn_index)
		if wave_index < plan.size() - 1:
			total += breathing_delay(wave)
	return total


static func _warning_for(wave: Dictionary, modifier: Dictionary) -> String:
	var lane: String = str(wave.get("lane", ""))
	var lane_text: String = "BOTH GATES" if lane == "split" else "%s GATE" % lane.to_upper()
	return "%s  •  %s  •  %s" % [lane_text, str(modifier.get("label", "STANDARD ASSAULT")), str(modifier.get("detail", "NO ELITES"))]
