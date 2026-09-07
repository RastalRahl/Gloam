extends CharacterBody2D
class_name GloamPlayer

signal xp_changed(current_xp: int, required_xp: int, current_level: int)
signal leveled_up(new_level: int)
signal health_changed(current_hp: int, max_hp: int)
signal downed
signal respawned
signal respawn_countdown_changed(time_left: float, duration: float, down_number: int, next_delay: float)
signal build_changed

const WARRIOR_IDLE := preload("res://assets/generated/tiny_swords/units/black/warrior/warrior_idle.png")
const WARRIOR_RUN := preload("res://assets/generated/tiny_swords/units/black/warrior/warrior_run.png")
const WARRIOR_ATTACK := preload("res://assets/generated/tiny_swords/units/black/warrior/warrior_attack_1.png")
const ARCHER_IDLE := preload("res://assets/generated/tiny_swords/units/black/archer/archer_idle.png")
const ARCHER_RUN := preload("res://assets/generated/tiny_swords/units/black/archer/archer_run.png")
const ARCHER_SHOOT := preload("res://assets/generated/tiny_swords/units/black/archer/archer_shoot.png")
const LANCER_IDLE := preload("res://assets/generated/tiny_swords/units/black/lancer/lancer_idle.png")
const LANCER_RUN := preload("res://assets/generated/tiny_swords/units/black/lancer/lancer_run.png")
const LANCER_ATTACK_DOWN := preload("res://assets/generated/tiny_swords/units/black/lancer/lancer_down_attack.png")
const LANCER_ATTACK_RIGHT := preload("res://assets/generated/tiny_swords/units/black/lancer/lancer_right_attack.png")
const LANCER_ATTACK_UP := preload("res://assets/generated/tiny_swords/units/black/lancer/lancer_up_attack.png")
const EFFECT_SCENE := preload("res://scenes/components/one_shot_effect_visual.tscn")
const DUST_EFFECT := preload("res://assets/generated/tiny_swords/effects/dust_01.png")
const SPARK_EFFECT := preload("res://assets/generated/tiny_swords/effects/explosion_01.png")
const FIRE_EFFECT := preload("res://assets/generated/tiny_swords/effects/fire_01.png")
const WATER_EFFECT := preload("res://assets/generated/tiny_swords/effects/water_splash.png")
const VISUAL_FEEDBACK := preload("res://scripts/visual_feedback.gd")
const INPUT_ACTIONS := preload("res://scripts/input_actions.gd")
const ELEMENTAL_PROGRESSION := preload("res://scripts/elemental_progression.gd")
const VISUALS := preload("res://scripts/visual_constants.gd")

@export var move_speed: float = 260.0
@export var projectile_scene: PackedScene

@export var shot_cooldown: float = 0.32
@export var projectile_damage: int = 1
@export var projectile_count: int = 1
@export var projectile_spread_degrees: float = 10.0
@export var projectile_speed: float = 520.0

@export var max_hp: int = 100
@export var respawn_delay: float = 3.0

@onready var attack_timer: Timer = $AttackTimer
@onready var visual: GloamAnimatedSpriteVisual = $SpriteVisual as GloamAnimatedSpriteVisual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var level: int = 1
var xp: int = 0
var xp_to_next: int = 5

var hp: int
var is_downed: bool = false
var spawn_position: Vector2
var respawn_time_left: float = 0.0
var respawn_duration: float = 0.0
var respawn_pending: bool = false
var respawn_down_number: int = 0
var downs_this_night: int = 0
var night_respawn_penalty_active: bool = false

var respawn_timer: Timer
var respawn_token: int = 0
var active_respawn_token: int = 0

var weapon_type: String = "bow"
var weapon_display_name: String = "Bow"
var weapon_base_damage: int = 1
var elemental_damage_bonus: int = 0
var settlement_damage_bonus: int = 0
var base_move_speed: float = 260.0
var weapon_base_shot_cooldown: float = 0.32
var weapon_base_projectile_speed: float = 520.0

