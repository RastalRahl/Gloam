extends Node2D
class_name GloamConstructionMarker

@export var marker_size: Vector2 = Vector2(56.0, 34.0)

@onready var base: Polygon2D = $Base
@onready var outline: Line2D = $Outline
@onready var hammer: Sprite2D = $Hammer

var selected: bool = false
var nearby: bool = false
var available: bool = true
var occupied: bool = false


func _ready() -> void:
	_rebuild_geometry()
	_apply_state()


func configure_size(new_size: Vector2) -> void:
	marker_size = new_size
	if is_node_ready():
		_rebuild_geometry()


func set_state(is_selected: bool, is_nearby: bool, is_available: bool, is_occupied: bool) -> void:
	selected = is_selected
	nearby = is_nearby
	available = is_available
	occupied = is_occupied
	if is_node_ready():
		_apply_state()


func _rebuild_geometry() -> void:
	var half := marker_size * 0.5
	var points := PackedVector2Array([
		Vector2(0.0, -half.y), Vector2(half.x, 0.0),
		Vector2(0.0, half.y), Vector2(-half.x, 0.0),
	])
	base.polygon = points
	outline.points = PackedVector2Array([points[0], points[1], points[2], points[3], points[0]])
	hammer.position = Vector2(0.0, -5.0)
	hammer.scale = Vector2.ONE * (1.15 if marker_size.x >= 80.0 else 0.9)


func _apply_state() -> void:
	visible = not occupied
	if occupied:
		return
	if not available:
		base.color = Color(0.26, 0.28, 0.28, 0.20)
		outline.default_color = Color(0.48, 0.50, 0.48, 0.32)
		hammer.modulate = Color(0.58, 0.58, 0.55, 0.38)
		scale = Vector2.ONE
	elif selected:
		base.color = Color(0.78, 0.49, 0.12, 0.46)
		outline.default_color = Color(1.0, 0.86, 0.38, 0.96)
		hammer.modulate = Color(1.0, 0.95, 0.72, 1.0)
		scale = Vector2.ONE * 1.08
	elif nearby:
		base.color = Color(0.62, 0.43, 0.16, 0.34)
		outline.default_color = Color(0.94, 0.73, 0.30, 0.78)
		hammer.modulate = Color(1.0, 0.90, 0.62, 0.84)
		scale = Vector2.ONE * 1.04
	else:
		base.color = Color(0.42, 0.32, 0.16, 0.20)
		outline.default_color = Color(0.74, 0.61, 0.34, 0.42)
		hammer.modulate = Color(0.88, 0.77, 0.52, 0.54)
		scale = Vector2.ONE

