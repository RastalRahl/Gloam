extends SceneTree

## Integrated 1280 x 720 evidence capture for the final visual/collision audit.
## The main scene, fixed gameplay camera, real phase transition, normal combat
## queries, and live collision overlay are used throughout.

const MAIN_SCENE := preload("res://scenes/main.tscn")

const OUTPUT_ROOT := "res://visual_comparison/final_audit_"

var failures: int = 0
var main: Node2D
var overlay: GloamCollisionDebugOverlay


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	main = MAIN_SCENE.instantiate() as Node2D
	main.day_duration = 999.0
	main.night_duration = 999.0
	main.final_boss_spawn_delay = 999.0
	main.exploration_debug_seed = 11
	root.add_child(main)
	current_scene = main
	await _frames(4)
	paused = false
	main._choose_starting_weapon("sword")
	await _frames(5)

	main.player.set_physics_process(false)
	main.world_camera.position_smoothing_enabled = false
	overlay = main.get_node("CollisionDebugOverlay") as GloamCollisionDebugOverlay
	for enemy: Node in main.get_node("DayEnemies").get_children():
		enemy.set_process(false)
		enemy.set_physics_process(false)

	_check(root.get_visible_rect().size == Vector2(1280, 720), "audit viewport is 1280 x 720")
	_check(main.world_camera.zoom == Vector2.ONE, "audit uses the intended 1.0 camera zoom")
	_check(main.world_visuals.are_terrain_collisions_active(), "terrain collision is active for captures")
	_check(main.world_visuals.are_prop_collisions_active(), "prop collision is active for captures")

	main.player.global_position = Vector2(320.0, 1190.0)
	await _capture_pair("village_fortifications_intact")

	var resource: Node2D = _find_resource("wood")
	_check(is_instance_valid(resource), "resource interaction capture has a wood pickup")
	if is_instance_valid(resource):
		print("Audit wood resource position: %s" % str(resource.global_position))
		main.player.global_position = resource.global_position + Vector2(-34.0, 0.0)
		await _capture_pair("resource_interaction")

	# Enter the real timer-driven dusk window while the player is away from the
	# village, then allow the same timer to complete the phase transition.
	main.player.global_position = Vector2(1780.0, 360.0)
	main.phase_timer.start(5.0)
	await _frames(3)
	main.night_presentation_controller.update_dusk_guidance(main.phase_timer.time_left)
	_check(main.return_panel.visible, "dusk capture shows the return-to-village guidance")
	await _capture_pair("dusk_transition")

	main.phase_timer.start(0.08)
	for _frame: int in range(180):
		if main.current_phase == main.Phase.NIGHT:
			break
		await process_frame
	_check(main.current_phase == main.Phase.NIGHT, "dusk completes through the real phase timer")
	main._cancel_pending_wave_work("final integrated visual audit stages deterministic combat")
	await _frames(3)

	main.player.global_position = Vector2(360.0, 1210.0)
	main.player.choose_weapon("sword")
	var sword_target: Node2D = await _spawn_frozen_target(main.player.global_position + Vector2(87.0, 0.0))
	if is_instance_valid(sword_target):
		var sword_hp_before: int = int(sword_target.get("hp"))
		main.player._perform_melee_attack(Vector2.RIGHT)
		main.player._play_attack_visual(Vector2.RIGHT)
		await _frames(1)
		_check(int(sword_target.get("hp")) < sword_hp_before, "sword reaches the target at its visible edge")
		await _capture_pair("night_sword_combat")
		sword_target.queue_free()
		await process_frame

	await _frames(32)
	main.player.choose_weapon("spear")
	var spear_target: Node2D = await _spawn_frozen_target(main.player.global_position + Vector2(134.0, 0.0))
	if is_instance_valid(spear_target):
		var spear_hp_before: int = int(spear_target.get("hp"))
		main.player._perform_melee_attack(Vector2.RIGHT)
		main.player._play_attack_visual(Vector2.RIGHT)
		await _frames(1)
		_check(int(spear_target.get("hp")) < spear_hp_before, "spear reaches the target at its visible edge")
		await _capture_pair("night_spear_combat")

	for enemy: Node in main.get_node("Enemies").get_children():
		enemy.hide()
		enemy.set_process(false)
		enemy.set_physics_process(false)
	main.player.global_position = Vector2(320.0, 1120.0)
	main.player.choose_weapon("sword")
	var north_gate := main.north_gate as GloamGate
	var east_gate := main.east_gate as GloamGate
	_check(is_instance_valid(north_gate) and is_instance_valid(east_gate), "fortification state capture has both authored gates")
	if is_instance_valid(north_gate) and is_instance_valid(east_gate):
		north_gate.take_damage(int(round(north_gate.max_hp * 0.55)))
		east_gate.take_damage(int(round(east_gate.max_hp * 0.55)))
		await _frames(2)
		await _capture_pair("village_fortifications_damaged")

		north_gate.take_damage(north_gate.hp)
		east_gate.take_damage(east_gate.hp)
		await _physics_frames(3)
		_check(north_gate.is_breached and east_gate.is_breached, "breached gate capture uses the live authored states")
		await _capture_pair("village_fortifications_breached")

	overlay.set_enabled(false)
	main.queue_free()
	await _frames(4)
	current_scene = null
	print("Final integrated visual audit: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _spawn_frozen_target(position: Vector2) -> Node2D:
	_check(main._spawn_enemy_in_lane("north"), "combat target spawns through the normal night lane path")
	await _frames(3)
	var enemies: Array[Node] = main.get_node("Enemies").get_children()
	if enemies.is_empty():
		failures += 1
		print("FAIL: combat target is missing")
		return null
	var target := enemies.back() as Node2D
	target.global_position = position
	# Keep the posed target alive through a full-strength spear hit so the
	# screenshot can show both the impact edge and the matching hurtbox.
	target.set("max_hp", 20)
	target.set("hp", 20)
	target.set_process(false)
	target.set_physics_process(false)
	await physics_frame
	return target


func _find_resource(resource_type: String) -> Node2D:
	var best: Node2D
	var best_clearance: float = -INF
	for resource: Node in main.get_node("Resources").get_children():
		if str(resource.get("resource_type")) != resource_type:
			continue
		var candidate := resource as Node2D
		var clearance: float = INF
		for obstacle: Dictionary in main.world_visuals.get_placement_footprints():
			clearance = minf(clearance, candidate.global_position.distance_to((obstacle["rect"] as Rect2).get_center()))
		if clearance > best_clearance:
			best_clearance = clearance
			best = candidate
	return best


func _capture_pair(label: String) -> void:
	overlay.set_enabled(false)
	await _settle()
	await _capture(OUTPUT_ROOT + label + "_normal.png", label + " normal")
	overlay.set_enabled(true)
	await _frames(2)
	await _capture(OUTPUT_ROOT + label + "_collision.png", label + " collision")
	overlay.set_enabled(false)


func _capture(path: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_check(image.get_size() == Vector2i(1280, 720), "%s is 1280 x 720" % label)
	var result: Error = image.save_png(path)
	_check(result == OK, "%s screenshot saved" % label)
	print("Captured %s: %s" % [label, path])


func _settle() -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame


func _physics_frames(count: int) -> void:
	for _index: int in range(count):
		await physics_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		print("FAIL: %s" % description)
