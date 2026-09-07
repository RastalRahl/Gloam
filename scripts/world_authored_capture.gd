extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

const VIEWS: Dictionary = {
	"village": Vector2(320, 1160),
	"north_passage": Vector2(256, 896),
	"east_passage": Vector2(512, 1184),
	"forest": Vector2(1040, 1080),
	"mine": Vector2(1930, 1120),
	"ruins": Vector2(1880, 430),
}

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var main: Node2D = MAIN_SCENE.instantiate() as Node2D
	main.day_duration = 999.0
	main.night_duration = 999.0
	main.exploration_debug_seed = 31
	root.add_child(main)
	current_scene = main
	await _frames(5)
	paused = false
	main._choose_starting_weapon("sword")
	await _frames(5)
	main.player.set_physics_process(false)
	main.world_camera.position_smoothing_enabled = false
	var overlay := main.get_node("CollisionDebugOverlay") as GloamCollisionDebugOverlay

	for view_name: String in ["village", "north_passage", "east_passage", "forest", "mine", "ruins"]:
		main.player.global_position = VIEWS[view_name]
		overlay.set_enabled(false)
		await _settle()
		await _capture("res://visual_comparison/world_authored_%s_normal.png" % view_name, "%s normal" % view_name)
		overlay.set_enabled(true)
		await _frames(2)
		await _capture("res://visual_comparison/world_authored_%s_collision.png" % view_name, "%s collision" % view_name)

	overlay.set_enabled(false)
	main.north_gate.take_damage(main.north_gate.max_hp)
	main.player.global_position = VIEWS["north_passage"]
	await _settle()
	await _capture("res://visual_comparison/world_authored_north_passage_breached.png", "north passage breached")
	main.east_gate.take_damage(main.east_gate.max_hp)
	main.player.global_position = VIEWS["east_passage"]
	await _settle()
	await _capture("res://visual_comparison/world_authored_east_passage_breached.png", "east passage breached")

	main.queue_free()
	await _frames(3)
	current_scene = null
	print("World authored capture: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _settle() -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw


func _capture(path: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_check(image.get_width() == 1280 and image.get_height() == 720, "%s is 1280 x 720" % label)
	var result: Error = image.save_png(path)
	_check(result == OK, "%s screenshot saved" % label)
	print("Captured %s: %s" % [label, path])


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		print("FAIL: %s" % description)
