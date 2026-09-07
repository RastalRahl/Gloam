extends RefCounted
class_name GloamRunCheckpoint

## Versioned, atomic persistence for stable dawn snapshots.
##
## The payload is deliberately plain data. Live nodes, signals, timers, enemies,
## and other transient scene state never cross this boundary.

const FORMAT_ID := "gloam-run-checkpoint"
const CURRENT_VERSION := 1
const DEFAULT_PATH := "user://run_checkpoint.json"

var checkpoint_path: String = DEFAULT_PATH
var last_error: String = ""
var loaded_from_backup: bool = false


func _init(path: String = DEFAULT_PATH) -> void:
	checkpoint_path = path


func save_dawn(payload: Dictionary) -> bool:
	last_error = ""
	loaded_from_backup = false
	if not _validate_payload(payload):
		last_error = "Checkpoint payload is not a supported stable dawn."
		return false

	var payload_json := JSON.stringify(payload)
	var envelope := {
		"format": FORMAT_ID,
		"version": CURRENT_VERSION,
		"payload": payload_json,
		"checksum": payload_json.sha256_text(),
	}
	var temporary_path := checkpoint_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		last_error = "Could not open the temporary checkpoint file."
		return false
	file.store_string(JSON.stringify(envelope))
	file.flush()
	file.close()

	# Verify the exact bytes we are about to promote before touching the current
	# checkpoint. A prior valid primary becomes the recoverable backup.
	if _read_valid_file(temporary_path).is_empty():
		last_error = "Temporary checkpoint verification failed."
		_remove_if_present(temporary_path)
		return false

	var absolute_primary := ProjectSettings.globalize_path(checkpoint_path)
	var absolute_temporary := ProjectSettings.globalize_path(temporary_path)
	var backup_path := checkpoint_path + ".bak"
	var absolute_backup := ProjectSettings.globalize_path(backup_path)
	var primary_was_valid := not _read_valid_file(checkpoint_path).is_empty()
	if FileAccess.file_exists(checkpoint_path):
		if primary_was_valid:
			_remove_if_present(backup_path)
			if DirAccess.rename_absolute(absolute_primary, absolute_backup) != OK:
				last_error = "Could not rotate the previous checkpoint to its backup."
				_remove_if_present(temporary_path)
				return false
		else:
			# Never replace a known-good backup with a corrupt primary.
			_remove_if_present(checkpoint_path)

	if DirAccess.rename_absolute(absolute_temporary, absolute_primary) != OK:
		last_error = "Could not replace the checkpoint atomically."
		if primary_was_valid and FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup, absolute_primary)
		_remove_if_present(temporary_path)
		return false
	return true


func load_latest_dawn() -> Dictionary:
	last_error = ""
	loaded_from_backup = false
	var primary := _read_valid_file(checkpoint_path)
	if not primary.is_empty():
		return primary
	var backup := _read_valid_file(checkpoint_path + ".bak")
	if not backup.is_empty():
		loaded_from_backup = true
		return backup
	if FileAccess.file_exists(checkpoint_path) or FileAccess.file_exists(checkpoint_path + ".bak"):
		last_error = "No valid supported checkpoint was found."
	return {}


func clear_run() -> bool:
	last_error = ""
	var success := true
	for path: String in [checkpoint_path, checkpoint_path + ".tmp", checkpoint_path + ".bak"]:
		if FileAccess.file_exists(path):
			var result := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			if result != OK:
				success = false
	if not success:
		last_error = "Could not clear every run checkpoint file."
	return success


func _read_valid_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var envelope_parser := JSON.new()
	if envelope_parser.parse(text) != OK:
		return {}
	var parsed: Variant = envelope_parser.data
	if not parsed is Dictionary:
		return {}
	var envelope := parsed as Dictionary
	if not _has_only_keys(envelope, ["format", "version", "payload", "checksum"]):
		return {}
	if envelope.get("format") != FORMAT_ID or envelope.get("version") != CURRENT_VERSION:
		return {}
	if not envelope.get("payload") is String or not envelope.get("checksum") is String:
		return {}
	var payload_json: String = envelope["payload"]
	if payload_json.sha256_text() != envelope["checksum"]:
		return {}
	var payload_parser := JSON.new()
	if payload_parser.parse(payload_json) != OK:
		return {}
	var payload_value: Variant = payload_parser.data
	if not payload_value is Dictionary:
		return {}
	var payload := payload_value as Dictionary
	return payload if _validate_payload(payload) else {}


