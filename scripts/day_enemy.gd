extends CharacterBody2D
class_name GloamDayEnemy

const XP_ORB_SCENE := preload("res://scenes/xp_orb.tscn")
const VISUAL_FEEDBACK := preload("res://scripts/visual_feedback.gd")
const GIANT_BAT_IDLE := preload("res://assets/generated/tiny_swords/enemies/giant_bat/giant_bat_idle.png")
const GIANT_BAT_MOVE := preload("res://assets/generated/tiny_swords/enemies/giant_bat/giant_bat_move.png")
const GIANT_BAT_ATTACK := preload("res://assets/generated/tiny_swords/enemies/giant_bat/giant_bat_attack.png")
const SPIDER_IDLE := preload("res://assets/generated/tiny_swords/enemies/spider/spider_idle.png")
const SPIDER_RUN := preload("res://assets/generated/tiny_swords/enemies/spider/spider_run.png")
const SPIDER_ATTACK := preload("res://assets/generated/tiny_swords/enemies/spider/spider_attack.png")
const SKULL_IDLE := preload("res://assets/generated/tiny_swords/enemies/skull/skull_idle.png")
const SKULL_RUN := preload("res://assets/generated/tiny_swords/enemies/skull/skull_run.png")
const SKULL_ATTACK := preload("res://assets/generated/tiny_swords/enemies/skull/skull_attack.png")
const ECONOMY_BALANCE := preload("res://scripts/economy_balance.gd")
const VISUALS := preload("res://scripts/visual_constants.gd")

@export var enemy_name: String = "Wild Creature"
@export_enum("forest", "mine", "ruins") var zone_type: String = "forest"
@export_enum("giant_bat", "spider", "skull") var visual_profile: String = "giant_bat"

@export var move_speed: float = 90.0
@export var max_hp: int = 3
@export var attack_damage: int = 5
@export var attack_interval: float = 0.9
@export var attack_distance: float = 28.0
@export var aggro_radius: float = 230.0
@export var leash_radius: float = 360.0
@export var xp_value: int = 1

@export var reward_resource: String = ""
@export var reward_amount: int = 0
@export var bonus_resource: String = ""
@export var bonus_chance: float = 0.0

var player: GloamPlayer
var spawn_position: Vector2
var hp: int
var attack_cooldown: float = 0.0
var engaged: bool = false

var slow_multiplier: float = 1.0
var slow_time_left: float = 0.0

var burn_damage_per_tick: int = 0
var burn_ticks_left: int = 0
var burn_tick_time: float = 0.0

var knockback_velocity: Vector2 = Vector2.ZERO
var stagger_time_left: float = 0.0

var health_bar_bg: ColorRect
var health_bar_fill: ColorRect
var attack_animation_time: float = 0.0
var facing_left: bool = false

@onready var sprite_visual: GloamAnimatedSpriteVisual = $SpriteVisual as GloamAnimatedSpriteVisual


func _ready() -> void:
    add_to_group("enemies")
    add_to_group("day_enemies")
    var reward_profile: Dictionary = ECONOMY_BALANCE.enemy_reward_profile(zone_type)
    reward_resource = str(reward_profile.get("resource", reward_resource))
    reward_amount = int(reward_profile.get("amount", reward_amount))
    bonus_resource = str(reward_profile.get("bonus_resource", bonus_resource))
    bonus_chance = float(reward_profile.get("bonus_chance", bonus_chance))
    hp = max_hp
    spawn_position = global_position
    _ensure_combat_colliders()
    _hide_legacy_visuals()
    _configure_visual()
    _setup_health_bar()


func _ensure_combat_colliders() -> void:
    collision_layer = 0
    collision_mask = 0
    var movement_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
    var footprint := VISUALS.ORDINARY_FOOTPRINT
    if visual_profile == "giant_bat" or visual_profile == "spider":
        footprint = Vector2(24, 10)
    elif visual_profile == "skull":
        footprint = Vector2(18, 10)
    if is_instance_valid(movement_shape):
        var rectangle := RectangleShape2D.new()
        rectangle.size = footprint
        movement_shape.shape = rectangle
        movement_shape.position = Vector2(0.0, -footprint.y * 0.5)
    var hurtbox := Area2D.new()
    hurtbox.name = "Hurtbox"
    hurtbox.collision_layer = 2
    hurtbox.collision_mask = 0
    hurtbox.monitorable = true
    var hurt_shape := CollisionShape2D.new()
    var hurt_rectangle := RectangleShape2D.new()
    var hurt_size := Vector2(44, 48) if visual_profile == "giant_bat" else Vector2(36, 44)
    hurt_rectangle.size = hurt_size
    hurt_shape.shape = hurt_rectangle
    hurt_shape.position = Vector2(0.0, -hurt_size.y * 0.5)
    hurtbox.add_child(hurt_shape)
    add_child(hurtbox)


