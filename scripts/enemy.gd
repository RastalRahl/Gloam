extends CharacterBody2D
class_name GloamEnemy

signal defeated(enemy: GloamEnemy)

const XP_ORB_SCENE := preload("res://scenes/xp_orb.tscn")
const VISUAL_FEEDBACK := preload("res://scripts/visual_feedback.gd")
const SKULL_IDLE := preload("res://assets/generated/tiny_swords/enemies/skull/skull_idle.png")
const SKULL_RUN := preload("res://assets/generated/tiny_swords/enemies/skull/skull_run.png")
const SKULL_ATTACK := preload("res://assets/generated/tiny_swords/enemies/skull/skull_attack.png")
const SPIDER_IDLE := preload("res://assets/generated/tiny_swords/enemies/spider/spider_idle.png")
const SPIDER_RUN := preload("res://assets/generated/tiny_swords/enemies/spider/spider_run.png")
const SPIDER_ATTACK := preload("res://assets/generated/tiny_swords/enemies/spider/spider_attack.png")
const TROLL_IDLE := preload("res://assets/generated/tiny_swords/enemies/troll/troll_idle.png")
const TROLL_WALK := preload("res://assets/generated/tiny_swords/enemies/troll/troll_walk.png")
const TROLL_ATTACK := preload("res://assets/generated/tiny_swords/enemies/troll/troll_attack.png")
const GNOLL_IDLE := preload("res://assets/generated/tiny_swords/enemies/gnoll/gnoll_idle.png")
const GNOLL_WALK := preload("res://assets/generated/tiny_swords/enemies/gnoll/gnoll_walk.png")
const GNOLL_THROW := preload("res://assets/generated/tiny_swords/enemies/gnoll/gnoll_throw.png")
const VISUALS := preload("res://scripts/visual_constants.gd")

@export var move_speed: float = 78.0
@export var max_hp: int = 3
@export var xp_value: int = 1

@export var attack_damage: int = 10
@export var attack_interval: float = 1.0
@export var core_attack_distance: float = 68.0
@export var player_attack_distance: float = 30.0
@export var defense_attack_distance: float = 36.0
@export var player_aggro_radius: float = 180.0
@export var defense_aggro_radius: float = 120.0
@export var soldier_aggro_radius: float = 145.0
@export var building_aggro_radius: float = 165.0
@export var can_attack_walls: bool = false
@export var wall_aggro_radius: float = 82.0
@export_enum("skull", "spider", "troll", "gnoll") var visual_profile: String = "skull"

var village_core: Node2D
var player: GloamPlayer
var primary_gate: GloamGate
var breach_marker: Node2D
var approach_waypoints: PackedVector2Array = PackedVector2Array()
var approach_index: int = 0

var hp: int
var attack_cooldown: float = 0.0

var slow_multiplier: float = 1.0
var slow_time_left: float = 0.0

var burn_damage_per_tick: int = 0
var burn_ticks_left: int = 0
var burn_tick_time: float = 0.0

var knockback_velocity: Vector2 = Vector2.ZERO
var stagger_time_left: float = 0.0

var health_bar_bg: ColorRect
var health_bar_fill: ColorRect
var attack_animation_time: float = 0.0
var facing_left: bool = false
var night_outline_sprite: AnimatedSprite2D
var night_readability_active: bool = false

@onready var sprite_visual: GloamAnimatedSpriteVisual = get_node_or_null("SpriteVisual") as GloamAnimatedSpriteVisual


func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	_ensure_combat_colliders()
	_hide_legacy_visuals()
	_configure_visual()
	_ensure_night_outline()
	_setup_health_bar()


func _ensure_combat_colliders() -> void:
	# The CharacterBody is not a combat target. Its compact footprint is for
	# ground contact only; the Area2D is the deliberately larger hurtbox.
	collision_layer = 0
	collision_mask = VISUALS.TERRAIN_OBSTACLE_LAYER | VISUALS.PROP_OBSTACLE_LAYER | VISUALS.GATE_OBSTACLE_LAYER
	var movement_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if is_instance_valid(movement_shape):
		var footprint := VISUALS.LARGE_ENEMY_FOOTPRINT if visual_profile == "troll" else VISUALS.ORDINARY_FOOTPRINT
		var rectangle := RectangleShape2D.new()
		rectangle.size = footprint
		movement_shape.shape = rectangle
		movement_shape.position = Vector2(0.0, -footprint.y * 0.5)
	var hurtbox := Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 2
	hurtbox.collision_mask = 0
	hurtbox.monitorable = true
	var hurt_shape := CollisionShape2D.new()
	var hurt_rectangle := RectangleShape2D.new()
	var hurt_size := Vector2(64, 105) if visual_profile == "troll" else Vector2(32, 46)
	hurt_rectangle.size = hurt_size
	hurt_shape.shape = hurt_rectangle
	hurt_shape.position = Vector2(0.0, -hurt_size.y * 0.5)
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)


