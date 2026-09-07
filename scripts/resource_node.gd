extends Area2D
class_name GloamResourceNode

const VISUAL_FEEDBACK := preload("res://scripts/visual_feedback.gd")
const RESOURCE_PROFILES := preload("res://scripts/resource_profiles.gd")
const RESOURCE_HIGHLIGHT := preload("res://scripts/resource_highlight.gd")

@export_enum("wood", "stone", "iron", "essence") var resource_type: String = "wood"
@export var amount: int = 1
@export_range(1, 3) var risk_tier: int = 1
@export var zone_name: String = "wilderness"

@onready var visual: ColorRect = $Visual
@onready var wood_art: Sprite2D = $WoodArt
@onready var stone_art: Sprite2D = $StoneArt
@onready var iron_art: Sprite2D = $IronArt
@onready var essence_art: Sprite2D = $EssenceArt

var collected: bool = false
var resource_profile: Dictionary = {}
var highlight: GloamResourceHighlight
@onready var collection_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
    body_entered.connect(_on_body_entered)
    resource_profile = RESOURCE_PROFILES.profile(resource_type)
    _configure_art_anchors()
    _configure_collection_area()
    _configure_highlight()
    _apply_resource_color()
    set_process(true)


func _configure_art_anchors() -> void:
    # Every pickup is positioned from its visible ground contact.  The
    # profile keeps the four resource silhouettes distinct from decorative
    # trees and from one another.
    var anchor: Vector2 = resource_profile["sprite_anchor"]
    var visual_scale: float = float(resource_profile["visual_scale"])

    wood_art.centered = false
    wood_art.scale = Vector2.ONE * visual_scale
    wood_art.position = anchor

    stone_art.centered = false
    stone_art.scale = Vector2.ONE * visual_scale
    stone_art.position = anchor

    iron_art.centered = false
    iron_art.scale = Vector2.ONE * visual_scale
    iron_art.position = anchor
    iron_art.modulate = Color.WHITE

    essence_art.centered = false
    essence_art.scale = Vector2.ONE * visual_scale
    essence_art.position = anchor
    essence_art.modulate = Color.WHITE


func _configure_collection_area() -> void:
    var shape := collection_shape.shape as CircleShape2D
    if shape == null:
        shape = CircleShape2D.new()
        collection_shape.shape = shape
    shape.radius = float(resource_profile.get("collection_radius", 16.0))


func _configure_highlight() -> void:
    highlight = RESOURCE_HIGHLIGHT.new() as GloamResourceHighlight
    highlight.name = "ProximityHighlight"
    highlight.position = resource_profile["highlight_position"]
    highlight.configure(
        float(resource_profile["highlight_radius"]),
        resource_profile["highlight_color"]
    )
    highlight.set_active(false)
    add_child(highlight)


func _process(_delta: float) -> void:
    if collected or not is_instance_valid(highlight):
        return
    var main := get_tree().current_scene
    var player := main.get_node_or_null("Player") as Node2D if is_instance_valid(main) else null
    if not is_instance_valid(player):
        highlight.set_active(false)
        return
    highlight.set_active(
        global_position.distance_to(player.global_position) <= float(resource_profile["interaction_radius"])
    )


func _apply_resource_color() -> void:
    visual.hide()
    wood_art.hide()
    stone_art.hide()
    iron_art.hide()
    essence_art.hide()

    match resource_type:
        "wood":
            wood_art.show()
        "stone":
            stone_art.show()
        "iron":
            iron_art.show()
        "essence":
            essence_art.show()
        _:
            visual.show()



func _on_body_entered(body: Node) -> void:
    if collected:
        return

    var player_body: GloamPlayer = body as GloamPlayer
    if not is_instance_valid(player_body) or player_body.is_downed:
        return

    var main: Node = get_tree().current_scene

    if main.has_method("try_collect_resource"):
        if main.try_collect_resource(resource_type, amount):
            collected = true
            VISUAL_FEEDBACK.spawn_dust(
                get_tree().current_scene,
                global_position + resource_profile["collection_effect_position"],
                0.48
            )
            VISUAL_FEEDBACK.request_audio(self, "resource_collect", 0.45)
            queue_free()
