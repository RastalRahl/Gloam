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
	main._clear_day_enemies()
	main.wood = 100
	main.stone = 100
	main.iron = 100
	main._spawn_soldier("guard")
	await process_frame
	var guard: GloamSoldier = main.get_node("Soldiers").get_child(0) as GloamSoldier
	var blacksmith_spot: GloamVillageBuildSpot = main.get_node("World/Regions/Village/VillageBuildSpots").get_child(0) as GloamVillageBuildSpot
	var barracks_spot: GloamVillageBuildSpot = main.get_node("World/Regions/Village/VillageBuildSpots").get_child(1) as GloamVillageBuildSpot
	var house_spot: GloamVillageBuildSpot = main.get_node("World/Regions/Village/VillageBuildSpots").get_child(2) as GloamVillageBuildSpot
	var farm_spot: GloamVillageBuildSpot = main.get_node("World/Regions/Village/VillageBuildSpots").get_child(3) as GloamVillageBuildSpot

	_check(main.player.projectile_damage == 2, "sword base damage starts at 2")
	_check(guard.attack_damage == 2, "guard base damage starts at 2")

	await _build(main, blacksmith_spot, "blacksmith")
	_check(main.blacksmith_built and main.blacksmith_bonus_damage == 1, "level 1 blacksmith activates once")
	_check(main.player.projectile_damage == 3 and guard.attack_damage == 3, "level 1 blacksmith updates hero and soldier")
	_check(main.damage_label.text == "DMG 3", "hero damage UI matches level 1 blacksmith")

	await _upgrade(main, blacksmith_spot)
	_check(blacksmith_spot.building.level == 2, "blacksmith upgrades to level 2")
	_check(main.blacksmith_bonus_damage == 2, "level 2 blacksmith bonus is derived once")
	_check(main.player.projectile_damage == 4 and guard.attack_damage == 4, "level 2 blacksmith updates existing actors")

	# Earth upgrades now follow the same gated progression as the live level-up
	# menu: unlock the first tier before applying the second-tier damage bonus.
	main.player.apply_upgrade("earth_force")
	main.player.apply_upgrade("earth_weight")
	_check(main.player.projectile_damage == 5, "elemental damage remains independent of blacksmith damage")

	var upgraded_blacksmith: GloamVillageBuilding = blacksmith_spot.building
	await _destroy(upgraded_blacksmith)
	_check(not main.blacksmith_built and main.blacksmith_bonus_damage == 0, "destroyed blacksmith removes active bonus")
	_check(main.player.projectile_damage == 3 and guard.attack_damage == 2, "destroyed blacksmith preserves base and elemental damage")
	_check(main.damage_label.text == "DMG 3", "hero damage UI updates immediately after destruction")
	_check(main.blacksmith_label.text.contains("NONE") and main.blacksmith_label.text.contains("+0 DMG"), "blacksmith UI shows no active damage bonus")
	_check(blacksmith_spot.building == null and not blacksmith_spot.occupied, "destroyed blacksmith spot is reusable")

	await _build(main, blacksmith_spot, "blacksmith")
	_check(main.blacksmith_built and main.blacksmith_bonus_damage == 1, "rebuilt level 1 blacksmith applies once")
	_check(main.player.projectile_damage == 4 and guard.attack_damage == 3, "rebuilt blacksmith does not duplicate bonus")
	_check(main.blacksmith_label.text.contains("READY") and main.blacksmith_label.text.contains("+1 DMG"), "blacksmith UI matches active bonus")

	await _build(main, barracks_spot, "barracks")
	await _upgrade(main, barracks_spot)
	_check(main.barracks_built and main.barracks_training_bonus == 1, "level 2 barracks bonus is derived once")
	_check(guard.attack_damage == 4, "barracks bonus reaches existing soldier")
	main._spawn_soldier("archer")
	await process_frame
	var archer: GloamSoldier = main.get_node("Soldiers").get_child(1) as GloamSoldier
	_check(archer.attack_damage == 3, "new soldier receives same active infrastructure bonus")

	var upgraded_barracks: GloamVillageBuilding = barracks_spot.building
	await _destroy(upgraded_barracks)
	_check(not main.barracks_built and main.barracks_training_bonus == 0, "destroyed barracks removes training bonus")
	_check(guard.attack_damage == 3 and archer.attack_damage == 2, "destroyed barracks updates existing soldiers")
	_check(barracks_spot.building == null and not barracks_spot.occupied, "destroyed barracks spot is reusable")

	await _build(main, barracks_spot, "barracks")
	_check(main.barracks_built and main.barracks_training_bonus == 0, "rebuilt level 1 barracks applies no old upgrade")
	_check(guard.attack_damage == 3 and archer.attack_damage == 2, "rebuilt barracks does not duplicate training bonus")

	await _build(main, house_spot, "house")
	await _upgrade(main, house_spot)
	_check(main.population_capacity == 11, "level 2 house capacity is derived")
	main.total_population = 10
	main._update_population_ui()
	var upgraded_house: GloamVillageBuilding = house_spot.building
	await _destroy(upgraded_house)
	_check(main.houses == 0 and main.population_capacity == 10, "house destruction grandfather policy avoids contradictory capacity")
	_check(main.total_population >= 0 and main.population_capacity >= main.total_population, "excess population remains nonnegative and valid")

	await _build(main, house_spot, "house")
	_check(main.houses == 1 and main.population_capacity == 10, "rebuilt house restores derived capacity without population duplication")

	await _build(main, farm_spot, "farm")
	await _upgrade(main, farm_spot)
	_check(main.farm_food_income == 5, "level 2 farm income is derived")
	var upgraded_farm: GloamVillageBuilding = farm_spot.building
	await _destroy(upgraded_farm)
	_check(main.farms == 0 and main.farm_food_income == 0, "farm destruction removes income")
	await _build(main, farm_spot, "farm")
	_check(main.farms == 1 and main.farm_food_income == 3, "rebuilt farm restores level 1 income once")

	_check(main.wood >= 0 and main.stone >= 0 and main.iron >= 0 and main.food >= 0, "resources never become negative")
	_check(main.population_capacity >= 0 and main.farm_food_income >= 0, "capacity and income never become negative")

	main.queue_free()
	await process_frame
	# Let the generated UI tone playback release before the process exits.
	await create_timer(0.25).timeout
	print("SETTLEMENT REGRESSION: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _build(main: Node2D, spot: GloamVillageBuildSpot, kind: String) -> void:
	main.active_village_build_spot = spot
	main._try_build_village_building(kind)
	await process_frame


func _upgrade(main: Node2D, spot: GloamVillageBuildSpot) -> void:
	main.active_village_build_spot = spot
	main._upgrade_village_building()
	await process_frame


func _destroy(building: GloamVillageBuilding) -> void:
	building.take_damage(999999)
	await process_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		print("FAIL: %s" % description)