var melee_length: float = 0.0
var melee_width: float = 0.0
var melee_offset: float = 0.0
var weapon_base_knockback: float = 0.0
var attack_animation_time: float = 0.0
var facing_left: bool = false
var preferred_aim_device: String = "mouse"
var last_controller_aim: Vector2 = Vector2.RIGHT

# Elemental affinities.
var fire_level: int = 0
var water_level: int = 0
var earth_level: int = 0
var air_level: int = 0

# Fire
var burn_damage: int = 0
var burn_ticks: int = 0
var fire_spread_radius: float = 0.0
var fire_spread_damage: int = 0
var fire_spread_ticks: int = 0

# Water
var slow_strength: float = 0.0
var slow_duration: float = 0.0

# Earth
var knockback_force: float = 0.0
var stagger_duration: float = 0.0
var damage_taken_multiplier: float = 1.0
var knockback_multiplier: float = 1.0


func _ready() -> void:
	$Shadow.hide()
	$Outline.hide()
	$Visual.hide()
	$Inner.hide()
	$Crest.hide()

	hp = max_hp
	spawn_position = global_position
	base_move_speed = move_speed
	weapon_base_shot_cooldown = shot_cooldown
	weapon_base_projectile_speed = projectile_speed
	respawn_timer = Timer.new()
	respawn_timer.name = "RespawnTimer"
	respawn_timer.one_shot = true
	respawn_timer.timeout.connect(_on_respawn_timer_timeout)
	add_child(respawn_timer)

	weapon_base_damage = maxi(0, projectile_damage)
	_recalculate_combat_stats()
	attack_timer.wait_time = shot_cooldown

	xp_changed.emit(xp, xp_to_next, level)
	health_changed.emit(hp, max_hp)
	build_changed.emit()


func _process(_delta: float) -> void:
	if not respawn_pending or not is_instance_valid(respawn_timer):
		return

	var updated_time_left: float = maxf(0.0, respawn_timer.time_left)

	if not is_equal_approx(updated_time_left, respawn_time_left):
		respawn_time_left = updated_time_left
		respawn_countdown_changed.emit(
			respawn_time_left,
			respawn_duration,
			respawn_down_number,
			get_next_respawn_delay()
		)


func choose_weapon(new_weapon: String) -> void:
	if is_downed:
		return

	weapon_type = new_weapon

	match weapon_type:
		"sword":
			weapon_display_name = "Sword"
			weapon_base_damage = 2
			weapon_base_shot_cooldown = 0.44
			melee_length = 82.0
			melee_width = 54.0
			melee_offset = 54.0
			weapon_base_knockback = 10.0

		"spear":
			weapon_display_name = "Spear"
			weapon_base_damage = 3
			weapon_base_shot_cooldown = 0.64
			melee_length = 132.0
			melee_width = 34.0
			melee_offset = 76.0
			weapon_base_knockback = 26.0

		_:
			weapon_type = "bow"
			weapon_display_name = "Bow"
			weapon_base_damage = 1
			weapon_base_shot_cooldown = 0.32
			weapon_base_projectile_speed = 520.0
			melee_length = 0.0
			melee_width = 0.0
			melee_offset = 0.0
			weapon_base_knockback = 0.0

	attack_timer.wait_time = shot_cooldown
	_configure_weapon_visual()
	_recalculate_combat_stats()
	build_changed.emit()


