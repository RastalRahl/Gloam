extends Node2D
class_name GloamSoldier

signal killed(role: String)

const WARRIOR_IDLE := preload("res://assets/generated/tiny_swords/units/black/warrior/warrior_idle.png")
const WARRIOR_RUN := preload("res://assets/generated/tiny_swords/units/black/warrior/warrior_run.png")
const WARRIOR_ATTACK := preload("res://assets/generated/tiny_swords/units/black/warrior/warrior_attack_1.png")
const ARCHER_IDLE := preload("res://assets/generated/tiny_swords/units/black/archer/archer_idle.png")
const ARCHER_RUN := preload("res://assets/generated/tiny_swords/units/black/archer/archer_run.png")
const ARCHER_SHOOT := preload("res://assets/generated/tiny_swords/units/black/archer/archer_shoot.png")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const VISUAL_FEEDBACK := preload("res://scripts/visual_feedback.gd")
const VISUALS := preload("res://scripts/visual_constants.gd")

@export_enum("guard", "archer") var role: String = "guard"
@export var max_hp: int = 50
@export var attack_range: float = 90.0
@export var attack_damage: int = 2
@export var attack_interval: float = 0.8
@export var movement_speed: float = 90.0
@export_group("Defense")
@export var defensive_leash_radius: float = 180.0

@onready var attack_timer: Timer = $AttackTimer
@onready var sprite_visual: GloamAnimatedSpriteVisual = $SpriteVisual as GloamAnimatedSpriteVisual

var hp: int
var base_attack_damage: int
var infrastructure_damage_bonus: int = 0
var attack_animation_time: float = 0.0
var facing_left: bool = false
var night_combat_active: bool = false
var home_position: Vector2
var has_home_position: bool = false

const HOME_ARRIVAL_DISTANCE: float = 2.0


func _ready() -> void:
    add_to_group("soldiers")
    hp = max_hp
    base_attack_damage = maxi(0, attack_damage)
    _recalculate_effective_damage()
    home_position = global_position
    has_home_position = true
    $Visual.hide()
    _configure_visual()

    attack_timer.wait_time = attack_interval
    attack_timer.timeout.connect(_try_attack)
    attack_timer.start()


func _process(delta: float) -> void:
    attack_animation_time = maxf(0.0, attack_animation_time - delta)

    if attack_animation_time > 0.0:
        return

    var moving: bool = false
    if night_combat_active:
        moving = _advance_on_nearest_enemy(delta)
    else:
        moving = _return_home(delta)

    if not moving and is_instance_valid(sprite_visual):
        sprite_visual.play_action("idle")


func set_night_combat_active(active: bool) -> void:
    night_combat_active = active


func set_home_position(position: Vector2) -> void:
    home_position = position
    has_home_position = true


func set_infrastructure_damage_bonus(amount: int) -> void:
    infrastructure_damage_bonus = maxi(0, amount)
    _recalculate_effective_damage()


func _recalculate_effective_damage() -> void:
    attack_damage = maxi(0, base_attack_damage + infrastructure_damage_bonus)


func _advance_on_nearest_enemy(delta: float) -> bool:
    var target: Node2D = _nearest_enemy()
    if not is_instance_valid(target):
        return _return_home(delta)

    var distance: float = global_position.distance_to(target.global_position)
    var desired_distance: float = attack_range * (0.72 if role == "archer" else 0.52)
    var minimum_distance: float = attack_range * (0.55 if role == "archer" else 0.0)
    var desired_position: Vector2 = global_position

    if distance > desired_distance:
        var toward_target: Vector2 = global_position.direction_to(target.global_position)
        desired_position = target.global_position - toward_target * desired_distance
    elif role == "archer" and distance < minimum_distance:
        var away_from_target: Vector2 = target.global_position.direction_to(global_position)
        if away_from_target.length_squared() <= 0.001:
            away_from_target = Vector2.UP
        desired_position = target.global_position + away_from_target * minimum_distance
    else:
        return false

    var next_position: Vector2 = global_position.move_toward(
        _clamp_to_defensive_region(desired_position),
        movement_speed * delta
    )
    if next_position.distance_squared_to(global_position) <= 0.0001:
        return false

    var direction: Vector2 = global_position.direction_to(next_position)
    global_position = next_position
    if is_instance_valid(sprite_visual):
        sprite_visual.set_facing_left(direction.x < 0.0)
        sprite_visual.play_action("run")
    return true