func _process(delta: float) -> void:
	attack_animation_time = maxf(0.0, attack_animation_time - delta)

	if not is_instance_valid(sprite_visual):
		return
	_sync_night_outline()

	if absf(velocity.x) > 1.0:
		facing_left = velocity.x < 0.0
		sprite_visual.set_facing_left(facing_left)

	if attack_animation_time <= 0.0:
		sprite_visual.play_action("run" if velocity.length_squared() > 4.0 else "idle")


func set_targets(new_village_core: Node2D, new_player: GloamPlayer) -> void:
	village_core = new_village_core
	player = new_player


func set_lane(new_gate: GloamGate, new_breach_marker: Node2D) -> void:
	primary_gate = new_gate
	breach_marker = new_breach_marker


func set_approach_path(points: PackedVector2Array) -> void:
	approach_waypoints = points
	approach_index = 0


func set_night_readability(active: bool) -> void:
	night_readability_active = active
	_ensure_night_outline()
	if is_instance_valid(night_outline_sprite):
		night_outline_sprite.visible = active


func _ensure_night_outline() -> void:
	if is_instance_valid(night_outline_sprite) or not is_instance_valid(sprite_visual):
		return

	var source_sprite: AnimatedSprite2D = sprite_visual.get_node_or_null("Sprite") as AnimatedSprite2D
	if not is_instance_valid(source_sprite) or source_sprite.sprite_frames == null:
		return

	night_outline_sprite = source_sprite.duplicate() as AnimatedSprite2D
	night_outline_sprite.name = "NightOutline"
	night_outline_sprite.z_index = -1
	night_outline_sprite.show_behind_parent = true
	night_outline_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	night_outline_sprite.modulate = Color(1.0, 0.36, 0.20, 0.68)
	night_outline_sprite.scale = source_sprite.scale * VISUALS.NIGHT_OUTLINE_SCALE
	night_outline_sprite.stop()
	night_outline_sprite.visible = night_readability_active
	sprite_visual.add_child(night_outline_sprite)


func _sync_night_outline() -> void:
	if not is_instance_valid(night_outline_sprite):
		return

	var source_sprite: AnimatedSprite2D = sprite_visual.get_node_or_null("Sprite") as AnimatedSprite2D
	if not is_instance_valid(source_sprite):
		return

	night_outline_sprite.animation = source_sprite.animation
	night_outline_sprite.frame = source_sprite.frame
	night_outline_sprite.frame_progress = source_sprite.frame_progress
	night_outline_sprite.flip_h = source_sprite.flip_h


func _physics_process(delta: float) -> void:
	_update_status_effects(delta)

	if hp <= 0:
		return

	attack_cooldown = maxf(0.0, attack_cooldown - delta)

	if knockback_velocity.length_squared() > 1.0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 450.0 * delta)
		move_and_slide()
		return

	if stagger_time_left > 0.0:
		velocity = Vector2.ZERO
		return

	var target: Node2D = _choose_target()

	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		return

	var attack_distance: float = core_attack_distance

	if target == player:
		attack_distance = player_attack_distance
	elif target.is_in_group("lane_markers"):
		attack_distance = 0.0
	elif target.is_in_group("defenses") or target.is_in_group("gates") or target.is_in_group("walls"):
		attack_distance = defense_attack_distance

	var movement_target: Vector2 = _movement_target_for(target)
	var following_approach: bool = movement_target != target.global_position
	var distance_to_target: float = global_position.distance_to(movement_target)

	if not following_approach and distance_to_target <= attack_distance:
		velocity = Vector2.ZERO

		if attack_cooldown <= 0.0:
			_attack_target(target)
			attack_cooldown = attack_interval

		return

	var direction: Vector2 = global_position.direction_to(movement_target)
	velocity = direction * move_speed * slow_multiplier
	move_and_slide()


func _movement_target_for(target: Node2D) -> Vector2:
	if target != primary_gate and target != breach_marker:
		return target.global_position
	while approach_index < approach_waypoints.size() and global_position.distance_to(approach_waypoints[approach_index]) <= 24.0:
		approach_index += 1
	if approach_index < approach_waypoints.size():
		return approach_waypoints[approach_index]
	return target.global_position


