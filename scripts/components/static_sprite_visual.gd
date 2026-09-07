extends Node2D
class_name GloamStaticSpriteVisual

const VISUALS := preload("res://scripts/visual_constants.gd")
const ASSET_CONFIG := preload("res://scripts/tiny_swords_asset_config.gd")

@export var pixel_scale: float = VISUALS.BUILDING_SPRITE_SCALE
@export var anchor_to_feet: bool = true

@onready var sprite: Sprite2D = $Sprite

var pending_texture: Texture2D


func _ready() -> void:
    _apply_texture()


# Anchoring at the feet lets the node position remain the gameplay/collision point.
func configure(texture: Texture2D, new_scale: float = VISUALS.BUILDING_SPRITE_SCALE) -> void:
    pending_texture = texture
    pixel_scale = new_scale

    if is_node_ready():
        _apply_texture()


func set_visual_tint(tint: Color) -> void:
    modulate = tint


func _apply_texture() -> void:
    if not is_instance_valid(sprite) or pending_texture == null:
        return

    sprite.texture = pending_texture
    sprite.scale = Vector2.ONE * pixel_scale
    sprite.centered = false
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

    if anchor_to_feet:
        var layout: Dictionary = ASSET_CONFIG.static_layout_for_texture(pending_texture)
        var foundation_y: float = float(layout.get("foundation_y", pending_texture.get_height()))
        sprite.position = Vector2(
            -pending_texture.get_width() * pixel_scale * 0.5,
            -foundation_y * pixel_scale
        )
    else:
        sprite.position = Vector2.ZERO
