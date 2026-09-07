extends GloamAnimatedSpriteVisual
class_name GloamOneShotEffectVisual

@export var expire_after: float = 1.0


func _ready() -> void:
    super._ready()
    sprite.animation_finished.connect(_on_animation_finished)


func play_effect(action: String = "effect") -> void:
    play_action(action)


func _on_animation_finished() -> void:
    queue_free()


func _process(delta: float) -> void:
    expire_after -= delta

    if expire_after <= 0.0:
        queue_free()