func _update_status_effects(delta: float) -> void:
	if stagger_time_left > 0.0:
		stagger_time_left = maxf(0.0, stagger_time_left - delta)

	if slow_time_left > 0.0:
		slow_time_left -= delta

		if slow_time_left <= 0.0:
			slow_multiplier = 1.0

	if burn_ticks_left > 0:
		burn_tick_time -= delta

		if burn_tick_time <= 0.0:
			burn_tick_time = 1.0
			burn_ticks_left -= 1
			take_damage(burn_damage_per_tick)


func apply_burn(damage_per_tick: int, ticks: int) -> void:
	burn_damage_per_tick = maxi(burn_damage_per_tick, damage_per_tick)
	burn_ticks_left = maxi(burn_ticks_left, ticks)
	burn_tick_time = minf(burn_tick_time, 0.25) if burn_tick_time > 0.0 else 0.25


func apply_slow(strength: float, duration: float) -> void:
	slow_multiplier = minf(slow_multiplier, maxf(0.25, 1.0 - strength))
	slow_time_left = maxf(slow_time_left, duration)


func apply_knockback(force: Vector2) -> void:
	knockback_velocity += force


func apply_stagger(duration: float) -> void:
	stagger_time_left = maxf(stagger_time_left, duration)



func _lane_gate_is_closed() -> bool:
	if not is_instance_valid(primary_gate):
		return false

	return not primary_gate.is_breached


func _get_nearby_wall() -> Node2D:
	if not can_attack_walls:
		return null

	var nearest_wall: Node2D = null
	var nearest_distance: float = INF

	for wall in get_tree().get_nodes_in_group("walls"):
		if not is_instance_valid(wall):
			continue

		var d: float = global_position.distance_to(wall.global_position)

		if d <= wall_aggro_radius and d < nearest_distance:
			nearest_distance = d
			nearest_wall = wall

	return nearest_wall


func _choose_target() -> Node2D:
	# Authored lanes own the approach. A closed lane gate is always the first
	# objective; after a breach, finish crossing the passage before acquiring
	# ordinary combat targets inside the village.
	if _lane_gate_is_closed():
		return primary_gate

	if is_instance_valid(breach_marker):
		if global_position.distance_to(breach_marker.global_position) > 18.0:
			return breach_marker

	if is_instance_valid(player):
		var player_is_downed: bool = player.is_downed

		if not player_is_downed:
			var distance_to_player: float = global_position.distance_to(player.global_position)

			if distance_to_player <= player_aggro_radius:
				return player

	var wall: Node2D = _get_nearby_wall()

	if is_instance_valid(wall):
		return wall

	var nearest_soldier: Node2D = null
	var nearest_soldier_distance: float = INF

	for soldier in get_tree().get_nodes_in_group("soldiers"):
		if not is_instance_valid(soldier):
			continue

		var soldier_distance: float = global_position.distance_to(soldier.global_position)

		if soldier_distance <= soldier_aggro_radius and soldier_distance < nearest_soldier_distance:
			nearest_soldier_distance = soldier_distance
			nearest_soldier = soldier

	if is_instance_valid(nearest_soldier):
		return nearest_soldier

	var nearest_building: Node2D = null
	var nearest_building_distance: float = INF

	for building in get_tree().get_nodes_in_group("village_buildings"):
		if not is_instance_valid(building):
			continue

		var building_distance: float = global_position.distance_to(building.global_position)

		if building_distance <= building_aggro_radius and building_distance < nearest_building_distance:
			nearest_building_distance = building_distance
			nearest_building = building

	if is_instance_valid(nearest_building):
		return nearest_building

	var nearest_defense: Node2D = null
	var nearest_distance: float = INF

	for defense in get_tree().get_nodes_in_group("defenses"):
		if not is_instance_valid(defense):
			continue

		var d: float = global_position.distance_to(defense.global_position)

		if d <= defense_aggro_radius and d < nearest_distance:
			nearest_distance = d
			nearest_defense = defense

	if is_instance_valid(nearest_defense):
		return nearest_defense

	if is_instance_valid(village_core):
		return village_core

	return null


func _attack_target(target: Node) -> void:
	if is_instance_valid(target) and target is Node2D:
		_play_attack_visual(target.global_position)

	if is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(attack_damage)


func take_damage(amount: int) -> void:
	if hp <= 0:
		return

	hp = maxi(0, hp - amount)
	_show_hit_feedback()
	_update_health_bar()

	if hp <= 0:
		_die()



