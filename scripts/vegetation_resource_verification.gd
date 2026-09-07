extends SceneTree

## Focused verification for the authored vegetation and resource placement
## contract added after the terrain/collision foundation.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const RESOURCE_PROFILES := preload("res://scripts/resource_profiles.gd")
const PLACEMENT := preload("res://scripts/placement_validation.gd")

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node2D = MAIN_SCENE.instantiate() as Node2D
	main.day_duration = 999.0
	main.night_duration = 999.0
	main.exploration_debug_seed = 11
	root.add_child(main)
	current_scene = main
	await _frames(3)
	paused = false
	main._choose_starting_weapon("bow")
	await _frames(4)

	var world: GloamWorldVisuals = main.world_visuals
	_check(world.get_vegetation_count("forest") == 16, "current sparse sixteen-tree forest canopy remains authored")
	_check(world.get_vegetation_count("village") == 0, "current village composition remains intentionally tree-free")
	_check(world.get_placement_validation_errors().is_empty(), "all authored prop anchors clear walkable-ground and footprint validation")
	for error: String in world.get_placement_validation_errors():
		print("PLACEMENT ERROR: %s" % error)
	_check(world.get_placement_footprints().size() == _authored_prop_count(world.get_node("Regions")), "every scene-authored placement has a validated ground footprint")

	for resource_type: String in RESOURCE_PROFILES.resource_types():
		var profile: Dictionary = RESOURCE_PROFILES.profile(resource_type)
		for field: String in [
			"sprite_anchor", "visual_scale", "interaction_radius", "physical_footprint",
			"highlight_position", "collection_effect_position", "placement_footprint",
		]:
			_check(profile.has(field), "%s profile defines %s" % [resource_type, field])
		_check(profile["physical_footprint"] == Vector2.ZERO, "%s pickup does not block movement" % resource_type)

	_check(main.get_node("Resources").get_child_count() == 22, "all planned resources survive placement validation")
	_check(main.get_node("DayEnemies").get_child_count() == 8, "all planned day enemy spawns survive placement validation")
	_check(main.exploration_controller.placement_validation_errors.is_empty(), "resources and enemy spawns have no placement-validation failures")
	for error: String in main.exploration_controller.placement_validation_errors:
		print("PLACEMENT ERROR: %s" % error)
	for resource: Node in main.get_node("Resources").get_children():
		_check(resource.collision_layer == 0, "%s resource remains non-blocking" % resource.name)
		var cue := resource.get_node("ProximityHighlight") as GloamResourceHighlight
		_check(cue.visible and not cue.active, "%s keeps only its subdued collectible cue outside proximity" % resource.name)
		var resource_profile: Dictionary = RESOURCE_PROFILES.profile(str(resource.get("resource_type")))
		_check(
			PLACEMENT.is_clear_of_visual_occlusion(
				(resource as Node2D).global_position,
				resource_profile["placement_footprint"],
				world.get_placement_footprints()
			),
			"%s remains outside vegetation occlusion" % resource.name
		)

	# Check the interaction cue without entering the collection radius.
	var first_resource: Node2D = main.get_node("Resources").get_child(0) as Node2D
	main.player.global_position = first_resource.global_position + Vector2(-34.0, 0.0)
	await _frames(2)
	_check(first_resource.get_node("ProximityHighlight").visible, "resource proximity cue appears inside interaction range")

	main._cancel_pending_wave_work("vegetation/resource verification cleanup")
	main.queue_free()
	await _frames(3)
	current_scene = null
	print("Vegetation/resource verification: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame


func _authored_prop_count(node: Node) -> int:
	var count: int = 1 if node.has_meta("placement_id") else 0
	for child: Node in node.get_children():
		count += _authored_prop_count(child)
	return count


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		print("FAIL: %s" % description)
