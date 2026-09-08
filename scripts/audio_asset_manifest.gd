extends RefCounted
class_name GloamAudioAssetManifest

## Only assets with a matching record in assets/audio/LICENSES.md belong here.
## Empty is intentional: the router stays silent rather than synthesize audio.
const REQUIRED_EVENTS: Array[String] = [
	"player_attack", "defense_attack", "enemy_hit", "enemy_death", "player_hit", "player_downed", "gate_damage", "gate_destroyed", "structure_damage", "structure_destroyed", "core_damage", "core_destroyed", "resource_collect", "survivor_rescued", "soldier_death", "wave_warning", "boss_spawn", "boss_hit", "boss_death", "ui_open", "ui_confirm", "ui_cancel", "ui_error", "dawn_transition", "dusk_transition", "ambience_village_day", "ambience_forest_day", "ambience_mine_day", "ambience_ruins_day", "ambience_night", "music_day", "music_night"
]

const ASSETS: Dictionary = {}

static func paths_for(event_name: String) -> Array[String]:
	var entry: Variant = ASSETS.get(event_name, {})
	return (entry as Dictionary).get("paths", []) as Array[String] if entry is Dictionary else []
