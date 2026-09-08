extends Control
class_name GloamNightThreatOverlay

const SKULL_SPIKE := preload("res://assets/generated/tiny_swords/props/decorations/skull_spike_01.png")

var threats: Array[Dictionary] = []
var high_contrast: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()


func set_threats(new_threats: Array) -> void:
	threats.clear()
	for threat: Variant in new_threats:
		if threat is Dictionary:
			threats.append(threat)
	visible = not threats.is_empty()
	queue_redraw()


func set_high_contrast(enabled: bool) -> void:
	high_contrast = enabled
	queue_redraw()


func _draw() -> void:
	if threats.is_empty():
		return

	var viewport_size := size
	var font: Font = ThemeDB.fallback_font
	for threat: Dictionary in threats:
		var lane: String = str(threat.get("lane", "NORTH"))
		var direction: String = str(threat.get("direction", "↓"))
		var urgency: String = str(threat.get("urgency", "WATCH"))
		var hostile_count: int = int(threat.get("count", 0))
		var priority: String = str(threat.get("priority", urgency))
		var accent: Color = Color(1.0, 0.86, 0.24, 1.0) if high_contrast else threat.get("color", Color(0.95, 0.36, 0.24, 1.0))
		var box_size := Vector2(218.0, 46.0)
		var box_position := Vector2(226.0, 14.0)

		if lane == "EAST":
			box_position = Vector2(viewport_size.x - box_size.x - 14.0, 14.0)

		# Indicators sit in the top edge gutters, outside the combat center and only
		# appear while their lane has an off-screen enemy.
		draw_rect(Rect2(box_position, box_size), Color(0.025, 0.040, 0.050, 0.96 if high_contrast else 0.88), true)
		draw_rect(Rect2(box_position, box_size), accent, false, 3.0 if high_contrast else 2.0)
		draw_texture_rect(
			SKULL_SPIKE,
			Rect2(box_position + Vector2(8.0, 11.0), Vector2(24.0, 24.0)),
			false,
			accent
		)
		var heading: String = "%s %s GATE" % [direction, lane]
		if hostile_count > 0:
			heading += "  •  %s" % urgency
		draw_string(font, box_position + Vector2(39.0, 19.0), heading, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(0.98, 0.88, 0.67, 1.0))
		var detail: String = "OFF-SCREEN  •  %s" % urgency
		if hostile_count > 0:
			detail = "%d OFF-SCREEN  •  %s" % [hostile_count, priority]
		draw_string(font, box_position + Vector2(39.0, 35.0), detail, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, accent)
