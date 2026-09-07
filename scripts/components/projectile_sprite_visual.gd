extends Node2D
class_name GloamProjectileSpriteVisual

const VISUALS := preload("res://scripts/visual_constants.gd")

@export var pixel_scale: float = VISUALS.EFFECT_SPRITE_SCALE

@onready var sprite: Sprite2D = $Sprite

var pending_texture: Texture2D


func _ready() -> void:
    _apply_texture()


func configure(texture: Texture2D, new_scale: float = VISUALS.EFFECT_SPRITE_SCALE) -> void:
    pending_texture = texture
    pixel_scale = new_scale

    if is_node_ready():
        _apply_texture()


func face_direction(direction: Vector2) -> void:
    if direction.length_squared() > 0.001:
        rotation = direction.angle()


func _apply_texture() -> void:
    if is_instance_valid(sprite) and pending_texture != null:
        sprite.texture = pending_texture
        sprite.scale = Vector2.ONE * pixel_scale
