@tool
extends Marker2D
class_name GloamWorldPassageMarker

@export var passage_id: String = "passage"
@export_enum("gate", "stairs", "passage") var passage_kind: String = "passage"
@export var direction: Vector2 = Vector2.UP
@export var opening_width: float = 64.0


func _ready() -> void:
	add_to_group("world_passages")
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var across := direction.orthogonal().normalized()
	var color := Color(0.35, 0.95, 0.72, 0.92)
	draw_line(-across * opening_width * 0.5, across * opening_width * 0.5, color, 4.0)
	draw_line(Vector2.ZERO, direction.normalized() * 28.0, color, 3.0)