func _input(event: InputEvent) -> void:
	INPUT_ACTIONS.observe_event(event)

	if event is InputEventJoypadMotion:
		var controller_aim: Vector2 = Input.get_vector(
			INPUT_ACTIONS.AIM_LEFT,
			INPUT_ACTIONS.AIM_RIGHT,
			INPUT_ACTIONS.AIM_UP,
			INPUT_ACTIONS.AIM_DOWN
		)
		if controller_aim.length_squared() > 0.04:
			last_controller_aim = controller_aim.normalized()
			preferred_aim_device = "controller"
	elif event is InputEventJoypadButton:
		var joypad_event: InputEventJoypadButton = event as InputEventJoypadButton
		if joypad_event.pressed and event.is_action_pressed(INPUT_ACTIONS.ATTACK):
			preferred_aim_device = "controller"
	elif event is InputEventMouseMotion:
		preferred_aim_device = "mouse"
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		preferred_aim_device = "mouse"


func _physics_process(delta: float) -> void:
	if is_downed:
		velocity = Vector2.ZERO
		return

	var direction: Vector2 = Input.get_vector(
		INPUT_ACTIONS.MOVE_LEFT,
		INPUT_ACTIONS.MOVE_RIGHT,
		INPUT_ACTIONS.MOVE_UP,
		INPUT_ACTIONS.MOVE_DOWN
	)

	velocity = direction * move_speed
	move_and_slide()

	attack_animation_time = maxf(0.0, attack_animation_time - delta)
	_update_locomotion_visual(direction)

	if Input.is_action_pressed(INPUT_ACTIONS.ATTACK):
		_try_attack()


func _try_attack() -> void:
	if is_downed or not attack_timer.is_stopped():
		return

	var aim_direction: Vector2 = _get_aim_direction()

	if aim_direction.length_squared() < 0.001:
		return

	match weapon_type:
		"sword", "spear":
			_perform_melee_attack(aim_direction)
		_:
			_perform_bow_attack(aim_direction)

	VISUAL_FEEDBACK.request_audio(self, "player_attack", 0.55)
	_play_attack_visual(aim_direction)
	attack_animation_time = shot_cooldown
	attack_timer.start()


func _get_aim_direction() -> Vector2:
	var controller_aim: Vector2 = Input.get_vector(
		INPUT_ACTIONS.AIM_LEFT,
		INPUT_ACTIONS.AIM_RIGHT,
		INPUT_ACTIONS.AIM_UP,
		INPUT_ACTIONS.AIM_DOWN
	)
	if controller_aim.length_squared() > 0.04:
		last_controller_aim = controller_aim.normalized()
		preferred_aim_device = "controller"
		return last_controller_aim

	if preferred_aim_device == "controller":
		return last_controller_aim if last_controller_aim.length_squared() > 0.04 else _facing_direction()

	var mouse_aim: Vector2 = global_position.direction_to(get_global_mouse_position())
	if mouse_aim.length_squared() > 0.001:
		return mouse_aim
	return _facing_direction()


func _facing_direction() -> Vector2:
	return Vector2.LEFT if facing_left else Vector2.RIGHT


func _perform_bow_attack(aim_direction: Vector2) -> void:
	if projectile_scene == null:
		return

	if projectile_count <= 1:
		_spawn_projectile(aim_direction)
	else:
		var total_spread: float = deg_to_rad(projectile_spread_degrees * float(projectile_count - 1))
		var start_angle: float = -total_spread / 2.0
		var step: float = deg_to_rad(projectile_spread_degrees)

		for i in range(projectile_count):
			var shot_direction: Vector2 = aim_direction.rotated(start_angle + step * i)
			_spawn_projectile(shot_direction)


func _spawn_projectile(direction: Vector2) -> void:
	var projectile: GloamProjectile = projectile_scene.instantiate() as GloamProjectile
	projectile.global_position = global_position + direction * 24.0

	if projectile.has_method("setup"):
		projectile.setup(
			direction,
			projectile_damage,
			projectile_speed,
			burn_damage,
			burn_ticks,
			slow_strength,
			slow_duration,
			knockback_force * knockback_multiplier,
			stagger_duration,
			fire_spread_radius,
			fire_spread_damage,
			fire_spread_ticks
		)
	projectile.set_source(self)

	get_tree().current_scene.add_child(projectile)