func _nearest_enemy() -> Node2D:
    var nearest: Node2D = null
    var nearest_distance: float = INF
    for enemy in get_tree().get_nodes_in_group("enemies"):
        var candidate: Node2D = enemy as Node2D
        if not is_instance_valid(candidate) or not _is_enemy_in_defensive_region(candidate):
            continue
        var distance: float = global_position.distance_to(candidate.global_position)
        if distance < nearest_distance:
            nearest_distance = distance
            nearest = candidate
    return nearest


func _is_enemy_in_defensive_region(enemy: Node2D) -> bool:
    if not has_home_position or not is_instance_valid(enemy):
        return false
    return home_position.distance_to(enemy.global_position) <= maxf(0.0, defensive_leash_radius)


func _clamp_to_defensive_region(position: Vector2) -> Vector2:
    if not has_home_position:
        return position

    var leash_radius: float = maxf(0.0, defensive_leash_radius)
    if leash_radius <= 0.0:
        return home_position

    var offset: Vector2 = position - home_position
    if offset.length_squared() <= leash_radius * leash_radius:
        return position
    return home_position + offset.normalized() * leash_radius


func _return_home(delta: float) -> bool:
    if not has_home_position:
        return false

    var distance_to_home: float = global_position.distance_to(home_position)
    if distance_to_home <= HOME_ARRIVAL_DISTANCE:
        if distance_to_home > 0.0:
            global_position = global_position.move_toward(home_position, movement_speed * delta)
        return false

    var direction: Vector2 = global_position.direction_to(home_position)
    global_position = global_position.move_toward(home_position, movement_speed * delta)
    if is_instance_valid(sprite_visual):
        sprite_visual.set_facing_left(direction.x < 0.0)
        sprite_visual.play_action("run")
    return true


func take_damage(amount: int) -> void:
    hp = maxi(0, hp - amount)

    if hp == 0:
        VISUAL_FEEDBACK.spawn_dust(get_tree().current_scene, global_position, 0.55)
        VISUAL_FEEDBACK.request_audio(self, "soldier_death", 0.65)
        killed.emit(role)
        queue_free()


func _try_attack() -> void:
    var target: Node2D = null
    var nearest_distance: float = INF

    for enemy in get_tree().get_nodes_in_group("enemies"):
        var candidate: Node2D = enemy as Node2D
        if not is_instance_valid(candidate) or not _is_enemy_in_defensive_region(candidate):
            continue

        var distance: float = global_position.distance_to(candidate.global_position)

        if distance <= attack_range and distance < nearest_distance:
            nearest_distance = distance
            target = candidate

    if not is_instance_valid(target):
        return

    var direction: Vector2 = global_position.direction_to(target.global_position)

    if direction.length_squared() <= 0.001:
        return

    _play_attack_visual(direction)

    if role == "archer":
        _shoot_arrow(direction)
    elif target.has_method("take_damage"):
        target.take_damage(attack_damage)


func _configure_visual() -> void:
    if not is_instance_valid(sprite_visual):
        return

    sprite_visual.set_visual_scale(VISUALS.UNIT_SPRITE_SCALE)
    sprite_visual.set_sprite_offset(Vector2.ZERO)

    if role == "archer":
        sprite_visual.configure([
            {"name": "idle", "texture": ARCHER_IDLE, "frame_count": 6, "fps": 8.0},
            {"name": "run", "texture": ARCHER_RUN, "frame_count": 4, "fps": 10.0},
            {"name": "attack", "texture": ARCHER_SHOOT, "frame_count": 8, "fps": 15.0, "loop": false},
        ])
    else:
        sprite_visual.configure([
            {"name": "idle", "texture": WARRIOR_IDLE, "frame_count": 8, "fps": 8.0},
            {"name": "run", "texture": WARRIOR_RUN, "frame_count": 6, "fps": 10.0},
            {"name": "attack", "texture": WARRIOR_ATTACK, "frame_count": 4, "fps": 13.0, "loop": false},
        ])



func _play_attack_visual(direction: Vector2) -> void:
    if not is_instance_valid(sprite_visual):
        return

    facing_left = direction.x < 0.0
    sprite_visual.set_facing_left(facing_left)
    sprite_visual.play_action("attack")
    attack_animation_time = minf(attack_interval, 0.55)


func _shoot_arrow(direction: Vector2) -> void:
    var projectile: GloamProjectile = PROJECTILE_SCENE.instantiate() as GloamProjectile
    projectile.global_position = global_position + direction * 20.0
    projectile.setup(direction, attack_damage, 460.0, 0, 0, 0.0, 0.0, 0.0)
    get_tree().current_scene.add_child(projectile)
