extends Node2D
class_name GloamCollisionDebugOverlay

## Toggleable collision inspection for the live world (F7). Colors communicate
## semantic ownership rather than raw physics layers, so terrain never looks
## interchangeable with a prop, actor footprint, or interaction trigger.

const TERRAIN_COLOR := Color(0.20, 0.78, 1.00, 0.96)
const PROP_COLOR := Color(0.92, 0.38, 0.96, 0.96)
const GATE_COLOR := Color(1.00, 0.55, 0.16, 0.96)
const ENTITY_COLOR := Color(0.28, 0.96, 0.48, 0.96)
const HURTBOX_COLOR := Color(1.00, 0.25, 0.22, 0.96)
const INTERACTION_COLOR := Color(1.00, 0.80, 0.18, 0.96)
const TEMPORARY_COLOR := Color(0.72, 0.42, 1.00, 0.96)

var scene_root: Node
var enabled: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_as_relative = false
	z_index = 4096
	scene_root = get_parent()
	visible = false
	set_process_unhandled_input(true)


func configure(new_scene_root: Node) -> void:
	scene_root = new_scene_root
	set_enabled(true)


func set_enabled(new_enabled: bool) -> void:
	enabled = new_enabled
	visible = enabled
	if enabled:
		queue_redraw()


func is_enabled() -> bool:
	return enabled


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_collision_debug") and not event.is_echo():
		set_enabled(not enabled)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if enabled:
		queue_redraw()


func _draw() -> void:
	if not enabled or not is_instance_valid(scene_root):
		return
	for node: Node in _all_nodes(scene_root):
		var collision := node as CollisionShape2D
		if not is_instance_valid(collision) or collision.disabled or collision.shape == null:
			continue
		var owner := collision.get_parent() as CollisionObject2D
		# Static footprints on layer zero are non-blocking by contract (open gates,
		# decorative props, and breaches), so do not present them as physical walls.
		if owner is StaticBody2D and owner.collision_layer == 0:
			continue
		_draw_collision_shape(collision, _collision_color(collision.get_parent()))
	_draw_legend()


func _draw_collision_shape(collision: CollisionShape2D, color: Color) -> void:
	var draw_transform: Transform2D = global_transform.affine_inverse() * collision.global_transform
	draw_set_transform_matrix(draw_transform)
	if collision.shape is RectangleShape2D:
		var size: Vector2 = (collision.shape as RectangleShape2D).size
		draw_rect(Rect2(-size * 0.5, size), color, false, 2.5)
	elif collision.shape is CircleShape2D:
		draw_circle(Vector2.ZERO, (collision.shape as CircleShape2D).radius, color, false, 2.5)
	elif collision.shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = collision.shape as CapsuleShape2D
		var half_body: float = maxf(0.0, (capsule.height - capsule.radius * 2.0) * 0.5)
		draw_line(Vector2(-capsule.radius, -half_body), Vector2(-capsule.radius, half_body), color, 2.5)
		draw_line(Vector2(capsule.radius, -half_body), Vector2(capsule.radius, half_body), color, 2.5)
		draw_arc(Vector2(0.0, -half_body), capsule.radius, PI, TAU, 24, color, 2.5)
		draw_arc(Vector2(0.0, half_body), capsule.radius, 0.0, PI, 24, color, 2.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _collision_color(owner: Node) -> Color:
	var category: String = str(owner.get_meta("collision_category", ""))
	if category == "terrain" or owner.is_in_group("terrain_collision"):
		return TERRAIN_COLOR
	if category == "temporary" or owner.is_in_group("temporary_gameplay_collision"):
		return TEMPORARY_COLOR
	if category == "gate" or owner.is_in_group("gate_collision"):
		return GATE_COLOR
	if category == "prop" or owner.is_in_group("prop_collision") or owner is StaticBody2D:
		return PROP_COLOR
	if owner is CharacterBody2D:
		return ENTITY_COLOR
	if owner is Area2D:
		return HURTBOX_COLOR if owner.name == "Hurtbox" else INTERACTION_COLOR
	return ENTITY_COLOR


func _draw_legend() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var origin: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * Vector2(18.0, viewport_size.y - 143.0)
	var legend_rect := Rect2(origin, Vector2(430.0, 125.0))
	draw_rect(legend_rect, Color(0.035, 0.055, 0.075, 0.90), true)
	draw_rect(legend_rect, Color(0.76, 0.68, 0.50, 0.88), false, 2.0)
	draw_string(ThemeDB.fallback_font, origin + Vector2(12.0, 20.0), "F7 COLLISION CONTRACT", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(0.94, 0.89, 0.76))
	var entries: Array = [
		["terrain / cliff", TERRAIN_COLOR], ["prop footprints", PROP_COLOR],
		["gates", GATE_COLOR], ["entity movement", ENTITY_COLOR], ["hurtboxes", HURTBOX_COLOR],
		["interaction areas", INTERACTION_COLOR], ["temporary blockers", TEMPORARY_COLOR],
	]
	for index: int in range(entries.size()):
		var column: int = index % 3
		var row: int = index / 3
		var item_origin := origin + Vector2(12.0 + column * 140.0, 40.0 + row * 27.0)
		draw_line(item_origin, item_origin + Vector2(18.0, 0.0), entries[index][1], 4.0)
		draw_string(ThemeDB.fallback_font, item_origin + Vector2(24.0, 5.0), entries[index][0], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color.WHITE)


func _all_nodes(node: Node) -> Array[Node]:
	var result: Array[Node] = [node]
	for child: Node in node.get_children():
		result.append_array(_all_nodes(child))
	return result
