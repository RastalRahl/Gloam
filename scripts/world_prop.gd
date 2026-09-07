@tool
extends Node2D
class_name GloamWorldProp

const ASSETS := preload("res://scripts/tiny_swords_asset_config.gd")
const VISUALS := preload("res://scripts/visual_constants.gd")

@export_enum(
	"tree_1", "tree_2", "bush_1", "bush_2", "rock_1", "rock_2",
	"gold_stone_1", "gold_resource", "stump_1", "wood_resource",
	"skull_spike_01", "skull_spike_02", "tower"
) var asset_kind: String = "tree_1":
	set(value):
		asset_kind = value
		_queue_configuration()
@export var placement_id: String = ""
@export_enum("village", "forest", "mine", "ruins") var zone_name: String = "village"
@export var cluster_name: String = ""
@export var footprint_size: Vector2 = Vector2(36.0, 18.0):
	set(value):
		footprint_size = value
		_queue_configuration()
@export var visual_scale: float = 1.0:
	set(value):
		visual_scale = value
		_queue_configuration()
@export var collision_enabled: bool = true:
	set(value):
		collision_enabled = value
		_queue_configuration()
@export var animation_phase: int = 0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite
@onready var static_sprite: Sprite2D = $StaticSprite
@onready var footprint_body: StaticBody2D = $GroundFootprint
@onready var footprint_shape: CollisionShape2D = $GroundFootprint/CollisionShape2D


func _ready() -> void:
	_apply_configuration()


func _queue_configuration() -> void:
	if is_inside_tree():
		call_deferred("_apply_configuration")


func _apply_configuration() -> void:
	if not is_instance_valid(animated_sprite) or not is_instance_valid(static_sprite):
		return
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_as_relative = false
	z_index = int(round(global_position.y))
	set_meta("placement_id", placement_id)
	set_meta("zone", zone_name)
	set_meta("cluster", cluster_name)
	set_meta("footprint", footprint_size)

	var animated: bool = asset_kind in ["tree_1", "tree_2", "bush_1", "bush_2"]
	animated_sprite.visible = animated
	static_sprite.visible = not animated
	if animated:
		var definition: Dictionary = ASSETS.animation("sway", asset_kind, 6.0)
		animated_sprite.sprite_frames = ASSETS.build_sprite_frames([definition])
		animated_sprite.animation = "sway"
		animated_sprite.scale = Vector2.ONE * visual_scale
		animated_sprite.position = -Vector2(ASSETS.layout(asset_kind)["anchor_offset"]) * visual_scale
		var count: int = animated_sprite.sprite_frames.get_frame_count("sway")
		animated_sprite.frame = posmod(animation_phase, maxi(1, count))
		if not Engine.is_editor_hint():
			animated_sprite.play()
	else:
		var texture: Texture2D = ASSETS.texture(asset_kind)
		static_sprite.texture = texture
		static_sprite.centered = false
		static_sprite.scale = Vector2.ONE * visual_scale
		var layout: Dictionary = ASSETS.static_layout_for_texture(texture)
		var foundation_y: float = float(layout.get("foundation_y", texture.get_height()))
		static_sprite.position = Vector2(-texture.get_width() * visual_scale * 0.5, -foundation_y * visual_scale)

	var rectangle := footprint_shape.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
		footprint_shape.shape = rectangle
	rectangle.size = footprint_size
	footprint_shape.position = Vector2(0.0, -footprint_size.y * 0.5)
	footprint_body.collision_layer = VISUALS.PROP_OBSTACLE_LAYER if collision_enabled else 0
	footprint_body.collision_mask = 0
	footprint_body.set_meta("collision_category", "prop")
	footprint_body.add_to_group("prop_collision")