func _perform_melee_attack(direction: Vector2) -> void:
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(melee_length, melee_width)

	var center: Vector2 = global_position + direction * melee_offset
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(direction.angle(), center)
	query.collision_mask = 2
	query.collide_with_bodies = false
	query.collide_with_areas = true

	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var results: Array[Dictionary] = space.intersect_shape(query, 32)

	var hit_bodies: Dictionary = {}

	for result in results:
		var body: Node = _resolve_hurtbox_target(result["collider"] as Node)

		if body == null or hit_bodies.has(body):
			continue

		hit_bodies[body] = true
		_apply_melee_hit(body, direction)

	_show_melee_feedback(direction)


func _resolve_hurtbox_target(collider: Node) -> Node:
	if not is_instance_valid(collider):
		return null
	if collider.has_method("take_damage"):
		return collider
	var parent: Node = collider.get_parent()
	return parent if is_instance_valid(parent) and parent.has_method("take_damage") else collider


func _apply_melee_hit(body: Node, direction: Vector2) -> void:
	if not body.has_method("take_damage"):
		return

	body.take_damage(projectile_damage)

	if burn_damage > 0 and burn_ticks > 0 and body.has_method("apply_burn"):
		body.apply_burn(burn_damage, burn_ticks)
		_apply_fire_spread(body)

	if slow_strength > 0.0 and slow_duration > 0.0 and body.has_method("apply_slow"):
		body.apply_slow(slow_strength, slow_duration)

	var effective_knockback: float = (knockback_force + weapon_base_knockback) * knockback_multiplier
	if effective_knockback > 0.0 and body.has_method("apply_knockback"):
		body.apply_knockback(direction * effective_knockback)

	if stagger_duration > 0.0 and body.has_method("apply_stagger"):
		body.apply_stagger(stagger_duration)

	_spawn_melee_impact(body.global_position)


func _apply_fire_spread(source: Node) -> void:
	if fire_spread_radius <= 0.0 or fire_spread_damage <= 0 or fire_spread_ticks <= 0:
		return

	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy == source or not is_instance_valid(enemy) or not enemy.has_method("apply_burn"):
			continue
		if int(enemy.get("hp")) <= 0:
			continue
		if source.global_position.distance_to(enemy.global_position) > fire_spread_radius:
			continue
		enemy.apply_burn(fire_spread_damage, fire_spread_ticks)


func _show_melee_feedback(direction: Vector2) -> void:
	# Put the telegraph on the far edge of the same rectangle used by the
	# physics query so sword and spear reach never reads shorter than it is.
	var reach: float = melee_offset + melee_length * 0.50
	var feedback_position: Vector2 = global_position + direction * reach
	var effect: GloamOneShotEffectVisual = EFFECT_SCENE.instantiate() as GloamOneShotEffectVisual
	effect.global_position = feedback_position
	effect.rotation = direction.angle()
	effect.z_index = 7
	get_tree().current_scene.add_child(effect)

	var texture: Texture2D = DUST_EFFECT
	var tint: Color = Color(0.78, 0.82, 0.86, 0.92)
	var scale: float = VISUALS.DUST_EFFECT_SCALE

	if weapon_type == "spear":
		texture = SPARK_EFFECT
		tint = Color(0.60, 0.76, 1.0, 0.85)
		scale = VISUALS.IMPACT_EFFECT_SCALE

	effect.set_visual_scale(scale)
	effect.set_visual_tint(tint)
	effect.configure([
		{"name": "effect", "texture": texture, "frame_count": 8, "fps": 18.0, "loop": false}
	], "effect")


