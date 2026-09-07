extends SceneTree

const RUN_CHECKPOINT := preload("res://scripts/run_checkpoint.gd")
const MAIN_SCENE := preload("res://scenes/main.tscn")
const TEST_PATH := "res://.godot/run_checkpoint_verification.json"

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("GLOAM RUN CHECKPOINT VERIFICATION")
	var store := RUN_CHECKPOINT.new(TEST_PATH) as GloamRunCheckpoint
	store.clear_run()
	_test_round_trip(store)
	_test_corruption_recovery(store)
	_test_unsupported_rejection(store)
	_test_new_run_reset(store)
	await _test_full_scene_restore(store)
	store.clear_run()
	print("RUN CHECKPOINT VERIFICATION: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _test_round_trip(store: GloamRunCheckpoint) -> void:
	print("-- stable dawn round trip")
	store.clear_run()
	var expected := _fixture(4)
	_check(store.save_dawn(expected), "valid dawn saves")
	var actual := store.load_latest_dawn()
	var normalized_parser := JSON.new()
	normalized_parser.parse(JSON.stringify(expected))
	_check(actual == normalized_parser.data, "all durable run state round-trips")
	var serialized := JSON.stringify(actual).to_lower()
	_check(not serialized.contains("enemy") and not serialized.contains("timer") and not serialized.contains("signal") and not serialized.contains("node"), "snapshot excludes transient runtime state")


func _test_corruption_recovery(store: GloamRunCheckpoint) -> void:
	print("-- corruption and backup recovery")
	store.clear_run()
	var prior := _fixture(2)
	var latest := _fixture(3)
	_check(store.save_dawn(prior), "first generation saves")
	_check(store.save_dawn(latest), "second generation saves and rotates backup")
	_write_text(TEST_PATH, "{ definitely not valid json")
	var recovered := store.load_latest_dawn()
	_check(store.loaded_from_backup and int(recovered.get("day", 0)) == 2, "corrupt primary recovers the prior valid dawn")
	_write_text(TEST_PATH + ".bak", "also corrupt")
	_check(store.load_latest_dawn().is_empty(), "two corrupt generations are rejected safely")


func _test_unsupported_rejection(store: GloamRunCheckpoint) -> void:
	print("-- unsupported version rejection")
	store.clear_run()
	var payload_json := JSON.stringify(_fixture(5))
	_write_text(TEST_PATH, JSON.stringify({
		"format": GloamRunCheckpoint.FORMAT_ID,
		"version": GloamRunCheckpoint.CURRENT_VERSION + 1,
		"payload": payload_json,
		"checksum": payload_json.sha256_text(),
	}))
	_check(store.load_latest_dawn().is_empty(), "future checkpoint versions are rejected")
	_check(not store.last_error.is_empty(), "rejection is reported without crashing")


func _test_new_run_reset(store: GloamRunCheckpoint) -> void:
	print("-- new-run reset")
	store.clear_run()
	_check(store.save_dawn(_fixture(7)), "checkpoint exists before reset")
	_check(store.save_dawn(_fixture(8)), "backup exists before reset")
	_write_text(TEST_PATH + ".tmp", "interrupted write")
	_check(store.clear_run(), "new-run reset succeeds")
	_check(not FileAccess.file_exists(TEST_PATH) and not FileAccess.file_exists(TEST_PATH + ".bak") and not FileAccess.file_exists(TEST_PATH + ".tmp"), "new-run reset removes primary, backup, and temporary generations")
	_check(store.load_latest_dawn().is_empty() and store.last_error.is_empty(), "reset state starts clean rather than corrupt")


func _test_full_scene_restore(store: GloamRunCheckpoint) -> void:
	print("-- live dawn reconstruction")
	store.clear_run()
	var main := MAIN_SCENE.instantiate()
	main.run_checkpoint = RUN_CHECKPOINT.new(TEST_PATH)
	root.add_child(main)
	await process_frame
	main.checkpoint_enabled = true
	main._choose_starting_weapon("bow")
	var automatic_dawn: Dictionary = main.run_checkpoint.load_latest_dawn()
	_check(not automatic_dawn.is_empty() and int(automatic_dawn.get("day", 0)) == 1, "starting a run writes the stable Day 1 dawn")
	if automatic_dawn.is_empty():
		print("Rejected automatic payload: %s" % JSON.stringify(main._capture_dawn_checkpoint()))
	var restored: bool = main._apply_dawn_checkpoint(_fixture(4))
	await process_frame
	_check(restored and main.current_day == 4 and main.current_phase == main.Phase.DAY, "resume enters the saved dawn directly")
	var defense_spot := main.get_node("World/Regions/Village/DefenseBuildSpots/DefenseSpot_01") as GloamBuildSpot
	var village_spot := main.get_node("World/Regions/Village/VillageBuildSpots/VillageSpot_01") as GloamVillageBuildSpot
	_check(defense_spot.occupied and defense_spot.structure.level == 2 and defense_spot.structure.hp == 51, "defense kind, level, and health reconstruct")
	_check(village_spot.occupied and village_spot.building.level == 3 and village_spot.building.hp == 120, "village structure kind, level, and health reconstruct")
	_check(main.guards == 2 and main.archers == 1 and main.get_node("Soldiers").get_child_count() == 3, "population assignments reconstruct their actors")
	_check(main.east_gate.is_breached and main.east_gate.hp == 0 and main.north_gate.level == 2, "gate breach, health, and level reconstruct")
	_check(main.player.weapon_type == "spear" and main.player.level == 6 and main.player.fire_level == 2 and main.pending_level_ups == 1, "player weapon, stats, and progression reconstruct")
	_check(main.exploration_seed == 731941 and main.rng.state == 99887766 and main.upgrade_rng.state == 88776655, "deterministic seeds and generator states reconstruct")
	_check(main.get_node("Enemies").get_child_count() == 0 and not main.wave_director.night_schedule_active, "resume contains no transient night enemies or wave work")
	main.free()
	await create_timer(0.25, true).timeout


func _fixture(day: int) -> Dictionary:
	return {
		"boundary": "dawn",
		"day": day,
		"completed_nights": day - 1,
		"resources": {"wood": 41, "stone": 23, "iron": 9, "food": 12, "essence": 7},
		"population": {"total": 8, "unassigned": 1, "workers": 4, "guards": 2, "archers": 1},
		"structures": {
			"defenses": [{"spot": "DefenseSpot_01", "kind": "archer", "level": 2, "hp": 51, "max_hp": 65}],
			"village": [{"spot": "VillageSpot_01", "kind": "house", "level": 3, "hp": 120, "max_hp": 182}],
		},
		"gates": [
			{"gate": "NorthGate", "level": 2, "hp": 190, "max_hp": 261, "breached": false},
			{"gate": "EastGate", "level": 1, "hp": 0, "max_hp": 180, "breached": true},
		],
		"core": {"hp": 73, "max_hp": 100},
		"player": {
			"weapon": "spear", "level": 6, "xp": 8, "xp_to_next": 17,
			"hp": 64, "max_hp": 100,
			"elements": {"fire": 2, "water": 1, "earth": 1, "air": 1},
			"pending_level_ups": 1,
		},
		"shrine": {"active_ward_bonus": 25},
		"seeds": {
			"exploration": "731941", "combat_seed": "-445566", "combat_state": "99887766",
			"upgrade_seed": "1307", "upgrade_state": "88776655",
		},
	}


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "test can write %s" % path)
		return
	file.store_string(content)
	file.close()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)
