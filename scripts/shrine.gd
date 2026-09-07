extends Area2D
class_name GloamShrine

const MONASTERY_TEXTURE := preload("res://assets/generated/tiny_swords/buildings/black/monastery.png")
const VISUALS := preload("res://scripts/visual_constants.gd")
const GROUND_FOOTPRINT := preload("res://scripts/ground_footprint.gd")

@onready var sprite_visual: GloamStaticSpriteVisual = $SpriteVisual as GloamStaticSpriteVisual

var player_inside: bool = false

func _ready() -> void:
    $Visual.hide()
    $Core.hide()
    var footprint := GROUND_FOOTPRINT.new().setup(Vector2(110, 20))
    footprint.name = "FoundationFootprint"
    add_child(footprint)
    sprite_visual.configure(MONASTERY_TEXTURE, VISUALS.SHRINE_SPRITE_SCALE)
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
    var player_body: GloamPlayer = body as GloamPlayer
    if not is_instance_valid(player_body) or player_body.is_downed:
        return

    player_inside = true
    var main: Node = get_tree().current_scene

    if main.has_method("set_shrine_active"):
        main.set_shrine_active(true, self)


func _on_body_exited(body: Node) -> void:
    var player_body: GloamPlayer = body as GloamPlayer
    if not is_instance_valid(player_body):
        return

    player_inside = false
    var main: Node = get_tree().current_scene

    if main.has_method("set_shrine_active"):
        main.set_shrine_active(false, self)
