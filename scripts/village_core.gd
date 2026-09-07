extends Node2D
class_name GloamVillageCore

signal health_changed(current_hp: int, max_hp: int)
signal destroyed

const CASTLE_TEXTURE := preload("res://assets/generated/tiny_swords/buildings/black/castle.png")
const VISUAL_FEEDBACK := preload("res://scripts/visual_feedback.gd")

@export var max_hp: int = 100

var hp: int

@onready var sprite_visual: Sprite2D = $CastleArt


func _ready() -> void:
    hp = max_hp
    health_changed.emit(hp, max_hp)


func take_damage(amount: int) -> void:
    if hp <= 0:
        return

    hp = maxi(0, hp - amount)
    health_changed.emit(hp, max_hp)

    if hp == 0:
        VISUAL_FEEDBACK.request_audio(self, "core_destroyed", 1.0)
        destroyed.emit()
    else:
        VISUAL_FEEDBACK.request_audio(self, "core_damage", 0.85)