func _setup_health_bar() -> void:
	health_bar_bg = ColorRect.new()
	health_bar_bg.position = Vector2(-18, -25)
	health_bar_bg.size = Vector2(36, 5)
	health_bar_bg.color = Color(0.08, 0.08, 0.08, 0.90)
	health_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar_bg.z_index = 10
	health_bar_bg.hide()
	add_child(health_bar_bg)

	health_bar_fill = ColorRect.new()
	health_bar_fill.position = Vector2(1, 1)
	health_bar_fill.size = Vector2(34, 3)
	health_bar_fill.color = Color(0.82, 0.18, 0.16, 1.0)
	health_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar_bg.add_child(health_bar_fill)


func _update_health_bar() -> void:
	if not is_instance_valid(health_bar_bg) or not is_instance_valid(health_bar_fill):
		return

	var ratio: float = clampf(float(hp) / float(max_hp), 0.0, 1.0)
	health_bar_fill.size = Vector2(34.0 * ratio, 3.0)
	health_bar_bg.visible = hp > 0 and hp < max_hp


func _show_hit_feedback() -> void:
	var body_visual: CanvasItem = sprite_visual

	if not is_instance_valid(body_visual):
		body_visual = get_node_or_null("Visual") as CanvasItem

	if not is_instance_valid(body_visual):
		return

	body_visual.modulate = Color(1.0, 0.72, 0.48, 1.0)

	var tween: Tween = create_tween()
	tween.tween_property(body_visual, "modulate", Color.WHITE, 0.12)
	VISUAL_FEEDBACK.request_audio(self, "enemy_hit", 0.45)


func _hide_legacy_visuals() -> void:
	for visual_name: String in ["Shadow", "Outline", "Visual", "EyeLeft", "EyeRight", "Core"]:
		var legacy_visual: CanvasItem = get_node_or_null(visual_name) as CanvasItem

		if is_instance_valid(legacy_visual):
			legacy_visual.hide()


func _configure_visual() -> void:
	if not is_instance_valid(sprite_visual):
		return

	sprite_visual.set_visual_scale(
		VISUALS.LARGE_ENEMY_SPRITE_SCALE if visual_profile == "troll" else VISUALS.UNIT_SPRITE_SCALE
	)
	sprite_visual.set_sprite_offset(Vector2.ZERO)

	match visual_profile:
		"spider":
			sprite_visual.configure([
				{"name": "idle", "texture": SPIDER_IDLE, "frame_count": 8, "fps": 8.0},
				{"name": "run", "texture": SPIDER_RUN, "frame_count": 5, "fps": 10.0},
				{"name": "attack", "texture": SPIDER_ATTACK, "frame_count": 8, "fps": 15.0, "loop": false},
			])
		"troll":
			sprite_visual.configure([
				{"name": "idle", "texture": TROLL_IDLE, "frame_count": 12, "fps": 7.0},
				{"name": "run", "texture": TROLL_WALK, "frame_count": 10, "fps": 9.0},
				{"name": "attack", "texture": TROLL_ATTACK, "frame_count": 6, "fps": 9.0, "loop": false},
			])
		"gnoll":
			sprite_visual.configure([
				{"name": "idle", "texture": GNOLL_IDLE, "frame_count": 6, "fps": 8.0},
				{"name": "run", "texture": GNOLL_WALK, "frame_count": 8, "fps": 10.0},
				{"name": "attack", "texture": GNOLL_THROW, "frame_count": 8, "fps": 13.0, "loop": false},
			])
		_:
			sprite_visual.configure([
				{"name": "idle", "texture": SKULL_IDLE, "frame_count": 8, "fps": 8.0},
				{"name": "run", "texture": SKULL_RUN, "frame_count": 6, "fps": 10.0},
				{"name": "attack", "texture": SKULL_ATTACK, "frame_count": 7, "fps": 13.0, "loop": false},
			])


func _play_attack_visual(target_position: Vector2) -> void:
	if not is_instance_valid(sprite_visual):
		return

	facing_left = target_position.x < global_position.x
	sprite_visual.set_facing_left(facing_left)
	sprite_visual.play_action("attack")
	attack_animation_time = minf(attack_interval, 0.55)


func _die() -> void:
	hp = 0
	VISUAL_FEEDBACK.spawn_death_burst(get_tree().current_scene, global_position, 0.72 if visual_profile != "troll" else 1.05)
	VISUAL_FEEDBACK.request_audio(self, "enemy_death", 0.75)

	var orb: GloamXpOrb = XP_ORB_SCENE.instantiate() as GloamXpOrb
	orb.global_position = global_position
	orb.xp_value = xp_value

	get_tree().current_scene.call_deferred("add_child", orb)
	defeated.emit(self)
	queue_free()