func _spawn_melee_impact(impact_position: Vector2) -> void:
	var effect: GloamOneShotEffectVisual = EFFECT_SCENE.instantiate() as GloamOneShotEffectVisual
	effect.global_position = impact_position
	effect.z_index = 8
	get_tree().current_scene.add_child(effect)

	var texture: Texture2D = SPARK_EFFECT
	var tint: Color = Color(0.95, 0.78, 0.40, 1.0)
	var scale: float = VISUALS.IMPACT_EFFECT_SCALE

	if burn_ticks > 0:
		texture = FIRE_EFFECT
		tint = Color(1.0, 0.38, 0.18, 1.0)
		scale = VISUALS.ELEMENTAL_EFFECT_SCALE
	elif slow_strength > 0.0:
		texture = WATER_EFFECT
		tint = Color(0.45, 0.76, 1.0, 1.0)
		scale = VISUALS.ELEMENTAL_EFFECT_SCALE
	elif knockback_force > 0.0:
		texture = DUST_EFFECT
		tint = Color(0.72, 0.66, 0.50, 1.0)
		scale = VISUALS.DUST_EFFECT_SCALE

	effect.set_visual_scale(scale)
	effect.set_visual_tint(tint)
	effect.configure([
		{"name": "effect", "texture": texture, "frame_count": 8, "fps": 18.0, "loop": false}
	], "effect")


func gain_xp(amount: int) -> void:
	if is_downed:
		return

	xp += amount

	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = int(round(xp_to_next * 1.35)) + 1
		leveled_up.emit(level)

	xp_changed.emit(xp, xp_to_next, level)


func take_damage(amount: int) -> void:
	if is_downed or hp <= 0:
		return

	var adjusted_amount: int = maxi(0, amount)
	if adjusted_amount > 0 and damage_taken_multiplier < 1.0:
		adjusted_amount = maxi(1, int(ceilf(float(adjusted_amount) * damage_taken_multiplier)))
	hp = maxi(0, hp - adjusted_amount)
	_show_damage_feedback()
	health_changed.emit(hp, max_hp)

	if hp == 0:
		_go_down()



func _show_damage_feedback() -> void:
	if not is_instance_valid(visual):
		return

	visual.set_visual_tint(Color(1.0, 0.45, 0.45, 1.0))

	var tween: Tween = create_tween()
	tween.tween_property(visual, "modulate", Color.WHITE, 0.16)
	VISUAL_FEEDBACK.request_audio(self, "player_hit", 0.65)


func _go_down() -> void:
	if is_downed or respawn_pending or not is_inside_tree():
		return

	is_downed = true
	respawn_down_number = 1

	if night_respawn_penalty_active:
		downs_this_night += 1
		respawn_down_number = downs_this_night

	respawn_duration = _get_respawn_duration(respawn_down_number)
	respawn_time_left = respawn_duration
	respawn_pending = true
	respawn_token += 1
	active_respawn_token = respawn_token

	respawn_timer.wait_time = respawn_duration
	respawn_timer.start()

	VISUAL_FEEDBACK.spawn_death_burst(get_tree().current_scene, global_position, 0.80)
	VISUAL_FEEDBACK.request_audio(self, "player_downed", 0.90)
	velocity = Vector2.ZERO
	attack_timer.stop()
	attack_animation_time = 0.0
	visual.hide()
	collision_shape.set_deferred("disabled", true)
	downed.emit()

	respawn_countdown_changed.emit(
		respawn_time_left,
		respawn_duration,
		respawn_down_number,
		get_next_respawn_delay()
	)


func _get_respawn_duration(down_number: int) -> float:
	if not night_respawn_penalty_active:
		return maxf(0.0, respawn_delay)

	match mini(down_number, 3):
		1:
			return maxf(0.0, respawn_delay)
		2:
			return 5.0
		_:
			return 7.0


func get_next_respawn_delay() -> float:
	if not night_respawn_penalty_active:
		return maxf(0.0, respawn_delay)

	return _get_respawn_duration(downs_this_night + 1)


func begin_day_respawn_cycle() -> void:
	downs_this_night = 0
	night_respawn_penalty_active = false

	if respawn_pending:
		respawn_countdown_changed.emit(
			respawn_time_left,
			respawn_duration,
			respawn_down_number,
			get_next_respawn_delay()
		)


