extends SceneTree

## Representative 1280 x 720 captures of every major zone with the live
## collision contract hidden and enabled. Run with a windowed renderer.

const MAIN_SCENE := preload("res://scenes/main.tscn")

const ZONES: Dictionary = {
	"village": Vector2(320.0, 1190.0),
	"forest": Vector2(1040.0, 1080.0),
	"mine": Vector2(1930.0, 1120.0),
	"ruins": Vector2(1880.0, 630.0),
}

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var main: Node2D = MAIN_SCENE.instantiate() as Node2D
	main.day_duration = 999.0
	main.night_duration = 999.0
	main.exploration_debug_seed = 11
	root.add_child(main)
	current_scene = main
	await _frames(4)
	paused = false
	main._choose_starting_weapon("sword")
	await _frames(4)
	main.player.set_physics_process(false)
	main.world_camera.position_smoothing_enabled = false
	var overlay := main.get_node("CollisionDebugOverlay") as GloamCollisionDebugOverlay

	for zone: String in ["village", "forest", "mine", "ruins"]:
		main.player.global_position = ZONES[zone]
		overlay.set_enabled(false)
		await _settle_camera()
		await _capture("res://visual_comparison/terrain_%s_normal.png" % zone, "%s normal" % zone)
		overlay.set_enabled(true)
		await _frames(3)
		await _capture("res://visual_comparison/terrain_%s_collision.png" % zone, "%s collision" % zone)

	overlay.set_enabled(false)
	main.queue_free()
	await _frames(4)
	await RenderingServer.frame_post_draw
	current_scene = null
	print("Terrain collision capture: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _settle_camera() -> void:
	await _frames(3)
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
