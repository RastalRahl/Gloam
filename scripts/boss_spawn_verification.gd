extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node2D = MAIN_SCENE.instantiate() as Node2D
	root.add_child(main)
	current_scene = main
	await process_frame
	paused = false
	main._choose_starting_weapon("sword")
	await process_frame

	main.current_day = main.nights_to_survive
	main._start_night()
	var first_spawn: bool = main._spawn_grave_ox()
	var second_spawn: bool = main._spawn_grave_ox()
	var boss_nodes: int = 0
	for child: Node in main.get_node("Enemies").get_children():
		if child is GloamGraveOx:
			boss_nodes += 1

	_check(first_spawn, "final-night boss can spawn once")
	_check(not second_spawn, "duplicate boss spawn is rejected")
	_check(boss_nodes == 1 and main.final_boss_spawned and is_instance_valid(main.current_boss), "exactly one boss instance is active", "nodes=1 spawned=true active=true", "nodes=%d spawned=%s active=%s" % [boss_nodes, main.final_boss_spawned, is_instance_valid(main.current_boss)])
	main._cancel_pending_wave_work("boss spawn verification cleanup")

	var audio_hooks: GloamAudioHooks = main.get_node_or_null("AudioHooks") as GloamAudioHooks
	if is_instance_valid(audio_hooks):
		audio_hooks.free()
	main.queue_free()
	await process_frame
	# Boss spawning emits its critical UI tone; allow that playback reference to
	# release before the smoke process exits. This is teardown-only.
	await create_timer(0.25, true).timeout
	print("Boss spawn verification: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, description: String, expected: Variant = null, actual: Variant = null) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		print("FAIL: %s | expected=%s actual=%s" % [description, str(expected), str(actual)])