func _process(delta: float) -> void:
    attack_animation_time = maxf(0.0, attack_animation_time - delta)

    if not is_instance_valid(sprite_visual):
        return

    if absf(velocity.x) > 1.0:
        facing_left = velocity.x < 0.0
        sprite_visual.set_facing_left(facing_left)

    if attack_animation_time <= 0.0:
        sprite_visual.play_action("run" if velocity.length_squared() > 4.0 else "idle")


func set_player(new_player: GloamPlayer) -> void:
    player = new_player


func _physics_process(delta: float) -> void:
    _update_status_effects(delta)

    if hp <= 0:
        return

    attack_cooldown = maxf(0.0, attack_cooldown - delta)

    if knockback_velocity.length_squared() > 1.0:
        velocity = knockback_velocity
        knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 430.0 * delta)
        move_and_slide()
        return

    if stagger_time_left > 0.0:
        velocity = Vector2.ZERO
        return

    if not is_instance_valid(player):
        velocity = Vector2.ZERO
        return

    var distance_to_player: float = global_position.distance_to(player.global_position)
    var distance_from_home: float = global_position.distance_to(spawn_position)

    if distance_to_player <= aggro_radius:
        engaged = true

    if engaged and distance_from_home > leash_radius and distance_to_player > aggro_radius:
        engaged = false

    if not engaged:
        if distance_from_home > 8.0:
            velocity = global_position.direction_to(spawn_position) * move_speed * 0.65
            move_and_slide()
        else:
            velocity = Vector2.ZERO
        return

    if distance_to_player <= attack_distance:
        velocity = Vector2.ZERO

        if attack_cooldown <= 0.0:
            var player_is_downed: bool = player.is_downed

            _play_attack_visual(player.global_position)

            if not player_is_downed and player.has_method("take_damage"):
                player.take_damage(attack_damage)

            attack_cooldown = attack_interval

        return

    velocity = global_position.direction_to(player.global_position) * move_speed * slow_multiplier
    move_and_slide()


func _update_status_effects(delta: float) -> void:
    if stagger_time_left > 0.0:
        stagger_time_left = maxf(0.0, stagger_time_left - delta)

    if slow_time_left > 0.0:
        slow_time_left -= delta

        if slow_time_left <= 0.0:
            slow_multiplier = 1.0

    if burn_ticks_left > 0:
        burn_tick_time -= delta

        if burn_tick_time <= 0.0:
            burn_tick_time = 1.0
            burn_ticks_left -= 1
            take_damage(burn_damage_per_tick)


func apply_burn(damage_per_tick: int, ticks: int) -> void:
    burn_damage_per_tick = maxi(burn_damage_per_tick, damage_per_tick)
    burn_ticks_left = maxi(burn_ticks_left, ticks)
    burn_tick_time = minf(burn_tick_time, 0.25) if burn_tick_time > 0.0 else 0.25


func apply_slow(strength: float, duration: float) -> void:
    slow_multiplier = minf(slow_multiplier, maxf(0.25, 1.0 - strength))
    slow_time_left = maxf(slow_time_left, duration)


func apply_knockback(force: Vector2) -> void:
    knockback_velocity += force


func apply_stagger(duration: float) -> void:
    stagger_time_left = maxf(stagger_time_left, duration)


func take_damage(amount: int) -> void:
    if hp <= 0:
        return

    hp = maxi(0, hp - amount)
    _show_hit_feedback()
    _update_health_bar()

    if hp <= 0:
        _die()