func begin_night_respawn_cycle() -> void:
	night_respawn_penalty_active = true


func cancel_respawn() -> void:
	respawn_token += 1
	active_respawn_token = respawn_token
	respawn_pending = false
	respawn_time_left = 0.0

	if is_instance_valid(respawn_timer):
		respawn_timer.stop()


func _on_respawn_timer_timeout() -> void:
	if (
		not respawn_pending
		or active_respawn_token != respawn_token
		or not is_downed
		or not is_inside_tree()
	):
		return

	var main: Node = get_tree().current_scene
	if is_instance_valid(main) and main.has_method("can_player_respawn"):
		if not main.can_player_respawn():
			cancel_respawn()
			return

	respawn_pending = false
	respawn_time_left = 0.0
	_respawn()


func _respawn() -> void:
	if not is_downed or not is_inside_tree():
		return

	global_position = spawn_position
	hp = max_hp
	is_downed = false
	velocity = Vector2.ZERO
	attack_animation_time = 0.0

	visual.show()
	collision_shape.set_deferred("disabled", false)

	health_changed.emit(hp, max_hp)
	respawned.emit()




func heal_full() -> void:
	if is_downed:
		return

	hp = max_hp
	health_changed.emit(hp, max_hp)


func get_elemental_levels() -> Dictionary:
	return {
		"fire": fire_level,
		"water": water_level,
		"earth": earth_level,
		"air": air_level,
	}


func get_elemental_combat_profile() -> Dictionary:
	return ELEMENTAL_PROGRESSION.get_combat_profile(get_elemental_levels(), weapon_type)


func apply_random_elemental_blessing(random_source: RandomNumberGenerator = null) -> String:
	if is_downed:
		return "Unavailable while downed"

	var choices: Array[Dictionary] = ELEMENTAL_PROGRESSION.get_available_upgrades(
		get_elemental_levels(),
		weapon_type
	)
	if choices.is_empty():
		return "Unavailable"

	var index: int = (
		random_source.randi_range(0, choices.size() - 1)
		if is_instance_valid(random_source)
		else randi_range(0, choices.size() - 1)
	)
	var chosen: Dictionary = choices[index]
	if not apply_upgrade(str(chosen.get("id", ""))):
		return "Unavailable"
	return str(chosen.get("element", "Unknown")).capitalize()


func set_settlement_damage_bonus(amount: int) -> void:
	settlement_damage_bonus = maxi(0, amount)
	_recalculate_combat_stats()
	build_changed.emit()


func _recalculate_effective_damage() -> void:
	projectile_damage = maxi(
		0,
		weapon_base_damage + elemental_damage_bonus + settlement_damage_bonus
	)


func _recalculate_combat_stats() -> void:
	var profile: Dictionary = get_elemental_combat_profile()
	elemental_damage_bonus = int(profile.get("damage_bonus", 0))
	burn_damage = int(profile.get("burn_damage", 0))
	burn_ticks = int(profile.get("burn_ticks", 0))
	fire_spread_radius = float(profile.get("fire_spread_radius", 0.0))
	fire_spread_damage = int(profile.get("fire_spread_damage", 0))
	fire_spread_ticks = int(profile.get("fire_spread_ticks", 0))
	slow_strength = float(profile.get("slow_strength", 0.0))
	slow_duration = float(profile.get("slow_duration", 0.0))
	knockback_force = float(profile.get("knockback_force", 0.0))
	stagger_duration = float(profile.get("stagger_duration", 0.0))
	damage_taken_multiplier = float(profile.get("damage_taken_multiplier", 1.0))
	knockback_multiplier = float(profile.get("knockback_multiplier", 1.0))
	move_speed = base_move_speed * float(profile.get("move_speed_multiplier", 1.0))
	shot_cooldown = maxf(
		0.08,
		weapon_base_shot_cooldown * float(profile.get("attack_cooldown_multiplier", 1.0))
	)
	projectile_speed = weapon_base_projectile_speed * float(profile.get("projectile_speed_multiplier", 1.0))
	if is_instance_valid(attack_timer):
		attack_timer.wait_time = shot_cooldown
	_recalculate_effective_damage()


