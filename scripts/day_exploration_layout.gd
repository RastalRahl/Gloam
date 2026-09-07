extends RefCounted
class_name GloamDayExplorationLayout

## Day traversal and zone semantics. Resource and enemy positions are authored
## as Marker2D nodes in the regional scenes and indexed by GloamWorldVisuals.

const DAY_OBSTACLE_LAYER: int = 16
const ZONE_ORDER: Array[String] = ["forest", "mine", "ruins"]

const VILLAGE_BOUNDS := Rect2(0.0, 896.0, 620.0, 504.0)
const ZONE_BOUNDS: Dictionary = {
	"forest": Rect2(600.0, 700.0, 810.0, 700.0),
	"mine": Rect2(1400.0, 760.0, 1000.0, 640.0),
	"ruins": Rect2(1180.0, 80.0, 1160.0, 600.0),
}

# Deterministic traversal probes used by verification. These are not world
# construction data and do not create nodes or collision.
const PATHS: Dictionary = {
	"forest": [
		Vector2(320.0, 1190.0), Vector2(610.0, 1190.0), Vector2(610.0, 1150.0),
		Vector2(760.0, 1140.0), Vector2(930.0, 1090.0), Vector2(1050.0, 1040.0),
		Vector2(1140.0, 960.0), Vector2(1230.0, 900.0), Vector2(1230.0, 820.0),
		Vector2(1260.0, 820.0), Vector2(1360.0, 760.0),
	],
	"mine": [
		Vector2(320.0, 1190.0), Vector2(610.0, 1190.0), Vector2(700.0, 1160.0),
		Vector2(940.0, 1160.0), Vector2(1180.0, 1160.0), Vector2(1360.0, 1120.0),
		Vector2(1510.0, 1080.0), Vector2(1680.0, 1080.0), Vector2(1840.0, 1120.0),
		Vector2(2000.0, 1120.0), Vector2(2160.0, 1120.0), Vector2(2240.0, 1160.0),
	],
	"mine_branch": [
		Vector2(1740.0, 1060.0), Vector2(1840.0, 970.0), Vector2(2010.0, 920.0),
		Vector2(2190.0, 900.0), Vector2(2200.0, 780.0),
	],
	"ruins": [
		Vector2(320.0, 1190.0), Vector2(260.0, 1120.0), Vector2(260.0, 1010.0),
		Vector2(260.0, 940.0), Vector2(260.0, 840.0), Vector2(420.0, 840.0),
		Vector2(560.0, 700.0), Vector2(800.0, 680.0), Vector2(1000.0, 640.0),
		Vector2(1180.0, 620.0), Vector2(1340.0, 660.0), Vector2(1500.0, 660.0),
		Vector2(1680.0, 660.0), Vector2(1860.0, 660.0), Vector2(2040.0, 660.0),
		Vector2(2200.0, 660.0), Vector2(2200.0, 580.0), Vector2(2260.0, 420.0),
	],
	"ruins_branch": [
		Vector2(1600.0, 560.0), Vector2(1710.0, 505.0), Vector2(1780.0, 430.0),
		Vector2(1840.0, 360.0),
	],
}

# All legacy landmark rectangles were terrain/prop substitutes and remain
# removed. Future entries must have a visible world anchor and an explicitly
# temporary gameplay purpose.
const TEMPORARY_GAMEPLAY_BLOCKERS: Array[Dictionary] = []


static func get_paths() -> Dictionary:
	return PATHS.duplicate(true)


static func get_obstacle_rects() -> Array[Dictionary]:
	return TEMPORARY_GAMEPLAY_BLOCKERS.duplicate(true)


static func create_day_obstacles(parent: Node2D) -> void:
	for entry: Dictionary in get_obstacle_rects():
		var body := StaticBody2D.new()
		body.name = str(entry["name"])
		body.collision_layer = DAY_OBSTACLE_LAYER
		body.collision_mask = 0
		body.set_meta("zone", entry["zone"])
		body.set_meta("purpose", entry["purpose"])
		body.set_meta("collision_category", "temporary")
		body.add_to_group("temporary_gameplay_collision")
		var rect: Rect2 = entry["rect"]
		body.position = rect.position + rect.size * 0.5
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collision.shape = shape
		body.add_child(collision)
		parent.add_child(body)


static func set_day_obstacles_active(parent: Node2D, active: bool) -> void:
	for child: Node in parent.get_children():
		if child is StaticBody2D:
			(child as StaticBody2D).collision_layer = DAY_OBSTACLE_LAYER if active else 0


static func get_safe_position(position: Vector2, clearance: float = 20.0) -> Vector2:
	var safe_position: Vector2 = position
	for entry: Dictionary in get_obstacle_rects():
		var rect: Rect2 = entry["rect"].grow(clearance)
		if not rect.has_point(safe_position):
			continue
		var candidates: Array[Vector2] = [
			Vector2(rect.position.x, safe_position.y), Vector2(rect.end.x, safe_position.y),
			Vector2(safe_position.x, rect.position.y), Vector2(safe_position.x, rect.end.y),
		]
		var closest: Vector2 = candidates[0]
		var closest_distance: float = safe_position.distance_squared_to(closest)
		for candidate: Vector2 in candidates:
			var candidate_distance: float = safe_position.distance_squared_to(candidate)
			if candidate_distance < closest_distance:
				closest = candidate
				closest_distance = candidate_distance
		safe_position = closest
	return safe_position


static func is_village_position(position: Vector2) -> bool:
	return VILLAGE_BOUNDS.has_point(position)


static func zone_for_position(position: Vector2) -> String:
	if is_village_position(position):
		return "village"
	for zone: String in ZONE_ORDER:
		if (ZONE_BOUNDS[zone] as Rect2).has_point(position):
			return zone
	return "wilderness"
