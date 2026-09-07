extends RefCounted
class_name GloamPlacementValidation

## Shared deterministic checks for authored props, resources, and day spawns.
##
## The check is deliberately geometry-first: an anchor must be on the authored
## walkable ground mask, its root rectangle must clear cliff-edge rectangles,
## and it must not intersect an existing ground footprint.  Candidate search is
## a fixed ordered list, never an unseeded random placement system.

const CELL_SIZE: float = 64.0
const TERRAIN_LAYER: int = 4
const PROP_LAYER: int = 8
const PLACEMENT_MASK: int = TERRAIN_LAYER | PROP_LAYER

const FIXED_OFFSETS: Array[Vector2] = [
	Vector2.ZERO,
	Vector2(40.0, 0.0), Vector2(-40.0, 0.0),
	Vector2(0.0, 40.0), Vector2(0.0, -40.0),
	Vector2(72.0, 0.0), Vector2(-72.0, 0.0),
	Vector2(0.0, 72.0), Vector2(0.0, -72.0),
	Vector2(56.0, 56.0), Vector2(-56.0, 56.0),
	Vector2(56.0, -56.0), Vector2(-56.0, -56.0),
	Vector2(104.0, 0.0), Vector2(-104.0, 0.0),
	Vector2(0.0, 104.0), Vector2(0.0, -104.0),
	Vector2(136.0, 0.0), Vector2(-136.0, 0.0),
	Vector2(0.0, 136.0), Vector2(0.0, -136.0),
	Vector2(136.0, 72.0), Vector2(-136.0, 72.0),
	Vector2(136.0, -72.0), Vector2(-136.0, -72.0),
	Vector2(168.0, 0.0), Vector2(-168.0, 0.0),
	Vector2(0.0, 168.0), Vector2(0.0, -168.0),
]


static func footprint_rect(anchor: Vector2, footprint: Vector2) -> Rect2:
	return Rect2(anchor + Vector2(-footprint.x * 0.5, -footprint.y), footprint)


static func rects_overlap(a: Rect2, b: Rect2, clearance: float = 0.0) -> bool:
	return a.grow(clearance).intersects(b)


static func is_ground_anchor_valid(
	anchor: Vector2,
	footprint: Vector2,
	ground_cells: Dictionary,
	cliff_rects: Array[Rect2]
) -> bool:
	if footprint.x <= 0.0 or footprint.y <= 0.0:
		return false
	var rect := footprint_rect(anchor, footprint)
	for point: Vector2 in [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.position.x, rect.end.y - 1.0),
		Vector2(rect.end.x, rect.end.y - 1.0),
	]:
		var cell := Vector2i(floori(point.x / CELL_SIZE), floori(point.y / CELL_SIZE))
		if not ground_cells.has(cell):
			return false
	for cliff_rect: Rect2 in cliff_rects:
		if rects_overlap(rect, cliff_rect, 1.0):
			return false
	return true


static func is_clear_of_footprints(
	anchor: Vector2,
	footprint: Vector2,
	obstacles: Array[Dictionary],
	clearance: float = 2.0
) -> bool:
	var rect := footprint_rect(anchor, footprint)
	for obstacle: Dictionary in obstacles:
		var obstacle_rect: Rect2 = obstacle.get("rect", Rect2())
		if rects_overlap(rect, obstacle_rect, clearance):
			return false
	return true


static func is_clear_of_visual_occlusion(
	anchor: Vector2,
	footprint: Vector2,
	obstacles: Array[Dictionary],
	clearance: float = 2.0
) -> bool:
	var rect := footprint_rect(anchor, footprint)
	for obstacle: Dictionary in obstacles:
		var occlusion_rect: Rect2 = obstacle.get("occlusion_rect", Rect2())
		if occlusion_rect.has_area() and rects_overlap(rect, occlusion_rect, clearance):
			return false
	return true


static func physics_space_is_clear(main: Node, anchor: Vector2, footprint: Vector2) -> bool:
	if not is_instance_valid(main) or not main.has_method("get_world_2d"):
		return true
	var space_state: PhysicsDirectSpaceState2D = main.get_world_2d().direct_space_state
	if space_state == null:
		return true
	var shape := RectangleShape2D.new()
	shape.size = footprint
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, anchor + Vector2(0.0, -footprint.y * 0.5))
	query.collision_mask = PLACEMENT_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return space_state.intersect_shape(query, 1).is_empty()


static func is_runtime_position_valid(
	world_visuals: Node,
	main: Node,
	anchor: Vector2,
	footprint: Vector2,
	reserved: Array[Dictionary]
) -> bool:
	if not is_instance_valid(world_visuals):
		return false
	if not world_visuals.has_method("is_walkable_ground_anchor"):
		return false
	if not world_visuals.is_walkable_ground_anchor(anchor, footprint):
		return false
	var placement_footprints: Array[Dictionary] = world_visuals.get_placement_footprints()
	if not is_clear_of_footprints(anchor, footprint, placement_footprints):
		return false
	if not is_clear_of_visual_occlusion(anchor, footprint, placement_footprints):
		return false
	if not is_clear_of_footprints(anchor, footprint, reserved):
		return false
	return physics_space_is_clear(main, anchor, footprint)


static func find_runtime_position(
	world_visuals: Node,
	main: Node,
	candidate: Vector2,
	bounds: Rect2,
	footprint: Vector2,
	reserved: Array[Dictionary]
) -> Dictionary:
	for offset: Vector2 in FIXED_OFFSETS:
		var position := candidate + offset
		if not bounds.grow(-maxf(footprint.x, footprint.y)).has_point(position):
			continue
		if not is_runtime_position_valid(world_visuals, main, position, footprint, reserved):
			continue
		return {"valid": true, "position": position}
	return {"valid": false, "position": candidate}