func apply_upgrade(upgrade_id: String) -> bool:
	if is_downed:
		return false

	if not ELEMENTAL_PROGRESSION.is_upgrade_available(upgrade_id, get_elemental_levels()):
		return false

	var definition: Dictionary = ELEMENTAL_PROGRESSION.get_definition(upgrade_id)
	var element: String = str(definition.get("element", "")).to_lower()
	match element:
		"fire": fire_level += 1
		"water": water_level += 1
		"earth": earth_level += 1
		"air": air_level += 1
		_:
			return false

	_recalculate_combat_stats()
	build_changed.emit()
	return true


func _configure_weapon_visual() -> void:
	var animation_definitions: Array[Dictionary] = []
	visual.set_visual_scale(VISUALS.LANCER_SPRITE_SCALE if weapon_type == "spear" else VISUALS.UNIT_SPRITE_SCALE)
	visual.set_sprite_offset(Vector2.ZERO)

	match weapon_type:
		"sword":
			animation_definitions = [
				{"name": "idle", "texture": WARRIOR_IDLE, "frame_count": 8, "fps": 7.0, "loop": true},
				{"name": "run", "texture": WARRIOR_RUN, "frame_count": 6, "fps": 11.0, "loop": true},
				{"name": "attack", "texture": WARRIOR_ATTACK, "frame_count": 4, "fps": 13.0, "loop": false}
			]

		"spear":
			animation_definitions = [
				{"name": "idle", "texture": LANCER_IDLE, "frame_count": 12, "fps": 9.0, "loop": true},
				{"name": "run", "texture": LANCER_RUN, "frame_count": 6, "fps": 10.0, "loop": true},
				{"name": "attack_down", "texture": LANCER_ATTACK_DOWN, "frame_count": 3, "fps": 10.0, "loop": false},
				{"name": "attack_right", "texture": LANCER_ATTACK_RIGHT, "frame_count": 3, "fps": 10.0, "loop": false},
				{"name": "attack_up", "texture": LANCER_ATTACK_UP, "frame_count": 3, "fps": 10.0, "loop": false}
			]

		_:
			animation_definitions = [
				{"name": "idle", "texture": ARCHER_IDLE, "frame_count": 6, "fps": 7.0, "loop": true},
				{"name": "run", "texture": ARCHER_RUN, "frame_count": 4, "fps": 10.0, "loop": true},
				{"name": "attack", "texture": ARCHER_SHOOT, "frame_count": 8, "fps": 15.0, "loop": false}
			]

	visual.configure(animation_definitions)


func _update_locomotion_visual(direction: Vector2) -> void:
	if not is_instance_valid(visual) or attack_animation_time > 0.0:
		return

	if absf(direction.x) > 0.01:
		facing_left = direction.x < 0.0
		visual.set_facing_left(facing_left)

	if direction.length_squared() > 0.01:
		visual.play_action("run")
	else:
		visual.play_action("idle")


func _play_attack_visual(direction: Vector2) -> void:
	if not is_instance_valid(visual):
		return

	if weapon_type != "spear":
		if absf(direction.x) > 0.01:
			facing_left = direction.x < 0.0
			visual.set_facing_left(facing_left)

		visual.play_action("attack")
		return

	if absf(direction.y) > absf(direction.x):
		visual.set_facing_left(false)
		visual.play_action("attack_down" if direction.y > 0.0 else "attack_up")
	else:
		facing_left = direction.x < 0.0
		visual.set_facing_left(facing_left)
		visual.play_action("attack_right")


func _exit_tree() -> void:
	cancel_respawn()
