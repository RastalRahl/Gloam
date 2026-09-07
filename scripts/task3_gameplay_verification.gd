extends SceneTree

## Gameplay-scale smoke test for the final entity collision contract.
## Movement uses the real scene's active footprint layers; combat uses the
## separated Area2D hurtboxes and the existing melee/projectile code paths.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const HOUSE_SCENE := preload("res://scenes/house.tscn")
const RESOURCE_SCENE := preload("res://scenes/resource_node.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const BRUTE_SCENE := preload("res://scenes/enemy_brute.tscn")
const GATE_SCENE := preload("res://scenes/gate.tscn")
const ENEMY_PROJECTILE_SCENE := preload("res://scenes/enemy_projectile.tscn")

var failures: int = 0
var main_scene: Node2D
var temporary_nodes: Array[Node] = []


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    main_scene = MAIN_SCENE.instantiate() as Node2D
    main_scene.day_duration = 999.0
    main_scene.night_duration = 999.0
    main_scene.final_boss_spawn_delay = 999.0
    main_scene.exploration_debug_seed = 11
    root.add_child(main_scene)
    current_scene = main_scene
    await process_frame
    paused = false
    main_scene._choose_starting_weapon("bow")
    await _physics_frames(3)
    main_scene.player.set_physics_process(false)

    await _test_tree_footprint()
    await _test_building_footprint()
    await _test_wall_and_gate_routes()
    await _test_resource_and_enemy_separation()
    await _test_projectile_hurtbox()
    await _test_melee_hurtboxes()
    await _test_permanent_obstacle_projectile_blocking()
    await _test_gate_breach_collision()

    for node: Node in temporary_nodes:
        if is_instance_valid(node):
            node.queue_free()
    temporary_nodes.clear()
    if is_instance_valid(main_scene):
        main_scene._cancel_pending_wave_work("task3 gameplay verification cleanup")
        main_scene.queue_free()
    await process_frame
    main_scene = null
    current_scene = null
    await process_frame
    await process_frame
    await create_timer(0.1).timeout

    print("Task3 gameplay verification: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
    quit(1 if failures > 0 else 0)


func _test_tree_footprint() -> void:
    var authored_tree := main_scene.get_node_or_null("World/Regions/Forest/Props/ForestTreeWest02") as Node2D
    _check(authored_tree != null, "authored tree footprint probe resolves a current forest tree")
    if authored_tree == null:
        return
    var tree_anchor := authored_tree.global_position
    var stopped_position := await _move_to(tree_anchor + Vector2(-55, 0), tree_anchor + Vector2(55, 0))
    _check(stopped_position.x < tree_anchor.x - 8.0, "tree movement footprint blocks at the trunk")


func _test_building_footprint() -> void:
    var house := HOUSE_SCENE.instantiate() as Node2D
    house.global_position = Vector2(850, 1180)
    main_scene.get_node("VillageBuildings").add_child(house)
    temporary_nodes.append(house)
    await _physics_frames(2)
    var stopped_position := await _move_to(Vector2(780, 1180), Vector2(920, 1180))
    _check(stopped_position.x < 850.0 - 30.0, "building foundation footprint blocks below the roof")


func _test_wall_and_gate_routes() -> void:
    var gate_exit := await _move_to(Vector2(450, 1190), Vector2(560, 1190))
    _check(gate_exit.x > 540.0, "authored east passage remains traversable by the player during day")


func _test_resource_and_enemy_separation() -> void:
    var resource := RESOURCE_SCENE.instantiate() as Area2D
    resource.resource_type = "wood"
    resource.global_position = Vector2(700, 1180)
    main_scene.get_node("Resources").add_child(resource)
    temporary_nodes.append(resource)
    await _physics_frames(2)
    var resource_pass := await _move_to(Vector2(650, 1180), Vector2(750, 1180))
    _check(resource_pass.x > 735.0, "resource pickup does not become a movement wall")

    var enemy := ENEMY_SCENE.instantiate() as GloamEnemy
    enemy.global_position = Vector2(800, 1300)
    main_scene.get_node("Enemies").add_child(enemy)
    temporary_nodes.append(enemy)
    await _physics_frames(2)
    var enemy_pass := await _move_to(Vector2(750, 1300), Vector2(850, 1300))
    _check(enemy_pass.x > 835.0, "enemy movement footprint stays separate from player movement")


func _test_projectile_hurtbox() -> void:
    var enemy := ENEMY_SCENE.instantiate() as GloamEnemy
    enemy.global_position = Vector2(410, 1100)
    main_scene.get_node("Enemies").add_child(enemy)
    temporary_nodes.append(enemy)
    await _physics_frames(3)
    main_scene.player.global_position = Vector2(250, 1100)
    main_scene.player.choose_weapon("bow")
    main_scene.player._perform_bow_attack(Vector2.RIGHT)
    await _physics_frames(30)
    _check(enemy.hp < enemy.max_hp, "projectile reaches the enemy hurtbox")


func _test_melee_hurtboxes() -> void:
    var enemy := ENEMY_SCENE.instantiate() as GloamEnemy
    enemy.global_position = Vector2(320, 1100)
    main_scene.get_node("Enemies").add_child(enemy)
    temporary_nodes.append(enemy)
    await _physics_frames(3)
    main_scene.player.global_position = Vector2(250, 1100)
    main_scene.player.choose_weapon("sword")
    main_scene.player._perform_melee_attack(Vector2.RIGHT)
    await _physics_frames(2)
    _check(enemy.hp < enemy.max_hp, "melee query reaches the enemy hurtbox")

    var brute := BRUTE_SCENE.instantiate() as GloamEnemy
    brute.global_position = Vector2(365, 1100)
    main_scene.get_node("Enemies").add_child(brute)
    temporary_nodes.append(brute)
    await _physics_frames(3)
    main_scene.player.choose_weapon("spear")
    main_scene.player._perform_melee_attack(Vector2.RIGHT)
    await _physics_frames(2)
    _check(brute.hp < brute.max_hp, "large enemy receives a larger hurtbox without a square movement collider")


func _test_permanent_obstacle_projectile_blocking() -> void:
    for day_enemy: Node in main_scene.get_node("DayEnemies").get_children():
        day_enemy.set_process(false)
        day_enemy.set_physics_process(false)

    var gate := GATE_SCENE.instantiate() as GloamGate
    gate.global_position = Vector2(700, 1190)
    main_scene.get_node("World/Regions/Village/Gates").add_child(gate)
    temporary_nodes.append(gate)

    var enemy := ENEMY_SCENE.instantiate() as GloamEnemy
    enemy.global_position = Vector2(790, 1180)
    main_scene.get_node("Enemies").add_child(enemy)
    temporary_nodes.append(enemy)
    await _physics_frames(3)

    main_scene.player.global_position = Vector2(610, 1180)
    main_scene.player.choose_weapon("bow")
    var enemy_hp_before: int = enemy.hp
    main_scene.player._perform_bow_attack(Vector2.RIGHT)
    await _physics_frames(30)
    _check(enemy.hp == enemy_hp_before, "friendly projectile stops at an intact gate")

    var hostile := ENEMY_PROJECTILE_SCENE.instantiate() as GloamEnemyProjectile
    hostile.global_position = Vector2(790, 1180)
    hostile.setup(main_scene.player, Vector2.LEFT, 9, 310.0)
    main_scene.add_child(hostile)
    temporary_nodes.append(hostile)
    var player_hp_before: int = main_scene.player.hp
    await _physics_frames(45)
    _check(main_scene.player.hp == player_hp_before, "hostile projectile stops at an intact gate")
    gate.take_damage(gate.max_hp)
    await _physics_frames(2)


func _test_gate_breach_collision() -> void:
    var gate := GATE_SCENE.instantiate() as GloamGate
    gate.global_position = Vector2(700, 1190)
    main_scene.get_node("World/Regions/Village/Gates").add_child(gate)
    temporary_nodes.append(gate)
    await _physics_frames(3)

    var footprint := gate.get_node("GateBlocker/CollisionShape2D") as CollisionShape2D
    _check(gate.blocks_monsters() and not footprint.disabled, "intact gate exposes its monster-blocking footprint")
    gate.take_damage(gate.max_hp)
    await _physics_frames(3)
    _check(gate.is_breached and footprint.disabled, "breached gate disables its physical footprint")

    gate.repair_full()
    await _physics_frames(2)
    _check(not gate.is_breached and not footprint.disabled, "gate repair restores its physical footprint")


func _move_to(start: Vector2, target: Vector2) -> Vector2:
    main_scene.player.global_position = start
    main_scene.player.velocity = Vector2.ZERO
    var previous_distance: float = INF
    var stalled: int = 0
    for _frame: int in range(120):
        await physics_frame
        var delta: Vector2 = target - main_scene.player.global_position
        main_scene.player.velocity = delta.normalized() * 760.0
        main_scene.player.move_and_slide()
        var distance: float = main_scene.player.global_position.distance_to(target)
        if distance >= previous_distance - 0.2:
            stalled += 1
        else:
            stalled = 0
        previous_distance = distance
        if distance <= 10.0 or stalled > 45:
            break
    main_scene.player.velocity = Vector2.ZERO
    return main_scene.player.global_position


func _physics_frames(count: int) -> void:
    for _index: int in range(count):
        await physics_frame


func _check(condition: bool, description: String) -> void:
    if condition:
        print("PASS: %s" % description)
    else:
        failures += 1
        print("FAIL: %s" % description)
