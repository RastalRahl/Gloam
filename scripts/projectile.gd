extends Area2D
class_name GloamProjectile

const ARROW_TEXTURE := preload("res://assets/generated/tiny_swords/units/black/archer/arrow.png")
const EFFECT_SCENE := preload("res://scenes/components/one_shot_effect_visual.tscn")
const EXPLOSION_EFFECT := preload("res://assets/generated/tiny_swords/effects/explosion_01.png")
const FIRE_EFFECT := preload("res://assets/generated/tiny_swords/effects/fire_01.png")
const WATER_EFFECT := preload("res://assets/generated/tiny_swords/effects/water_splash.png")
const DUST_EFFECT := preload("res://assets/generated/tiny_swords/effects/dust_01.png")
const VISUALS := preload("res://scripts/visual_constants.gd")

@export var lifetime: float = 1.6

var direction: Vector2 = Vector2.RIGHT
var speed: float = 520.0
var damage: int = 1
var age: float = 0.0

var burn_damage: int = 0
var burn_ticks: int = 0

var slow_strength: float = 0.0
var slow_duration: float = 0.0

var knockback_force: float = 0.0
var stagger_duration: float = 0.0
var fire_spread_radius: float = 0.0
var fire_spread_damage: int = 0
var fire_spread_ticks: int = 0
var source_node: Node


func _ready() -> void:
    $Trail.hide()
    $Outline.hide()
    $Visual.hide()
    var sprite_visual: GloamProjectileSpriteVisual = $SpriteVisual as GloamProjectileSpriteVisual
    sprite_visual.configure(ARROW_TEXTURE)
    body_entered.connect(_on_body_entered)
    area_entered.connect(_on_area_entered)


func setup(
    new_direction: Vector2,
    new_damage: int,
    new_speed: float,
    new_burn_damage: int,
    new_burn_ticks: int,
    new_slow_strength: float,
    new_slow_duration: float,
    new_knockback_force: float,
    new_stagger_duration: float = 0.0,
    new_fire_spread_radius: float = 0.0,
    new_fire_spread_damage: int = 0,
    new_fire_spread_ticks: int = 0
) -> void:
    direction = new_direction.normalized()
    damage = new_damage
    speed = new_speed

    burn_damage = new_burn_damage
    burn_ticks = new_burn_ticks

    slow_strength = new_slow_strength
    slow_duration = new_slow_duration

    knockback_force = new_knockback_force
    stagger_duration = new_stagger_duration
    fire_spread_radius = new_fire_spread_radius
    fire_spread_damage = new_fire_spread_damage
    fire_spread_ticks = new_fire_spread_ticks


func set_source(new_source: Node) -> void:
    source_node = new_source


func _physics_process(delta: float) -> void:
    var next_position: Vector2 = global_position + direction * speed * delta
    var obstacle_hit: Dictionary = _first_permanent_obstacle(global_position, next_position)
    if not obstacle_hit.is_empty():
        global_position = obstacle_hit["position"]
        queue_free()
        return

    global_position = next_position
    rotation = direction.angle()

    age += delta

    if age >= lifetime:
        queue_free()


func _first_permanent_obstacle(from: Vector2, to: Vector2) -> Dictionary:
    var query := PhysicsRayQueryParameters2D.create(
        from,
        to,
		VISUALS.TERRAIN_OBSTACLE_LAYER | VISUALS.PROP_OBSTACLE_LAYER | VISUALS.GATE_OBSTACLE_LAYER,
        _source_collision_rids()
    )
    query.collide_with_areas = false
    query.collide_with_bodies = true
    return get_world_2d().direct_space_state.intersect_ray(query)


func _source_collision_rids() -> Array[RID]:
    var result: Array[RID] = []
    if is_instance_valid(source_node):
        _append_collision_rids(source_node, result)
    return result


func _append_collision_rids(node: Node, result: Array[RID]) -> void:
    var collision_object := node as CollisionObject2D
    if is_instance_valid(collision_object):
        result.append(collision_object.get_rid())
    for child: Node in node.get_children():
        _append_collision_rids(child, result)


func _on_body_entered(body: Node) -> void:
    _hit_target(body)


func _on_area_entered(area: Area2D) -> void:
    _hit_target(area.get_parent() if is_instance_valid(area) else null)


func _hit_target(target: Node) -> void:
    if is_instance_valid(target) and target.has_method("take_damage"):
        target.take_damage(damage)

        if burn_damage > 0 and burn_ticks > 0 and target.has_method("apply_burn"):
            target.apply_burn(burn_damage, burn_ticks)

        if slow_strength > 0.0 and slow_duration > 0.0 and target.has_method("apply_slow"):
            target.apply_slow(slow_strength, slow_duration)

        if knockback_force > 0.0 and target.has_method("apply_knockback"):
            target.apply_knockback(direction * knockback_force)

        if stagger_duration > 0.0 and target.has_method("apply_stagger"):
            target.apply_stagger(stagger_duration)

        _apply_fire_spread(target)

        _spawn_impact_effect(target.global_position)
        queue_free()


func _apply_fire_spread(source: Node) -> void:
    if fire_spread_radius <= 0.0 or fire_spread_damage <= 0 or fire_spread_ticks <= 0:
        return

    for enemy: Node in get_tree().get_nodes_in_group("enemies"):
        if enemy == source or not is_instance_valid(enemy) or not enemy.has_method("apply_burn"):
            continue
        if int(enemy.get("hp")) <= 0:
            continue
        if source.global_position.distance_to(enemy.global_position) > fire_spread_radius:
            continue
        enemy.apply_burn(fire_spread_damage, fire_spread_ticks)


func _spawn_impact_effect(impact_position: Vector2) -> void:
    var effect: GloamOneShotEffectVisual = EFFECT_SCENE.instantiate() as GloamOneShotEffectVisual
    effect.global_position = impact_position
    effect.z_index = 8

    var texture: Texture2D = EXPLOSION_EFFECT
    var tint: Color = Color(0.96, 0.78, 0.38, 1.0)
    var scale: float = VISUALS.IMPACT_EFFECT_SCALE

    if burn_ticks > 0:
        texture = FIRE_EFFECT
        tint = Color(1.0, 0.45, 0.20, 1.0)
        scale = VISUALS.ELEMENTAL_EFFECT_SCALE
    elif slow_strength > 0.0:
        texture = WATER_EFFECT
        tint = Color(0.45, 0.78, 1.0, 1.0)
        scale = VISUALS.ELEMENTAL_EFFECT_SCALE
    elif knockback_force > 0.0:
        texture = DUST_EFFECT
        tint = Color(0.73, 0.66, 0.50, 1.0)
        scale = VISUALS.DUST_EFFECT_SCALE

    get_tree().current_scene.add_child(effect)
    effect.set_visual_scale(scale)
    effect.set_visual_tint(tint)
    effect.configure([
        {"name": "effect", "texture": texture, "frame_count": 8, "fps": 18.0, "loop": false}
    ], "effect")
