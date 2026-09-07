extends Node2D
class_name GloamNightLaneVisuals

const SKULL_SPIKE := preload("res://assets/generated/tiny_swords/props/decorations/skull_spike_01.png")

var north_gate: Node2D
var east_gate: Node2D
var north_breach_marker: Node2D
var east_breach_marker: Node2D
var active: bool = false
var pulse_time: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func configure(
	new_north_gate: Node2D,
	new_east_gate: Node2D,
	new_north_breach_marker: Node2D,
	new_east_breach_marker: Node2D
) -> void:
	north_gate = new_north_gate
	east_gate = new_east_gate
	north_breach_marker = new_north_breach_marker
	east_breach_marker = new_east_breach_marker
	queue_redraw()


func set_active(is_active: bool) -> void:
	active = is_active
	visible = active
	queue_redraw()


func _process(delta: float) -> void:
	if not active:
		return

	pulse_time += delta
	queue_redraw()


func _draw() -> void:
	if not active:
		return

	var north_spawn := Vector2(260.0, 620.0)
	var east_spawn := Vector2(1080.0, 1190.0)
	var north_target := north_gate.global_position if is_instance_valid(north_gate) else Vector2(260.0, 995.0)
	var east_target := east_gate.global_position if is_instance_valid(east_gate) else Vector2(505.0, 1190.0)

	_draw_lane(north_spawn, north_target, Color(0.88, 0.31, 0.22, 0.82), false)
	_draw_lane(east_spawn, east_target, Color(0.95, 0.53, 0.24, 0.82), true)
	_draw_gate_marker(north_breach_marker, Color(0.98, 0.40, 0.24, 0.95))
	_draw_gate_marker(east_breach_marker, Color(1.0, 0.64, 0.25, 0.95))


func _draw_lane(start: Vector2, finish: Vector2, color: Color, horizontal: bool) -> void:
	# Keep the warning language close to the threatened gate. Full-length
	# dashed routes read like debug navigation and compete with combat sprites.
	var direction := start.direction_to(finish)
	var marker_positions: Array[Vector2] = [
		start.lerp(finish, 0.72),
		start.lerp(finish, 0.84),
	]
	for marker_position: Vector2 in marker_positions:
		_draw_chevron(marker_position, direction, color)


func _draw_chevron(center: Vector2, direction: Vector2, color: Color) -> void:
	var normal := Vector2(-direction.y, direction.x)
	var tip := center + direction * 7.0
	var left := center - direction * 5.0 + normal * 6.0
	var right := center - direction * 5.0 - normal * 6.0
	draw_polyline(PackedVector2Array([left, tip, right]), color, 2.0, false)


func _draw_gate_marker(marker: Node2D, color: Color) -> void:
	if not is_instance_valid(marker):
		return

	var pulse := 1.0 + sin(pulse_time * 3.0) * 0.08
	var radius := 18.0 * pulse
	draw_arc(marker.global_position, radius, 0.0, TAU, 16, color, 2.0, false)
	draw_texture_rect(
		SKULL_SPIKE,
		Rect2(marker.global_position - Vector2(10.0, 10.0), Vector2(20.0, 20.0)),
		false,
		color
	)
