@tool
extends Marker2D
class_name GloamWorldSpawnMarker

@export_enum("night_enemy", "night_boss", "day_enemy", "resource", "survivor", "guard_post", "archer_post") var marker_kind: String = "night_enemy"
@export_enum("north", "east", "forest", "mine", "ruins", "village") var lane_or_zone: String = "north"
@export var route_id: String = ""
@export var resource_type: String = ""
@export_range(0, 2) var variation_set: int = 0
@export_range(1, 3) var risk_tier: int = 1


func _ready() -> void:
	add_to_group("world_spawn_markers")
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var color := Color(0.95, 0.28, 0.22, 0.9)
	if marker_kind == "resource":
		color = Color(0.95, 0.78, 0.25, 0.9)
	elif marker_kind in ["guard_post", "archer_post", "survivor"]:
		color = Color(0.28, 0.75, 0.95, 0.9)
	draw_circle(Vector2.ZERO, 12.0, color, false, 2.0)
	draw_line(Vector2(-18.0, 0.0), Vector2(18.0, 0.0), color, 2.0)
	draw_line(Vector2(0.0, -18.0), Vector2(0.0, 18.0), color, 2.0)
