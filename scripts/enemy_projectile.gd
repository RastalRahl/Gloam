extends Node2D
class_name GloamEnemyProjectile

const BONE_TEXTURE := preload("res://assets/generated/tiny_swords/enemies/gnoll/gnoll_bone.png")
const VISUALS := preload("res://scripts/visual_constants.gd")

@export var lifetime: float = 1.8

var target: Node2D
var direction: Vector2 = Vector2.RIGHT
var damage: int = 1
var speed: float = 310.0
var age: float = 0.0

@onready var sprite_visual: GloamAnimatedSpriteVisual = $SpriteVisual as GloamAnimatedSpriteVisual


func _ready() -> void:
	sprite_visual.configure([
		{"name": "fly", "texture": BONE_TEXTURE, "frame_count": 4, "fps": 12.0},
	], "fly")
	sprite_visual.set_visual_scale(VISUALS.PROJECTILE_SPRITE_SCALE)


func setup(new_target: Node2D, new_direction: Vector2, new_damage: int, new_speed: float) -> void:
	target = new_target
	direction = new_direction.normalized()
	damage = new_damage
	speed = new_speed


func _physics_process(delta: float) -> void:
	age += delta

	if age >= lifetime or not is_instance_valid(target):
		queue_free()
		return

	var next_position: Vector2 = global_position + direction * speed * delta
	var obstacle_hit: Dictionary = _first_permanent_obstacle(global_position, next_position)
	if not obstacle_hit.is_empty():
		var collider: Node = obstacle_hit.get("collider") as Node
		if _collider_belongs_to_target(collider) and target.has_method("take_damage"):
			target.take_damage(damage)
		queue_free()
		return

	global_position = next_position
	rotation = direction.angle()

	if global_position.distance_to(target.global_position) <= maxf(18.0, speed * delta):
		if target.has_method("take_damage"):
			target.take_damage(damage)

		queue_free()


func _first_permanent_obstacle(from: Vector2, to: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(
		from,
		to,
		VISUALS.TERRAIN_OBSTACLE_LAYER | VISUALS.PROP_OBSTACLE_LAYER | VISUALS.GATE_OBSTACLE_LAYER
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_2d().direct_space_state.intersect_ray(query)


func _collider_belongs_to_target(collider: Node) -> bool:
	if not is_instance_valid(collider) or not is_instance_valid(target):
		return false
	if collider == target:
		return true
	var ancestor: Node = collider.get_parent()
	while is_instance_valid(ancestor):
		if ancestor == target:
			return true
		ancestor = ancestor.get_parent()
	return false
