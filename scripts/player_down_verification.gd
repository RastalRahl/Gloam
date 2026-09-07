extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const XP_ORB_SCENE := preload("res://scenes/xp_orb.tscn")
const RESOURCE_NODE_SCENE := preload("res://scenes/resource_node.tscn")

var passed: bool = true


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

    var player: GloamPlayer = main.player
    main.wood = 100
    main.stone = 100
    main.iron = 100
    player.hp = player.max_hp
    player.respawn_delay = 0.5
    player.begin_night_respawn_cycle()
    main._refresh_shrine_prompt()
    _check(main.shrine_prompt.text.contains("Full heal (not respawn)"), "shrine UI distinguishes healing from respawning")

    _check(is_equal_approx(player._get_respawn_duration(1), 0.5), "first night down uses base respawn delay")
    _check(is_equal_approx(player._get_respawn_duration(2), 5.0), "second night down uses 5 second delay")
    _check(is_equal_approx(player._get_respawn_duration(3), 7.0), "third night down uses capped 7 second delay")
    player.respawn_delay = 3.0
    _check(is_equal_approx(player._get_respawn_duration(1), 3.0), "default first night down is 3 seconds")
    player.respawn_delay = 0.5

    player.take_damage(player.max_hp)
    await process_frame
    _check(player.is_downed and player.respawn_pending, "first down enters one pending respawn state")
    _check(is_equal_approx(player.respawn_duration, 0.5), "first down schedules the configured base delay")
    _check(player.respawn_down_number == 1 and player.get_next_respawn_delay() == 5.0, "first down communicates escalation to 5 seconds")
    _check(main.downed_label.visible and main.downed_label.text.contains("Next night down: 5 seconds"), "downed UI communicates the next night penalty")

    var first_countdown: float = player.respawn_time_left
    await create_timer(0.02).timeout
    _check(player.respawn_time_left < first_countdown, "respawn countdown decreases live")
    _check(player.global_position == player.spawn_position, "downed player remains at the down location until respawn")

    await create_timer(0.60).timeout
    await process_frame
    _check(not player.is_downed and not player.respawn_pending, "first respawn completes")
    _check(player.hp == player.max_hp and player.global_position == player.spawn_position, "respawn restores full health at the village")

    player.hp = player.max_hp
    player.take_damage(player.max_hp)
    await process_frame
    _check(is_equal_approx(player.respawn_duration, 5.0), "second down in the night escalates to 5 seconds")
    _check(player.get_next_respawn_delay() == 7.0, "second down communicates escalation to 7 seconds")
    player.cancel_respawn()
    player._respawn()
    await process_frame

    player.hp = player.max_hp
    player.take_damage(player.max_hp)
    await process_frame
    _check(is_equal_approx(player.respawn_duration, 7.0), "third down in the night reaches the 7 second cap")
    _check(player.get_next_respawn_delay() == 7.0, "further night downs remain capped at 7 seconds")

    var xp_before: int = player.xp
    var food_before: int = main.food
    main.essence = 10
    var essence_before: int = main.essence
    player.velocity = Vector2(100.0, 100.0)
    player._physics_process(0.1)
    _check(player.velocity == Vector2.ZERO, "downed movement is blocked")
    var projectiles_before: int = _count_projectiles()
    player._try_attack()
    _check(_count_projectiles() == projectiles_before, "downed attacks do not spawn projectiles")

    _check(not main.try_collect_resource("wood", 1), "downed player cannot collect resources")
    _check(main.food == food_before, "resource collection does not alter unrelated resources while downed")
    _check(not main.try_rescue_villager(), "downed player cannot rescue villagers")
    main.essence = 10
    main._buy_shrine_heal()
    _check(main.essence == essence_before, "downed player cannot buy shrine healing")
    var defense_count_before: int = main.get_node("Defenses").get_child_count()
    main.active_build_spot = main.get_node("World/Regions/Village/DefenseBuildSpots").get_child(0)
    main._try_build("archer")
    _check(main.get_node("Defenses").get_child_count() == defense_count_before, "downed player cannot build defenses")
    var village_building_count_before: int = main.get_node("VillageBuildings").get_child_count()
    main.active_village_build_spot = main.get_node("World/Regions/Village/VillageBuildSpots").get_child(0)
    main._try_build_village_building("house")
    _check(main.get_node("VillageBuildings").get_child_count() == village_building_count_before, "downed player cannot build village structures")
    player.gain_xp(1)
    _check(player.xp == xp_before, "downed player cannot gain XP directly")

    var orb: GloamXpOrb = XP_ORB_SCENE.instantiate() as GloamXpOrb
    root.add_child(orb)
    orb._collect(player)
    _check(is_instance_valid(orb) and player.xp == xp_before, "downed player cannot collect XP orbs")

    var resource: GloamResourceNode = RESOURCE_NODE_SCENE.instantiate() as GloamResourceNode
    root.add_child(resource)
    resource._on_body_entered(player)
    _check(is_instance_valid(resource) and main.wood == 100, "downed player cannot collect resource nodes")

    player.cancel_respawn()
    player._respawn()
    main._start_day()
    _check(player.downs_this_night == 0 and not player.night_respawn_penalty_active, "dawn resets the night respawn escalation")

    player.hp = player.max_hp
    player.take_damage(player.max_hp)
    await process_frame
    _check(is_equal_approx(player.respawn_duration, 0.5), "next day starts again at the base respawn delay")
    player.cancel_respawn()
    player._respawn()
    await process_frame

    main._start_night()
    player.hp = player.max_hp
    player.take_damage(player.max_hp)
    await process_frame
    _check(player.is_downed and player.respawn_pending, "night down is pending before terminal state")
    main._spawn_enemy_in_lane("north")
    await process_frame
    _check(main.night_schedule_active and main.wave_director.required_alive_count() > 0, "night assault spawning continues while the player is down")
    var spawned_enemy: Node = main.get_node("Enemies").get_child(0)
    _check(spawned_enemy._choose_target() != player, "enemies do not target the downed player")

    paused = true
    var paused_countdown: float = player.respawn_time_left
    await create_timer(0.12).timeout
    _check(player.is_downed and is_equal_approx(player.respawn_time_left, paused_countdown), "pause freezes the pending respawn countdown")
    paused = false

    main.current_day = main.nights_to_survive
    main.final_night_survival_complete = true
    main.final_boss_defeated = true
    main._win_run()
    paused = false
    await create_timer(0.12).timeout
    _check(main.current_phase == 2 and not player.respawn_pending and player.is_downed, "victory cancels pending respawn without reviving")

    main.queue_free()
    await process_frame

    var game_over_main: Node2D = MAIN_SCENE.instantiate() as Node2D
    root.add_child(game_over_main)
    current_scene = game_over_main
    await process_frame
    paused = false
    game_over_main._choose_starting_weapon("sword")
    await process_frame
    var game_over_player: GloamPlayer = game_over_main.player
    game_over_player.respawn_delay = 0.5
    game_over_player.begin_night_respawn_cycle()
    game_over_player.take_damage(game_over_player.max_hp)
    await process_frame
    _check(game_over_player.is_downed and game_over_player.respawn_pending, "game over scenario starts with a pending respawn")
    game_over_main._on_village_core_destroyed()
    paused = false
    await create_timer(0.12).timeout
    await process_frame
    _check(game_over_main.game_over and not game_over_player.respawn_pending and game_over_player.is_downed, "game over cancels pending respawn without reviving")

    orb.queue_free()
    resource.queue_free()
    game_over_main.queue_free()
    await process_frame
    # Let the generated terminal-state tones release before the process exits.
    await create_timer(0.25).timeout

    print("Player-down verification: %s" % ("PASS" if passed else "FAIL"))
    quit(0 if passed else 1)


func _check(condition: bool, description: String) -> void:
    if condition:
        print("PASS: %s" % description)
    else:
        passed = false
        print("FAIL: %s" % description)


func _count_projectiles() -> int:
    var count: int = 0
    for node in root.get_children():
        if node is GloamProjectile:
            count += 1

    return count
