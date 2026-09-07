extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const ECONOMY_BALANCE := preload("res://scripts/economy_balance.gd")

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

	main.wood = 100
	main.stone = 100
	main.iron = 100
	main.essence = 10

	var defense_spot: GloamBuildSpot = main.get_node("World/Regions/Village/DefenseBuildSpots").get_child(0) as GloamBuildSpot
	main.player.global_position = defense_spot.global_position
	main.set_active_build_spot(defense_spot)
	_check(main.active_interaction_target == defense_spot, "defense spot becomes the active contextual target")
	_check(main.contextual_interaction_menu.prompt_button.visible, "one contextual prompt is visible")
	_check(main.contextual_interaction_menu.prompt_button.focus_mode == Control.FOCUS_ALL, "context prompt is keyboard/controller focusable")

	var accept_event := InputEventAction.new()
	accept_event.action = "interact"
	accept_event.pressed = true
	main._unhandled_input(accept_event)
	_check(main.interaction_menu_open and paused, "opening the contextual menu pauses daytime simulation")
	_check(main.contextual_interaction_menu.choice_buttons.size() == 3, "defense menu lists all available defenses")
	var archer_cost: Dictionary = ECONOMY_BALANCE.defense_definition("archer")["cost"]
	var archer_cost_text: String = main._cost_text(archer_cost)
	_check(main.contextual_interaction_menu.choice_buttons[0].text.contains("Cost: %s" % archer_cost_text), "defense cost is shown")
	_check(main.contextual_interaction_menu.choice_buttons[0].text.contains("Effect:"), "defense effect is shown")
	_check(main.contextual_interaction_menu.choice_buttons[0].focus_mode == Control.FOCUS_ALL, "choice buttons are keyboard/controller focusable")
	main.contextual_interaction_menu.choice_buttons[0].pressed.emit()
	main.contextual_interaction_menu.choice_buttons[0].pressed.emit()
	await process_frame
	_check(not main.interaction_menu_open and not paused, "a selection closes the menu safely")
	_check(main.get_node("Defenses").get_child_count() == 1, "held/repeated selection cannot build twice")
	_check(main.wood == 100 - int(archer_cost["wood"]), "shown defense cost matches the charged cost")
	var held_accept := InputEventAction.new()
	held_accept.action = "interact"
	held_accept.pressed = true
	main.contextual_interaction_menu._input(held_accept)
	main.contextual_interaction_menu._on_prompt_pressed()
	_check(not main.interaction_menu_open, "held accept cannot reopen a menu after a purchase")
	var released_accept := InputEventAction.new()
	released_accept.action = "interact"
	released_accept.pressed = false
	main.contextual_interaction_menu._input(released_accept)

	main._open_contextual_interaction()
	_check(main.contextual_interaction_menu.choice_buttons[0].text.contains("Repair"), "existing defense changes the menu to repair and upgrade")
	var cancel_event := InputEventAction.new()
	cancel_event.action = "menu_cancel"
	cancel_event.pressed = true
	cancel_event.pressed = true
	main.contextual_interaction_menu._unhandled_input(cancel_event)
	await process_frame
	_check(not main.interaction_menu_open and not paused, "controller close path unpauses safely")

	main.wood = 0
	main.stone = 0
	main.iron = 0
	var unaffordable_spot: GloamBuildSpot = main.get_node("World/Regions/Village/DefenseBuildSpots").get_child(1) as GloamBuildSpot
	defense_spot.player_inside = false
	unaffordable_spot.player_inside = true
	main.player.global_position = unaffordable_spot.global_position
	main._set_active_interaction_target(unaffordable_spot)
	main._open_contextual_interaction()
	_check(main.contextual_interaction_menu.choice_buttons[0].disabled, "unaffordable choices are disabled")
	_check(
		main.contextual_interaction_menu.choice_buttons[0].text.contains("Need %d more Wood" % int(archer_cost["wood"])),
		"unaffordable requirements are explained"
	)
	main.contextual_interaction_menu.close_menu()

	main.wood = 100
	main.stone = 100
	main.iron = 100
	var village_spot: GloamVillageBuildSpot = main.get_node("World/Regions/Village/VillageBuildSpots").get_child(0) as GloamVillageBuildSpot
	unaffordable_spot.player_inside = false
	main.player.global_position = village_spot.global_position
	main.set_active_village_build_spot(village_spot)
	main._open_contextual_interaction()
	_check(main.contextual_interaction_menu.choice_buttons.size() == 4, "village menu lists all available buildings")
	var blacksmith_cost: Dictionary = ECONOMY_BALANCE.village_definition("blacksmith")["cost"]
	_check(
		main.contextual_interaction_menu.choice_buttons[3].text.contains("Cost: %s" % main._cost_text(blacksmith_cost)),
		"building cost matches the build definition"
	)
	main.contextual_interaction_menu.choice_buttons[0].pressed.emit()
	await process_frame
	main._open_contextual_interaction()
	_check(main.contextual_interaction_menu.choice_buttons[0].text.contains("Repair"), "occupied village spot exposes repair and upgrade")
	main.contextual_interaction_menu.close_menu()

	var shrine: GloamShrine = main.get_node("Shrines").get_child(0) as GloamShrine
	main.player.hp = main.player.max_hp - 5
	main.essence = 10
	village_spot.player_inside = false
	main.player.global_position = shrine.global_position
	shrine.player_inside = true
	main.set_shrine_active(true, shrine)
	main._open_contextual_interaction()
	_check(main.contextual_interaction_menu.choice_buttons.size() == 3, "shrine menu lists healing, blessing, and ward")
	_check(main.contextual_interaction_menu.choice_buttons[0].text.contains("not a respawn"), "shrine healing distinguishes healing from respawning")
	main.contextual_interaction_menu.choice_buttons[0].pressed.emit()
	await process_frame
	_check(main.player.hp == main.player.max_hp and main.essence == 9, "shrine selection charges the displayed essence cost once")

	main.player.global_position = main.north_gate.global_position
	main.north_gate.hp = 1
	shrine.player_inside = false
	main._set_active_interaction_target(main.north_gate)
	main.wood = 100
	main.stone = 100
	main.iron = 100
	main._open_contextual_interaction()
	_check(main.contextual_interaction_menu.choice_buttons.size() == 2, "existing fortification lists repair and upgrade")
	var gate_repair_cost: Dictionary = main._fortification_repair_cost(main.north_gate)
	_check(
		main.contextual_interaction_menu.choice_buttons[0].text.contains("Cost: %s" % main._cost_text(gate_repair_cost)),
		"gate repair cost is shown from the same cost definition"
	)
	main.contextual_interaction_menu.choice_buttons[0].pressed.emit()
	await process_frame
	_check(
		main.north_gate.hp == main.north_gate.max_hp
			and main.wood == 100 - int(gate_repair_cost["wood"])
			and main.stone == 100 - int(gate_repair_cost["stone"]),
		"gate repair charges the matching cost"
	)

	var other_spot: GloamBuildSpot = main.get_node("World/Regions/Village/DefenseBuildSpots").get_child(1) as GloamBuildSpot
	defense_spot.player_inside = true
	other_spot.player_inside = true
	main.player.global_position = defense_spot.global_position
	main._set_active_interaction_target(null)
	main._update_interaction_target()
	_check(main.active_interaction_target == defense_spot, "overlapping candidates choose the nearest deterministic target")
	main._open_contextual_interaction()
	main.clear_active_build_spot(defense_spot)
	_check(not main.interaction_menu_open and not paused, "leaving the active zone closes the correct menu")

	main._start_night()
	await process_frame
	_check(not main.contextual_interaction_menu.prompt_button.visible, "night hides the contextual prompt")
	main._open_contextual_interaction()
	_check(not main.interaction_menu_open, "night rejects contextual construction and shrine use")
	main._cancel_pending_wave_work("contextual verification cleanup")

	main._start_day()
	var terminal_spot: GloamBuildSpot = main.get_node("World/Regions/Village/DefenseBuildSpots").get_child(2) as GloamBuildSpot
	terminal_spot.player_inside = true
	main._set_active_interaction_target(terminal_spot)
	main.wood = 100
	main._open_contextual_interaction()
	main._on_village_core_destroyed()
	_check(main.game_over and not main.interaction_menu_open and paused, "game over closes and blocks the contextual menu")

	main.queue_free()
	await process_frame
	# Let the generated UI tone playback release before the process exits.
	await create_timer(0.25).timeout
	print("Contextual interaction verification: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		print("FAIL: %s" % description)
