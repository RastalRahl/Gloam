extends GloamEnemy
class_name GloamRangedEnemy

const ENEMY_PROJECTILE_SCENE := preload("res://scenes/enemy_projectile.tscn")

@export var preferred_range: float = 250.0
@export var projectile_speed: float = 310.0


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

	var movement_target: Vector2 = _movement_target_for(target)
	var following_approach: bool = movement_target != target.global_position
	var distance_to_target: float = global_position.distance_to(target.global_position)

	if not following_approach and distance_to_target <= preferred_range:
		velocity = Vector2.ZERO

		if attack_cooldown <= 0.0:
			_attack_target(target)
			attack_cooldown = attack_interval

		return

	var direction: Vector2 = global_position.direction_to(movement_target)
	velocity = direction * move_speed * slow_multiplier
	move_and_slide()


func _attack_target(target: Node) -> void:
	if not is_instance_valid(target) or not target is Node2D:
		return

	_play_attack_visual(target.global_position)

	var projectile: GloamEnemyProjectile = ENEMY_PROJECTILE_SCENE.instantiate() as GloamEnemyProjectile
	var direction: Vector2 = global_position.direction_to(target.global_position)
	projectile.global_position = global_position + direction * 22.0
	projectile.setup(target, direction, attack_damage, projectile_speed)
	get_tree().current_scene.add_child(projectile)
