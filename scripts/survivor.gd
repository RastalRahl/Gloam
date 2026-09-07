extends Area2D
class_name GloamSurvivor

const PAWN_IDLE := preload("res://assets/generated/tiny_swords/units/black/pawn/pawn_idle.png")
const VISUAL_FEEDBACK := preload("res://scripts/visual_feedback.gd")
const VISUALS := preload("res://scripts/visual_constants.gd")

var rescued: bool = false

@onready var sprite_visual: GloamAnimatedSpriteVisual = $SpriteVisual as GloamAnimatedSpriteVisual


func _ready() -> void:
    $Visual.hide()
    sprite_visual.configure([
        {"name": "idle", "texture": PAWN_IDLE, "frame_count": 8, "fps": 6.0},
    ])
    sprite_visual.set_visual_scale(VISUALS.UNIT_SPRITE_SCALE)
    sprite_visual.set_sprite_offset(Vector2.ZERO)
    body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
    var player_body: GloamPlayer = body as GloamPlayer
    if rescued or not is_instance_valid(player_body) or player_body.is_downed:
        return

    var main: Node = get_tree().current_scene

    if main.has_method("try_rescue_villager"):
        if main.try_rescue_villager():
            rescued = true
            VISUAL_FEEDBACK.spawn_dust(get_tree().current_scene, global_position, 0.55)
            VISUAL_FEEDBACK.request_audio(self, "survivor_rescued", 0.70)
            queue_free()
