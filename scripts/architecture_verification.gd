extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const ECONOMY_BALANCE := preload("res://scripts/economy_balance.gd")

var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	paused = false
	main._choose_starting_weapon("sword")
	await process_frame

	for manager_name: String in [
		"WaveDirector",
		"ConstructionManager",
		"PopulationManager",
		"InteractionController",
		"ProgressionManager",
		"ShrineManager",
		"RunPhaseDirector",
		"HUDController",
		"ExplorationController",
	]:
		_check(main.has_node(manager_name), "main composes %s" % manager_name)

	_check(main.wave_director != null, "wave state is owned by the wave director")
	_check(main.construction_manager != null, "construction state is owned by the construction manager")
	_check(main.population_manager != null, "population state is owned by the population manager")
	_check(main.interaction_controller != null, "overlap targeting is owned by the interaction controller")
	_check(main.progression_manager != null, "upgrade choices are owned by the progression manager")
	_check(main.shrine_manager != null, "shrine transactions are owned by the shrine manager")
	_check(main.run_phase_director != null, "phase identity is owned by the run-phase director")
	_check(main.hud_controller != null, "HUD projections are owned by the HUD controller")
	_check(main.exploration_controller != null, "day world population is owned by the exploration controller")
	_check(main.has_node("World/Regions/Village"), "main composes an authored Village scene")
	_check(main.has_node("World/Regions/Forest"), "main composes an authored Forest scene")
	_check(main.has_node("World/Regions/Mine"), "main composes an authored Mine scene")
	_check(main.has_node("World/Regions/Ruins"), "main composes an authored Ruins scene")
	_check(main.has_node("World/Terrain/TerrainCliffCollision"), "permanent terrain collision is scene-authored")
	_check(main.get_node("World/Regions/Village/DefenseBuildSpots").get_child_count() == 7, "defense build spots are scene-authored")
	_check(main.get_node("World/Regions/Village/VillageBuildSpots").get_child_count() == 5, "all five current village build spots are scene-authored")
	_check(main.get_node("World/Regions/Village/Walls").get_child_count() == 0, "fake terrain-art walls are removed")
	_check(main._defense_build_definition("archer")["cost"] == ECONOMY_BALANCE.defense_definition("archer")["cost"], "defense prices use central data")
	_check(main._village_build_definition("farm")["cost"] == ECONOMY_BALANCE.village_definition("farm")["cost"], "village prices use central data")
	_check(main._get_wave_plan().size() == 3, "phase root reads the declared wave plan")

	main.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("Architecture verification: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		print("FAIL: %s" % description)