func _setup_health_bar() -> void:
    health_bar_bg = ColorRect.new()
    health_bar_bg.position = Vector2(-18, -25)
    health_bar_bg.size = Vector2(36, 5)
    health_bar_bg.color = Color(0.08, 0.08, 0.08, 0.90)
    health_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    health_bar_bg.z_index = 10
    health_bar_bg.hide()
    add_child(health_bar_bg)

    health_bar_fill = ColorRect.new()
    health_bar_fill.position = Vector2(1, 1)
    health_bar_fill.size = Vector2(34, 3)
    health_bar_fill.color = Color(0.82, 0.18, 0.16, 1.0)
    health_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    health_bar_bg.add_child(health_bar_fill)


func _update_health_bar() -> void:
    if not is_instance_valid(health_bar_bg) or not is_instance_valid(health_bar_fill):
        return

    var ratio: float = clampf(float(hp) / float(max_hp), 0.0, 1.0)
    health_bar_fill.size = Vector2(34.0 * ratio, 3.0)
    health_bar_bg.visible = hp > 0 and hp < max_hp


func _show_hit_feedback() -> void:
    var body_visual: CanvasItem = sprite_visual

    if not is_instance_valid(body_visual):
        body_visual = get_node_or_null("Visual") as CanvasItem

    if not is_instance_valid(body_visual):
        return

    body_visual.modulate = Color(1.0, 0.72, 0.48, 1.0)

    var tween: Tween = create_tween()
    tween.tween_property(body_visual, "modulate", Color.WHITE, 0.12)
    VISUAL_FEEDBACK.request_audio(self, "enemy_hit", 0.40)


func _hide_legacy_visuals() -> void:
    for visual_name: String in ["Shadow", "Outline", "Visual", "Core", "Eye"]:
        var legacy_visual: CanvasItem = get_node_or_null(visual_name) as CanvasItem

        if is_instance_valid(legacy_visual):
            legacy_visual.hide()


func _configure_visual() -> void:
    if not is_instance_valid(sprite_visual):
        return

    sprite_visual.set_visual_scale(VISUALS.UNIT_SPRITE_SCALE)
    sprite_visual.set_sprite_offset(Vector2.ZERO)

    match visual_profile:
        "spider":
            sprite_visual.configure([
                {"name": "idle", "texture": SPIDER_IDLE, "frame_count": 8, "fps": 8.0},
                {"name": "run", "texture": SPIDER_RUN, "frame_count": 5, "fps": 10.0},
                {"name": "attack", "texture": SPIDER_ATTACK, "frame_count": 8, "fps": 15.0, "loop": false},
            ])
        "skull":
            sprite_visual.configure([
                {"name": "idle", "texture": SKULL_IDLE, "frame_count": 8, "fps": 8.0},
                {"name": "run", "texture": SKULL_RUN, "frame_count": 6, "fps": 10.0},
                {"name": "attack", "texture": SKULL_ATTACK, "frame_count": 7, "fps": 13.0, "loop": false},
            ])
        _:
            sprite_visual.configure([
                {"name": "idle", "texture": GIANT_BAT_IDLE, "frame_count": 6, "fps": 8.0},
                {"name": "run", "texture": GIANT_BAT_MOVE, "frame_count": 4, "fps": 11.0},
                {"name": "attack", "texture": GIANT_BAT_ATTACK, "frame_count": 7, "fps": 14.0, "loop": false},
            ])


func _play_attack_visual(target_position: Vector2) -> void:
    if not is_instance_valid(sprite_visual):
        return

    facing_left = target_position.x < global_position.x
    sprite_visual.set_facing_left(facing_left)
    sprite_visual.play_action("attack")
    attack_animation_time = minf(attack_interval, 0.55)


func _die() -> void:
    VISUAL_FEEDBACK.spawn_death_burst(get_tree().current_scene, global_position, 0.68)
    VISUAL_FEEDBACK.request_audio(self, "enemy_death", 0.70)
    var orb: GloamXpOrb = XP_ORB_SCENE.instantiate() as GloamXpOrb
    orb.global_position = global_position
    orb.xp_value = xp_value
    get_tree().current_scene.call_deferred("add_child", orb)

    var main: Node = get_tree().current_scene

    if main.has_method("grant_exploration_reward"):
        main.grant_exploration_reward(reward_resource, reward_amount)

        if bonus_resource != "" and randf() < bonus_chance:
            main.grant_exploration_reward(bonus_resource, 1)

    queue_free()
