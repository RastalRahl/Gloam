extends RefCounted
class_name GloamVisualFeedback

const EFFECT_SCENE := preload("res://scenes/components/one_shot_effect_visual.tscn")
const DUST_EFFECT := preload("res://assets/generated/tiny_swords/effects/dust_01.png")
const EXPLOSION_EFFECT := preload("res://assets/generated/tiny_swords/effects/explosion_01.png")


static func spawn_dust(parent: Node, position: Vector2, scale_amount: float = 0.60) -> void:
    _spawn_effect(parent, position, DUST_EFFECT, Color(0.70, 0.64, 0.56, 0.90), scale_amount)


static func spawn_death_burst(parent: Node, position: Vector2, scale_amount: float = 0.72) -> void:
    _spawn_effect(parent, position, EXPLOSION_EFFECT, Color(0.94, 0.56, 0.36, 0.92), scale_amount)
    spawn_dust(parent, position, scale_amount * 0.9)


static func request_audio(source: Node, event_name: String, intensity: float = 1.0) -> void:
    if not is_instance_valid(source) or source.get_tree() == null:
        return

    var main: Node = source.get_tree().current_scene

    if is_instance_valid(main) and main.has_method("play_audio_hook"):
        main.play_audio_hook(event_name, source.global_position, intensity)


static func _spawn_effect(parent: Node, position: Vector2, texture: Texture2D, tint: Color, scale_amount: float) -> void:
    if not is_instance_valid(parent):
        return

    var effect: GloamOneShotEffectVisual = EFFECT_SCENE.instantiate() as GloamOneShotEffectVisual
    effect.global_position = position
    effect.z_index = 8
    effect.configure([
        {"name": "effect", "texture": texture, "frame_count": 8, "fps": 16.0, "loop": false},
    ], "effect")
    effect.set_visual_scale(scale_amount)
    effect.set_visual_tint(tint)
    parent.add_child(effect)
