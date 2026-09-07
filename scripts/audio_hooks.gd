extends Node
class_name GloamAudioHooks

## Centralized audio router.
##
## The project intentionally contains no imported sound bank. These short PCM
## streams are synthesized at runtime, so the placeholder set is original to
## Gloam and carries no third-party licensing uncertainty.

signal requested(event_name: String, world_position: Vector2, intensity: float)
signal event_played(event_name: String, bus_name: String, world_position: Vector2, intensity: float)
signal settings_changed

const AUDIO_SETTINGS_MENU := preload("res://scripts/audio_settings_menu.gd")
const SETTINGS_PATH: String = "user://gloam_audio_settings.cfg"
const SAMPLE_RATE: int = 22050
const MAX_SFX_VOICES: int = 12
const MAX_CONCURRENT_SFX: int = 8
const UI_VOICE_COUNT: int = 3
const SILENT_DB: float = -80.0

const EVENT_SPECS: Dictionary = {
	"player_attack": {"bus": "SFX", "frequency": 340.0, "end_frequency": 470.0, "duration": 0.085, "gain": 0.34, "wave": "saw", "cooldown": 0.055, "priority": 2, "positional": true},
	"defense_attack": {"bus": "SFX", "frequency": 235.0, "end_frequency": 300.0, "duration": 0.095, "gain": 0.25, "wave": "saw", "cooldown": 0.08, "priority": 1, "positional": true},
	"enemy_hit": {"bus": "SFX", "frequency": 145.0, "end_frequency": 105.0, "duration": 0.065, "gain": 0.20, "wave": "noise", "cooldown": 0.055, "priority": 1, "positional": true},
	"enemy_death": {"bus": "SFX", "frequency": 180.0, "end_frequency": 72.0, "duration": 0.16, "gain": 0.30, "wave": "noise_tone", "cooldown": 0.06, "priority": 1, "positional": true},
	"player_hit": {"bus": "SFX", "frequency": 115.0, "end_frequency": 62.0, "duration": 0.18, "gain": 0.54, "wave": "square", "cooldown": 0.18, "priority": 3, "positional": true},
	"player_downed": {"bus": "SFX", "frequency": 210.0, "end_frequency": 52.0, "duration": 0.42, "gain": 0.60, "wave": "triangle", "cooldown": 0.35, "priority": 3, "positional": true},
	"gate_damage": {"bus": "SFX", "frequency": 82.0, "end_frequency": 54.0, "duration": 0.20, "gain": 0.52, "wave": "noise_tone", "cooldown": 0.22, "priority": 3, "positional": true},
	"gate_destroyed": {"bus": "SFX", "frequency": 125.0, "end_frequency": 36.0, "duration": 0.48, "gain": 0.72, "wave": "noise_tone", "cooldown": 0.50, "priority": 3, "positional": true},
	"structure_damage": {"bus": "SFX", "frequency": 108.0, "end_frequency": 74.0, "duration": 0.12, "gain": 0.28, "wave": "noise", "cooldown": 0.20, "priority": 1, "positional": true},
	"structure_destroyed": {"bus": "SFX", "frequency": 150.0, "end_frequency": 42.0, "duration": 0.34, "gain": 0.48, "wave": "noise_tone", "cooldown": 0.35, "priority": 2, "positional": true},
	"core_damage": {"bus": "SFX", "frequency": 76.0, "end_frequency": 45.0, "duration": 0.24, "gain": 0.62, "wave": "square", "cooldown": 0.24, "priority": 3, "positional": true},
	"core_destroyed": {"bus": "SFX", "frequency": 180.0, "end_frequency": 28.0, "duration": 0.60, "gain": 0.82, "wave": "noise_tone", "cooldown": 0.60, "priority": 3, "positional": true},
	"resource_collect": {"bus": "SFX", "frequency": 520.0, "end_frequency": 760.0, "duration": 0.10, "gain": 0.30, "wave": "sine", "cooldown": 0.08, "priority": 1, "positional": true},
	"survivor_rescued": {"bus": "SFX", "frequency": 390.0, "end_frequency": 640.0, "duration": 0.20, "gain": 0.38, "wave": "sine", "cooldown": 0.15, "priority": 2, "positional": true},
	"soldier_death": {"bus": "SFX", "frequency": 125.0, "end_frequency": 58.0, "duration": 0.25, "gain": 0.42, "wave": "triangle", "cooldown": 0.18, "priority": 2, "positional": true},
	"wave_warning": {"bus": "UI", "frequency": 260.0, "end_frequency": 390.0, "duration": 0.32, "gain": 0.58, "wave": "square", "cooldown": 0.55, "priority": 3, "positional": false},
	"boss_spawn": {"bus": "UI", "frequency": 110.0, "end_frequency": 220.0, "duration": 0.72, "gain": 0.78, "wave": "saw", "cooldown": 0.80, "priority": 3, "positional": false},
	"boss_hit": {"bus": "SFX", "frequency": 92.0, "end_frequency": 128.0, "duration": 0.16, "gain": 0.40, "wave": "square", "cooldown": 0.10, "priority": 2, "positional": true},
	"boss_death": {"bus": "UI", "frequency": 150.0, "end_frequency": 620.0, "duration": 0.90, "gain": 0.88, "wave": "sine", "cooldown": 1.0, "priority": 3, "positional": false},
	"ui_open": {"bus": "UI", "frequency": 300.0, "end_frequency": 430.0, "duration": 0.09, "gain": 0.22, "wave": "sine", "cooldown": 0.08, "priority": 1, "positional": false},
	"ui_confirm": {"bus": "UI", "frequency": 430.0, "end_frequency": 620.0, "duration": 0.12, "gain": 0.25, "wave": "sine", "cooldown": 0.08, "priority": 1, "positional": false},
	"ui_cancel": {"bus": "UI", "frequency": 300.0, "end_frequency": 190.0, "duration": 0.10, "gain": 0.20, "wave": "sine", "cooldown": 0.08, "priority": 1, "positional": false},
	"ui_error": {"bus": "UI", "frequency": 135.0, "end_frequency": 105.0, "duration": 0.13, "gain": 0.25, "wave": "square", "cooldown": 0.12, "priority": 1, "positional": false}
}

