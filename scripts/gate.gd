extends Node2D
class_name GloamGate

const VISUAL_FEEDBACK := preload("res://scripts/visual_feedback.gd")
const VISUALS := preload("res://scripts/visual_constants.gd")

signal destroyed(gate: Node)
signal health_changed(current_hp: int, max_hp: int)

@export var gate_name: String = "Gate"
@export var max_hp: int = 180
@export var max_level: int = 3
@export var gate_width: float = 112.0

@onready var fortification_art: Sprite2D = $IntactArt
@onready var breached_left: Sprite2D = $BreachedLeft
@onready var breached_right: Sprite2D = $BreachedRight
@onready var blocker_body: StaticBody2D = $GateBlocker
@onready var blocker_shape: CollisionShape2D = $GateBlocker/CollisionShape2D
@onready var health_bar: ColorRect = $HealthBar
@onready var health_fill: ColorRect = $HealthBar/Fill

var hp: int
var level: int = 1
var is_breached: bool = false


func _ready() -> void:
	add_to_group("gates")
	hp = max_hp
	_configure_art_and_collision()
	blocker_body.collision_layer = VISUALS.GATE_OBSTACLE_LAYER
	blocker_body.collision_mask = 0
	blocker_body.set_meta("collision_category", "gate")
	blocker_body.add_to_group("gate_collision")
	_update_visual()
	_update_health_bar()
	health_changed.emit(hp, max_hp)


func take_damage(amount: int) -> void:
	if is_breached:
		return
	hp = maxi(0, hp - amount)
	_update_health_bar()
	health_changed.emit(hp, max_hp)
	if hp <= 0:
		is_breached = true
		blocker_shape.set_deferred("disabled", true)
		_update_visual()
		VISUAL_FEEDBACK.request_audio(self, "gate_destroyed", 1.0)
		destroyed.emit(self)
	else:
		_update_visual()
		VISUAL_FEEDBACK.request_audio(self, "gate_damage", 0.75)


func repair_full() -> void:
	hp = max_hp
	is_breached = false
	blocker_shape.set_deferred("disabled", false)
	_update_visual()
	_update_health_bar()
	health_changed.emit(hp, max_hp)


func can_upgrade() -> bool:
	return level < max_level and not is_breached


func upgrade() -> void:
	if not can_upgrade():
		return
	level += 1
	max_hp = int(round(max_hp * 1.45))
	hp = max_hp
	_update_visual()
	_update_health_bar()
	health_changed.emit(hp, max_hp)


func blocks_monsters() -> bool:
	return not is_breached and not blocker_shape.disabled


func _update_visual() -> void:
	fortification_art.visible = not is_breached
	breached_left.visible = is_breached
	breached_right.visible = is_breached
	if is_breached:
		return
	var health_ratio: float = float(hp) / float(max_hp)
	var brightness: float = 0.05 * float(level - 1)
	if health_ratio < 0.35:
		fortification_art.modulate = Color(0.88, 0.42, 0.34, 1.0)
	elif health_ratio < 0.65:
		fortification_art.modulate = Color(0.90, 0.68, 0.42, 1.0)
	else:
		fortification_art.modulate = Color(0.84 + brightness, 0.88 + brightness, 0.96, 1.0)


func _configure_art_and_collision() -> void:
	var horizontal_scale: float = gate_width / 256.0
	fortification_art.scale = Vector2(horizontal_scale, 0.52)
	fortification_art.position = Vector2(0.0, -16.0)
	breached_left.scale = Vector2(horizontal_scale, 0.52)
	breached_right.scale = Vector2(horizontal_scale, 0.52)
	breached_left.position = Vector2(-gate_width * 0.27, -10.0)
	breached_right.position = Vector2(gate_width * 0.27, -10.0)
	var rectangle := blocker_shape.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
		blocker_shape.shape = rectangle
	rectangle.size = Vector2(gate_width, 18.0)
	blocker_shape.position = Vector2(0.0, -9.0)


func _update_health_bar() -> void:
	var ratio: float = clampf(float(hp) / float(max_hp), 0.0, 1.0)
	health_fill.size = Vector2(58.0 * ratio, 4.0)
	health_bar.visible = is_breached or hp < max_hp
	if is_breached:
		health_fill.color = Color(0.45, 0.10, 0.08, 1.0)
	elif ratio < 0.35:
		health_fill.color = Color(0.82, 0.20, 0.14, 1.0)
	elif ratio < 0.65:
		health_fill.color = Color(0.84, 0.52, 0.16, 1.0)
	else:
		health_fill.color = Color(0.48, 0.70, 0.30, 1.0)

