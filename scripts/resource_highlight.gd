extends Node2D
class_name GloamResourceHighlight

var radius: float = 22.0
var highlight_color: Color = Color(1.0, 0.8, 0.35, 0.8)
var active: bool = false


func configure(new_radius: float, new_color: Color) -> void:
	radius = new_radius
	highlight_color = new_color
	queue_redraw()


func set_active(new_active: bool) -> void:
	if active == new_active:
		visible = true
		return
	active = new_active
	visible = true
	queue_redraw()


func _draw() -> void:
	var arc_color := highlight_color
	var line_width: float = 2.0
	var arc_span: float = TAU / 7.0
	if not active:
		# A restrained dormant cue distinguishes collectible logs/rocks from
		# identical scenery without turning every pickup into bright UI chrome.
		arc_color.a *= 0.32
		line_width = 1.0
		arc_span = TAU / 16.0
	# Three short arcs read as a restrained focus cue rather than a permanent
	# bright circle under every pickup.
	for segment: int in range(3):
		var start_angle := -PI * 0.5 + float(segment) * TAU / 3.0 + 0.12
		var end_angle := start_angle + arc_span
		draw_arc(Vector2.ZERO, radius, start_angle, end_angle, 12, arc_color, line_width, true)