var settings_path: String = SETTINGS_PATH
var sfx_voices: Array[AudioStreamPlayer2D] = []
var ui_voices: Array[AudioStreamPlayer] = []
var sfx_voice_started_at: Array[float] = []
var ui_voice_started_at: Array[float] = []
var stream_bank: Dictionary = {}
var last_event_time: Dictionary = {}
var ui_voice_cursor: int = 0
var settings_menu: GloamAudioSettingsMenu = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_buses()
	_load_settings()
	_build_stream_bank()
	_create_voice_pools()
	_create_settings_menu()


func _exit_tree() -> void:
	for voice: AudioStreamPlayer2D in sfx_voices:
		voice.stop()
		voice.stream = null
	for voice: AudioStreamPlayer in ui_voices:
		voice.stop()
		voice.stream = null
	sfx_voices.clear()
	ui_voices.clear()
	sfx_voice_started_at.clear()
	ui_voice_started_at.clear()
	stream_bank.clear()


func request(event_name: String, world_position: Vector2, intensity: float = 1.0) -> void:
	var safe_intensity: float = clampf(intensity, 0.0, 1.5)
	requested.emit(event_name, world_position, safe_intensity)

	if not EVENT_SPECS.has(event_name) or safe_intensity <= 0.0:
		return

	var spec: Dictionary = EVENT_SPECS[event_name]
	var now: float = Time.get_ticks_msec() / 1000.0
	var cooldown: float = float(spec.get("cooldown", 0.0))
	var previous_time: float = float(last_event_time.get(event_name, -INF))
	if now - previous_time < cooldown:
		return

	var voice: Node = _take_voice(str(spec.get("bus", "SFX")), int(spec.get("priority", 1)))
	if not is_instance_valid(voice):
		return

	var variants: Array = stream_bank.get(event_name, [])
	if variants.is_empty():
		return

	var variant_index: int = int(abs(Time.get_ticks_msec() + event_name.hash())) % variants.size()
	var stream: AudioStreamWAV = variants[variant_index] as AudioStreamWAV
	if not is_instance_valid(stream):
		return

	last_event_time[event_name] = now
	var gain: float = clampf(safe_intensity * float(spec.get("gain", 0.3)), 0.0, 1.0)
	if voice is AudioStreamPlayer2D:
		var positional_voice: AudioStreamPlayer2D = voice as AudioStreamPlayer2D
		positional_voice.stream = stream
		positional_voice.volume_db = _volume_to_db(gain)
		positional_voice.global_position = world_position
		positional_voice.max_distance = 1800.0
		positional_voice.attenuation = 0.85
		positional_voice.panning_strength = 0.35
		positional_voice.play()
		var sfx_index: int = sfx_voices.find(positional_voice)
		if sfx_index >= 0:
			sfx_voice_started_at[sfx_index] = now
	else:
		var ui_voice: AudioStreamPlayer = voice as AudioStreamPlayer
		ui_voice.stream = stream
		ui_voice.volume_db = _volume_to_db(gain)
		ui_voice.play()
		var ui_index: int = ui_voices.find(ui_voice)
		if ui_index >= 0:
			ui_voice_started_at[ui_index] = now
	event_played.emit(event_name, str(spec.get("bus", "SFX")), world_position, safe_intensity)


