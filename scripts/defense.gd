extends Node2D
class_name GloamDefense

signal destroyed(defense: Node)

const TOWER_TEXTURE := preload("res://assets/generated/tiny_swords/buildings/black/tower.png")
const ARCHERY_TEXTURE := preload("res://assets/generated/tiny_swords/buildings/black/archery.png")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const VISUAL_FEEDBACK := preload("res://scripts/visual_feedback.gd")
const VISUALS := preload("res://scripts/visual_constants.gd")
const GROUND_FOOTPRINT := preload("res://scripts/ground_footprint.gd")

@export var defense_name: String = "Defense"
@export var max_hp: int = 50
@export var attack_range: float = 0.0
@export var attack_damage: int = 0
@export var attack_interval: float = 1.0
@export var max_level: int = 3
@export_enum("tower", "barricade", "ballista") var visual_profile: String = "tower"
@export var projectile_speed: float = 460.0
@export var projectile_scale: float = VISUALS.PROJECTILE_SPRITE_SCALE

@onready var attack_timer: Timer = $AttackTimer
@onready var sprite_visual: GloamStaticSpriteVisual = get_node_or_null("SpriteVisual") as GloamStaticSpriteVisual
@onready var fortification_art: Sprite2D = get_node_or_null("FortificationArt") as Sprite2D

var hp: int
var level: int = 1


func _ready() -> void:
    add_to_group("defenses")
    hp = max_hp
    if visual_profile == "ballista":
        projectile_scale = VISUALS.BALLISTA_PROJECTILE_SCALE
    _ensure_foundation_footprint()
    _hide_legacy_visual()
    _configure_visual()

    attack_timer.wait_time = attack_interval
    attack_timer.one_shot = false

    if attack_range > 0.0 and attack_damage > 0:
        attack_timer.timeout.connect(_try_attack)
        attack_timer.start()


func take_damage(amount: int) -> void:
    hp = maxi(0, hp - amount)

    if hp <= 0:
        VISUAL_FEEDBACK.request_audio(self, "structure_destroyed", 0.85)
        destroyed.emit(self)
        queue_free()
    else:
        VISUAL_FEEDBACK.request_audio(self, "structure_damage", 0.45)


func repair_full() -> void:
    hp = max_hp


func can_upgrade() -> bool:
    return level < max_level


func upgrade() -> void:
    if not can_upgrade():
        return

    level += 1
    max_hp = int(round(max_hp * 1.30))
    hp = max_hp

    if attack_damage > 0:
        attack_damage += 1
        attack_range += 18.0
        attack_interval = maxf(0.20, attack_interval * 0.88)
        attack_timer.wait_time = attack_interval


func _try_attack() -> void:
    if attack_range <= 0.0 or attack_damage <= 0:
        return

    var best_enemy: Node2D = null
    var best_distance: float = INF

    for enemy in get_tree().get_nodes_in_group("enemies"):
        if not is_instance_valid(enemy):
            continue

        var d: float = global_position.distance_to(enemy.global_position)

        if d <= attack_range and d < best_distance:
            best_distance = d
            best_enemy = enemy

    if not is_instance_valid(best_enemy):
        return

    var direction: Vector2 = global_position.direction_to(best_enemy.global_position)

    if direction.length_squared() <= 0.001:
        return

    _show_attack_feedback()

    var projectile: GloamProjectile = PROJECTILE_SCENE.instantiate() as GloamProjectile
    projectile.global_position = global_position + direction * 18.0
    projectile.scale = Vector2.ONE * projectile_scale
    projectile.setup(direction, attack_damage, projectile_speed, 0, 0, 0.0, 0.0, 0.0)
    projectile.set_source(self)
    get_tree().current_scene.add_child(projectile)
    VISUAL_FEEDBACK.request_audio(self, "defense_attack", 0.45)


func _hide_legacy_visual() -> void:
    var legacy_visual: CanvasItem = get_node_or_null("Visual") as CanvasItem

    if is_instance_valid(legacy_visual):
        legacy_visual.hide()


func _configure_visual() -> void:
    if visual_profile == "barricade":
        if is_instance_valid(fortification_art):
            fortification_art.centered = true
            fortification_art.region_rect = Rect2(320, 256, 192, 128)
            fortification_art.scale = Vector2.ONE * VISUALS.FORTIFICATION_SPRITE_SCALE
            fortification_art.position = Vector2(0.0, -32.0)
            fortification_art.modulate = Color.WHITE
        return

    if not is_instance_valid(sprite_visual):
        return

    if visual_profile == "ballista":
        sprite_visual.configure(ARCHERY_TEXTURE, VISUALS.DEFENSE_SPRITE_SCALE)
    else:
        sprite_visual.configure(TOWER_TEXTURE, VISUALS.DEFENSE_SPRITE_SCALE)


func _ensure_foundation_footprint() -> void:
    var footprint_size := VISUALS.DEFENSE_FOOTPRINT
    if visual_profile == "ballista":
        footprint_size = Vector2(96, 18)
    elif visual_profile == "barricade":
        footprint_size = Vector2(64, 16)
    var footprint := GROUND_FOOTPRINT.new().setup(footprint_size)
    footprint.name = "FoundationFootprint"
    add_child(footprint)


func _show_attack_feedback() -> void:
    var visual: CanvasItem = sprite_visual if is_instance_valid(sprite_visual) else fortification_art

    if not is_instance_valid(visual):
        return

    var original_tint: Color = visual.modulate
    visual.modulate = Color(1.0, 0.84, 0.52, 1.0)
    var tween: Tween = create_tween()
    tween.tween_property(visual, "modulate", original_tint, 0.14)
