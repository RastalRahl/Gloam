extends Node2D
class_name GloamVillageBuilding

signal destroyed(building: Node)

const HOUSE_1_TEXTURE := preload("res://assets/generated/tiny_swords/buildings/black/house_1.png")
const HOUSE_2_TEXTURE := preload("res://assets/generated/tiny_swords/buildings/black/house_2.png")
const HOUSE_3_TEXTURE := preload("res://assets/generated/tiny_swords/buildings/black/house_3.png")
const BARRACKS_TEXTURE := preload("res://assets/generated/tiny_swords/buildings/black/barracks.png")
const TOWER_TEXTURE := preload("res://assets/generated/tiny_swords/buildings/black/tower.png")
const VISUAL_FEEDBACK := preload("res://scripts/visual_feedback.gd")
const VISUALS := preload("res://scripts/visual_constants.gd")
const GROUND_FOOTPRINT := preload("res://scripts/ground_footprint.gd")

@export_enum("house", "farm", "barracks", "blacksmith") var building_type: String = "house"
@export var display_name: String = "Building"
@export var max_hp: int = 100
@export var max_level: int = 3

var hp: int
var level: int = 1

@onready var sprite_visual: GloamStaticSpriteVisual = $SpriteVisual as GloamStaticSpriteVisual
@onready var field_art: Sprite2D = get_node_or_null("FieldArt") as Sprite2D


func _ready() -> void:
    add_to_group("village_buildings")
    hp = max_hp
    _ensure_foundation_footprint()
    _hide_legacy_visuals()
    _configure_visual()


func take_damage(amount: int) -> void:
    hp = maxi(0, hp - amount)

    if hp <= 0:
        VISUAL_FEEDBACK.request_audio(self, "structure_destroyed", 0.90)
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
    max_hp = int(round(max_hp * 1.35))
    hp = max_hp


func _hide_legacy_visuals() -> void:
    for visual_name: String in ["Visual", "Roof", "FieldStripe1", "FieldStripe2", "Banner", "Forge"]:
        var legacy_visual: CanvasItem = get_node_or_null(visual_name) as CanvasItem

        if is_instance_valid(legacy_visual):
            legacy_visual.hide()


func _configure_visual() -> void:
    if is_instance_valid(field_art):
        field_art.centered = true
        field_art.scale = Vector2.ONE * VISUALS.FIELD_SPRITE_SCALE
        field_art.position = Vector2(0.0, -96.0 * VISUALS.FIELD_SPRITE_SCALE)
        field_art.modulate = Color.WHITE
    match building_type:
        "farm":
            sprite_visual.configure(HOUSE_3_TEXTURE, VISUALS.SMALL_BUILDING_SPRITE_SCALE)
        "barracks":
            sprite_visual.configure(BARRACKS_TEXTURE, VISUALS.SMALL_BUILDING_SPRITE_SCALE)
        "blacksmith":
            sprite_visual.configure(TOWER_TEXTURE, VISUALS.SMALL_BUILDING_SPRITE_SCALE)
        _:
            var house_texture: Texture2D = HOUSE_1_TEXTURE if int(abs(global_position.x + global_position.y)) % 2 == 0 else HOUSE_2_TEXTURE
            sprite_visual.configure(house_texture, VISUALS.SMALL_BUILDING_SPRITE_SCALE)


func _ensure_foundation_footprint() -> void:
    var footprint_size := Vector2(72, 18)
    match building_type:
        "farm":
            footprint_size = Vector2(96, 20)
        "barracks":
            footprint_size = Vector2(122, 22)
        "blacksmith":
            footprint_size = Vector2(78, 18)
    var footprint := GROUND_FOOTPRINT.new().setup(footprint_size)
    footprint.name = "FoundationFootprint"
    add_child(footprint)