func get_bus_volume(bus_name: String) -> float:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(bus_index))


func is_bus_muted(bus_name: String) -> bool:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	return bus_index >= 0 and AudioServer.is_bus_mute(bus_index)


func set_bus_volume(bus_name: String, linear_volume: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var safe_volume: float = clampf(linear_volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(bus_index, _volume_to_db(safe_volume))
	_save_settings()
	settings_changed.emit()


func set_bus_muted(bus_name: String, muted: bool) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_mute(bus_index, muted)
	_save_settings()
	settings_changed.emit()


func _ensure_audio_buses() -> void:
	if AudioServer.get_bus_index("Master") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Master")

	for bus_name: String in ["Music", "SFX", "UI"]:
		var bus_index: int = AudioServer.get_bus_index(bus_name)
		if bus_index < 0:
			AudioServer.add_bus()
			bus_index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(bus_index, bus_name)
		AudioServer.set_bus_send(bus_index, "Master")


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		_apply_default_settings()
		return

	for bus_name: String in ["Master", "Music", "SFX", "UI"]:
		var volume: float = clampf(float(config.get_value("audio", "%s_volume" % bus_name, 1.0)), 0.0, 1.0)
		var muted: bool = bool(config.get_value("audio", "%s_muted" % bus_name, false))
		var bus_index: int = AudioServer.get_bus_index(bus_name)
		if bus_index >= 0:
			AudioServer.set_bus_volume_db(bus_index, _volume_to_db(volume))
			AudioServer.set_bus_mute(bus_index, muted)


func _apply_default_settings() -> void:
	for bus_name: String in ["Master", "Music", "SFX", "UI"]:
		var bus_index: int = AudioServer.get_bus_index(bus_name)
		if bus_index >= 0:
			AudioServer.set_bus_volume_db(bus_index, 0.0)
			AudioServer.set_bus_mute(bus_index, false)


func _save_settings() -> void:
	var config := ConfigFile.new()
	for bus_name: String in ["Master", "Music", "SFX", "UI"]:
		config.set_value("audio", "%s_volume" % bus_name, get_bus_volume(bus_name))
		config.set_value("audio", "%s_muted" % bus_name, is_bus_muted(bus_name))
	config.save(settings_path)


func _build_stream_bank() -> void:
	for event_name: String in EVENT_SPECS.keys():
		var spec: Dictionary = EVENT_SPECS[event_name]
		var variants: Array[AudioStreamWAV] = []
		variants.append(_build_stream(spec, event_name, 0))
		variants.append(_build_stream(spec, event_name, 1))
		stream_bank[event_name] = variants


func _build_stream(spec: Dictionary, event_name: String, variant: int) -> AudioStreamWAV:
	var duration: float = maxf(0.025, float(spec.get("duration", 0.1)))
	var sample_count: int = maxi(1, int(round(duration * SAMPLE_RATE)))
	var start_frequency: float = maxf(20.0, float(spec.get("frequency", 220.0)))
	var end_frequency: float = maxf(20.0, float(spec.get("end_frequency", start_frequency)))
	var gain: float = clampf(float(spec.get("gain", 0.3)), 0.0, 1.0)
	var wave: String = str(spec.get("wave", "sine"))
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	var phase: float = float(variant) * 0.7
	var noise_rng := RandomNumberGenerator.new()
	noise_rng.seed = absi(event_name.hash() + variant * 7919)
	for index in range(sample_count):
		var progress: float = float(index) / float(maxi(1, sample_count - 1))
		var frequency: float = lerpf(start_frequency, end_frequency, progress)
		phase += TAU * frequency / float(SAMPLE_RATE)
		var tone: float = sin(phase)
		match wave:
			"square":
				tone = 1.0 if tone >= 0.0 else -1.0
			"saw":
				tone = 2.0 * fmod(phase / TAU, 1.0) - 1.0
			"triangle":
				tone = (2.0 / PI) * asin(clampf(sin(phase), -1.0, 1.0))
			"noise":
				tone = noise_rng.randf_range(-1.0, 1.0)
			"noise_tone":
				tone = tone * 0.55 + noise_rng.randf_range(-1.0, 1.0) * 0.45

		var envelope: float = 1.0
		var attack_samples: int = maxi(1, int(SAMPLE_RATE * minf(0.012, duration * 0.25)))
		var release_samples: int = maxi(1, int(SAMPLE_RATE * minf(0.08, duration * 0.40)))
		if index < attack_samples:
			envelope = float(index) / float(attack_samples)
		elif index >= sample_count - release_samples:
			envelope = float(sample_count - index) / float(release_samples)

		var sample_value: int = clampi(int(round(tone * envelope * gain * 32767.0)), -32767, 32767)
		data[index * 2] = sample_value & 0xff
		data[index * 2 + 1] = (sample_value >> 8) & 0xff

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream


func _create_voice_pools() -> void:
	for index in range(MAX_SFX_VOICES):
		var voice := AudioStreamPlayer2D.new()
		voice.name = "SFXVoice%d" % index
		voice.bus = "SFX"
		add_child(voice)
		sfx_voices.append(voice)
		sfx_voice_started_at.append(-INF)

	for index in range(UI_VOICE_COUNT):
		var voice := AudioStreamPlayer.new()
		voice.name = "UIVoice%d" % index
		voice.bus = "UI"
		add_child(voice)
		ui_voices.append(voice)
		ui_voice_started_at.append(-INF)


func _take_voice(bus_name: String, priority: int) -> Node:
	if bus_name == "UI":
		return _take_ui_voice()
	return _take_sfx_voice(priority)


func _take_sfx_voice(priority: int) -> AudioStreamPlayer2D:
	for voice: AudioStreamPlayer2D in sfx_voices:
		if not voice.playing:
			return voice

	var active_count: int = 0
	for voice: AudioStreamPlayer2D in sfx_voices:
		if voice.playing:
			active_count += 1
	if active_count >= MAX_CONCURRENT_SFX and priority < 3:
		return null

	var oldest_index: int = -1
	var oldest_time: float = INF
	for index in range(sfx_voices.size()):
		if sfx_voices[index].playing and sfx_voice_started_at[index] < oldest_time:
			oldest_time = sfx_voice_started_at[index]
			oldest_index = index

	if oldest_index < 0:
		return null

	sfx_voices[oldest_index].stop()
	sfx_voice_started_at[oldest_index] = Time.get_ticks_msec() / 1000.0
	return sfx_voices[oldest_index]


func _take_ui_voice() -> AudioStreamPlayer:
	for voice: AudioStreamPlayer in ui_voices:
		if not voice.playing:
			return voice

	var oldest_index: int = ui_voice_cursor % maxi(1, ui_voices.size())
	ui_voice_cursor += 1
	ui_voices[oldest_index].stop()
	return ui_voices[oldest_index]


func _create_settings_menu() -> void:
	var scene_root: Node = get_parent()
	var ui_layer: CanvasLayer = scene_root.get_node_or_null("UI") as CanvasLayer
	if not is_instance_valid(ui_layer):
		return

	settings_menu = AUDIO_SETTINGS_MENU.new() as GloamAudioSettingsMenu
	settings_menu.name = "AudioSettingsMenu"
	var game_settings: GloamGameSettings = scene_root.get_node_or_null("GameSettings") as GloamGameSettings
	settings_menu.configure(self, game_settings)
	ui_layer.add_child(settings_menu)


func _volume_to_db(linear_volume: float) -> float:
	var safe_volume: float = clampf(linear_volume, 0.0, 1.0)
	return SILENT_DB if safe_volume <= 0.0001 else linear_to_db(safe_volume)
