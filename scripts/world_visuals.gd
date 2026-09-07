extends Node2D
class_name GloamWorldVisuals

## Read-only runtime facade over the scene-authored world.
##
## Terrain cells, cliff collision, props, gates, build spots, spawn markers,
## and approach paths live in .tscn files. This script indexes those authored
## nodes for dynamic gameplay systems without constructing static content.

const VISUALS := preload("res://scripts/visual_constants.gd")
const PLACEMENT := preload("res://scripts/placement_validation.gd")
const ASSETS := preload("res://scripts/tiny_swords_asset_config.gd")
const RESOURCE_PROFILES := preload("res://scripts/resource_profiles.gd")
const ECONOMY_BALANCE := preload("res://scripts/economy_balance.gd")

@onready var lower_terrain: TileMapLayer = $Terrain/LowerTerrain
@onready var village_terrain: TileMapLayer = $Terrain/VillageTerrain
@onready var raised_terrain: TileMapLayer = $Terrain/RaisedTerrain
@onready var cliff_faces: TileMapLayer = $Terrain/CliffFaces
@onready var terrain_collision: StaticBody2D = $Terrain/TerrainCliffCollision
@onready var decorations: Node2D = $Regions

var layout_seed: int = 731941
var walkable_ground_cells: Dictionary = {}
var cliff_rects: Array[Rect2] = []
var placement_footprints: Array[Dictionary] = []
var placement_validation_errors: Array[String] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_index_authored_terrain()
	_index_authored_props()


func set_layout_seed(new_seed: int) -> void:
	layout_seed = new_seed if new_seed != 0 else 731941


func _index_authored_terrain() -> void:
	walkable_ground_cells.clear()
	for layer: TileMapLayer in [lower_terrain, village_terrain, raised_terrain]:
		for cell: Vector2i in layer.get_used_cells():
			walkable_ground_cells[cell] = true
	cliff_rects.clear()
	for child: Node in terrain_collision.get_children():
		var collision := child as CollisionShape2D
		if collision == null or not (collision.shape is RectangleShape2D):
			continue
		var size: Vector2 = (collision.shape as RectangleShape2D).size
		cliff_rects.append(Rect2(collision.global_position - size * 0.5, size))


func _index_authored_props() -> void:
	placement_footprints.clear()
	placement_validation_errors.clear()
	for node: Node in _all_nodes($Regions):
		if not node.has_meta("placement_id"):
			continue
		var anchor := node as Node2D
		var asset_kind := str(node.get("asset_kind"))
		var alignment_profile := ASSETS.prop_profile(asset_kind)
		var footprint: Vector2 = node.get_meta("footprint", Vector2.ZERO)
		var placement_id: String = str(node.get_meta("placement_id", node.name))
		if not PLACEMENT.is_ground_anchor_valid(anchor.global_position, footprint, walkable_ground_cells, cliff_rects):
			placement_validation_errors.append("%s is not on valid walkable ground at %s" % [placement_id, anchor.global_position])
		var rect := PLACEMENT.footprint_rect(anchor.global_position, footprint)
		for existing: Dictionary in placement_footprints:
			if PLACEMENT.rects_overlap(rect, existing["rect"], 1.0):
				placement_validation_errors.append("%s overlaps %s" % [placement_id, existing["id"]])
		placement_footprints.append({
			"id": placement_id,
			"zone": node.get_meta("zone", "wilderness"),
			"kind": alignment_profile["category"],
			"asset": asset_kind,
			"rect": rect,
			"occlusion_rect": _occlusion_rect(anchor, asset_kind),
			"position": anchor.global_position,
			"footprint": footprint,
		})


func _occlusion_rect(anchor: Node2D, asset_kind: String) -> Rect2:
	var profile := ASSETS.prop_profile(asset_kind)
	if str(profile["category"]) in ["tree", "bush"]:
		var alignment := ASSETS.alignment_for_asset(asset_kind, float(profile["visual_scale"]))
		var visible_rect: Rect2 = alignment["visible_rect"]
		return Rect2(anchor.global_position + visible_rect.position, visible_rect.size)
	return Rect2()


func get_resource_layout(seed: int, day: int) -> Array[Dictionary]:
	var layout: Array[Dictionary] = []
	var respawn_counts: Dictionary = ECONOMY_BALANCE.pickup_counts_for_day(day)
	var variation_rng := RandomNumberGenerator.new()
	variation_rng.seed = seed + day * 104729 + 17 * 65537
	var zones: Array[String] = ["forest", "mine", "ruins"]
	for zone_index: int in range(zones.size()):
		var zone: String = zones[zone_index]
		var markers: Array[Node] = _spawn_markers("resource", zone)
		var set_count: int = 0
		for marker: Node in markers:
			set_count = maxi(set_count, int(marker.get("variation_set")) + 1)
		var selected_set: int = posmod(seed + day * 7 + zone_index * 11, maxi(1, set_count))
		var selected_resource_counts: Dictionary = {}
		for marker: Node in markers:
			if int(marker.get("variation_set")) != selected_set:
				continue
			var resource_type: String = str(marker.get("resource_type"))
			var desired_count: int = int((respawn_counts.get(zone, {}) as Dictionary).get(resource_type, 0))
			var selected_count: int = int(selected_resource_counts.get(resource_type, 0))
			if selected_count >= desired_count:
				continue
			selected_resource_counts[resource_type] = selected_count + 1
			var marker_position: Vector2 = (marker as Node2D).global_position
			var position: Vector2 = marker_position + Vector2(
				variation_rng.randf_range(-18.0, 18.0),
				variation_rng.randf_range(-18.0, 18.0)
			)
			var resource_profile := RESOURCE_PROFILES.profile(resource_type)
			if not is_walkable_ground_anchor(position, resource_profile["placement_footprint"]):
				position = marker_position
			layout.append({
				"type": resource_type,
				"position": position,
				"risk_tier": int(marker.get("risk_tier")),
				"zone": zone,
				"depth": int(marker.get("risk_tier")),
			})
	return layout