func _validate_payload(payload: Dictionary) -> bool:
	var keys := ["boundary", "day", "completed_nights", "resources", "population", "structures", "gates", "core", "player", "shrine", "seeds"]
	if not _has_only_keys(payload, keys) or payload.get("boundary") != "dawn":
		return false
	if not _whole_in_range(payload.get("day"), 1, 1000):
		return false
	if not _whole_in_range(payload.get("completed_nights"), 0, 999):
		return false
	if int(payload["completed_nights"]) != int(payload["day"]) - 1:
		return false
	if not _validate_nonnegative_map(payload.get("resources"), ["wood", "stone", "iron", "food", "essence"]):
		return false
	if not _validate_nonnegative_map(payload.get("population"), ["total", "unassigned", "workers", "guards", "archers"]):
		return false
	var population: Dictionary = payload["population"]
	if int(population["unassigned"]) + int(population["workers"]) + int(population["guards"]) + int(population["archers"]) != int(population["total"]):
		return false
	if not _validate_structures(payload.get("structures")) or not _validate_gates(payload.get("gates")):
		return false
	if not _validate_nonnegative_map(payload.get("core"), ["hp", "max_hp"]):
		return false
	var core: Dictionary = payload["core"]
	if int(core["max_hp"]) <= 0 or int(core["hp"]) <= 0 or int(core["hp"]) > int(core["max_hp"]):
		return false
	if not _validate_player(payload.get("player")):
		return false
	if not _validate_nonnegative_map(payload.get("shrine"), ["active_ward_bonus"]):
		return false
	if not payload.get("seeds") is Dictionary:
		return false
	var seeds: Dictionary = payload["seeds"]
	if not _has_only_keys(seeds, ["exploration", "combat_seed", "combat_state", "upgrade_seed", "upgrade_state"]):
		return false
	for value: Variant in seeds.values():
		if not value is String or not (value as String).is_valid_int():
			return false
	return true


func _validate_structures(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var structures := value as Dictionary
	if not _has_only_keys(structures, ["defenses", "village"]):
		return false
	for category: String in ["defenses", "village"]:
		if not structures[category] is Array:
			return false
		var seen_spots: Dictionary = {}
		for entry_value: Variant in structures[category]:
			if not entry_value is Dictionary:
				return false
			var entry := entry_value as Dictionary
			if not _has_only_keys(entry, ["spot", "kind", "level", "hp", "max_hp"]):
				return false
			if not entry["spot"] is String or (entry["spot"] as String).is_empty() or seen_spots.has(entry["spot"]):
				return false
			if not entry["kind"] is String or (entry["kind"] as String).is_empty():
				return false
			if not _valid_durable_state(entry):
				return false
			if int(entry["hp"]) <= 0:
				return false
			seen_spots[entry["spot"]] = true
	return true


func _validate_gates(value: Variant) -> bool:
	if not value is Array:
		return false
	var seen: Dictionary = {}
	for entry_value: Variant in value:
		if not entry_value is Dictionary:
			return false
		var entry := entry_value as Dictionary
		if not _has_only_keys(entry, ["gate", "level", "hp", "max_hp", "breached"]):
			return false
		if not entry["gate"] is String or (entry["gate"] as String).is_empty() or seen.has(entry["gate"]):
			return false
		if not entry["breached"] is bool or not _valid_durable_state(entry):
			return false
		if bool(entry["breached"]) != (int(entry["hp"]) == 0):
			return false
		seen[entry["gate"]] = true
	return true


func _validate_player(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var player := value as Dictionary
	if not _has_only_keys(player, ["weapon", "level", "xp", "xp_to_next", "hp", "max_hp", "elements", "pending_level_ups"]):
		return false
	if player.get("weapon") not in ["sword", "bow", "spear"]:
		return false
	for key: String in ["level", "xp", "xp_to_next", "hp", "max_hp", "pending_level_ups"]:
		if not _whole_in_range(player.get(key), 0, 1000000000):
			return false
	if int(player["level"]) < 1 or int(player["xp_to_next"]) < 1 or int(player["max_hp"]) < 1 or int(player["hp"]) > int(player["max_hp"]):
		return false
	if not _validate_nonnegative_map(player.get("elements"), ["fire", "water", "earth", "air"]):
		return false
	return true


func _valid_durable_state(entry: Dictionary) -> bool:
	for key: String in ["level", "hp", "max_hp"]:
		if not _whole_in_range(entry.get(key), 0, 1000000000):
			return false
	return int(entry["level"]) >= 1 and int(entry["max_hp"]) >= 1 and int(entry["hp"]) <= int(entry["max_hp"])


func _validate_nonnegative_map(value: Variant, keys: Array) -> bool:
	if not value is Dictionary:
		return false
	var values := value as Dictionary
	if not _has_only_keys(values, keys):
		return false
	for key: Variant in keys:
		if not _whole_in_range(values.get(key), 0, 1000000000):
			return false
	return true


func _whole_in_range(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	return is_finite(number) and number == floor(number) and number >= minimum and number <= maximum


func _has_only_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key: Variant in expected:
		if not value.has(key):
			return false
	return true


func _remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