func get_day_enemy_spawn_positions(zone: String, seed: int, day: int, count: int) -> Array[Vector2]:
	var markers: Array[Node] = _spawn_markers("day_enemy", zone)
	var order: Array[int] = []
	for index: int in range(markers.size()):
		order.append(index)
	var route_rng := RandomNumberGenerator.new()
	route_rng.seed = seed + day * 104729 + (101 + ["forest", "mine", "ruins"].find(zone)) * 65537
	for index: int in range(order.size() - 1, 0, -1):
		var swap_index: int = route_rng.randi_range(0, index)
		var swapped: int = order[index]
		order[index] = order[swap_index]
		order[swap_index] = swapped
	var result: Array[Vector2] = []
	for index: int in range(mini(count, order.size())):
		result.append((markers[order[index]] as Node2D).global_position)
	return result


func choose_night_spawn(lane: String, random_source: RandomNumberGenerator) -> Dictionary:
	var markers: Array[Node] = valid_night_spawn_markers(lane)
	if markers.is_empty():
		return {}
	var marker: Node2D = markers[random_source.randi_range(0, markers.size() - 1)] as Node2D
	var route_id: String = str(marker.get("route_id"))
	return {
		"position": marker.global_position,
		"route_id": route_id,
		"lane": lane,
		"waypoints": get_approach_points(route_id),
	}


func valid_night_spawn_markers(lane: String) -> Array[Node]:
	var result: Array[Node] = []
	for marker: Node in _spawn_markers("night_enemy", lane):
		var route_id: String = str(marker.get("route_id"))
		if route_id.is_empty() or get_approach_points(route_id).size() < 2:
			continue
		result.append(marker)
	return result


func get_night_spawn_edge_position(lane: String) -> Vector2:
	var lanes: Array[String] = []
	if lane == "split":
		lanes.assign(["north", "east"])
	else:
		lanes.append(lane)
	var sum: Vector2 = Vector2.ZERO
	var count: int = 0
	for lane_name: String in lanes:
		for marker: Node in valid_night_spawn_markers(lane_name):
			sum += (marker as Node2D).global_position
			count += 1
	return sum / float(count) if count > 0 else Vector2.ZERO


func get_boss_spawn_position() -> Vector2:
	var markers: Array[Node] = _spawn_markers("night_boss", "north")
	if markers.is_empty():
		push_error("World is missing its authored night_boss spawn marker")
		return Vector2.ZERO
	return (markers[0] as Node2D).global_position


func get_approach_points(route_id: String) -> PackedVector2Array:
	for path: Node in $NightApproaches/ApproachPaths.get_children():
		if path is Path2D and str(path.get_meta("route_id", path.name)) == route_id:
			var points := PackedVector2Array()
			for point: Vector2 in (path as Path2D).curve.get_baked_points():
				points.append((path as Path2D).to_global(point))
			return points
	return PackedVector2Array()


func marker_positions(marker_kind: String) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for marker: Node in _spawn_markers(marker_kind, ""):
		result.append((marker as Node2D).global_position)
	return result


func _spawn_markers(marker_kind: String, lane_or_zone: String) -> Array[Node]:
	var result: Array[Node] = []
	for node: Node in _all_nodes(self):
		if not node.is_in_group("world_spawn_markers"):
			continue
		if str(node.get("marker_kind")) != marker_kind:
			continue
		if not lane_or_zone.is_empty() and str(node.get("lane_or_zone")) != lane_or_zone:
			continue
		result.append(node)
	return result


func get_passage(passage_id: String) -> Node2D:
	for passage: Node in get_tree().get_nodes_in_group("world_passages"):
		if is_ancestor_of(passage) and str(passage.get("passage_id")) == passage_id:
			return passage as Node2D
	return null


func get_placement_footprints() -> Array[Dictionary]:
	return placement_footprints.duplicate(true)


func get_placement_validation_errors() -> Array[String]:
	return placement_validation_errors.duplicate()


func get_vegetation_count(zone: String = "") -> int:
	var count: int = 0
	for placement: Dictionary in placement_footprints:
		if str(placement["kind"]) == "tree" and (zone.is_empty() or str(placement["zone"]) == zone):
			count += 1
	return count


func are_prop_collisions_active() -> bool:
	for node: Node in _all_nodes($Regions):
		if not node.has_meta("placement_id") or not bool(node.get("collision_enabled")):
			continue
		var body := node.get_node_or_null("GroundFootprint") as StaticBody2D
		if body == null or body.collision_layer != VISUALS.PROP_OBSTACLE_LAYER:
			return false
	return true


func is_walkable_ground_anchor(anchor: Vector2, footprint: Vector2) -> bool:
	return PLACEMENT.is_ground_anchor_valid(anchor, footprint, walkable_ground_cells, cliff_rects)


func are_terrain_collisions_active() -> bool:
	return terrain_collision != null and terrain_collision.collision_layer == VISUALS.TERRAIN_OBSTACLE_LAYER and terrain_collision.get_child_count() > 0


func get_terrain_collision_shape_count() -> int:
	return terrain_collision.get_child_count() if terrain_collision != null else 0


func get_terrain_regions() -> Array[Node]:
	return $TerrainRegions.get_children()


func get_terrain_passages() -> Array[Node]:
	return $Passages.get_children()


func _all_nodes(node: Node) -> Array[Node]:
	var result: Array[Node] = [node]
	for child: Node in node.get_children():
		result.append_array(_all_nodes(child))
	return result
