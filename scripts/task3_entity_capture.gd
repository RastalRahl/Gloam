extends SceneTree

## Deterministic final visual verification for the gameplay-scale integration.
## The captures use the real main scene and only add a frozen showcase ring so
## every gameplay entity family can be reviewed at the camera's normal framing.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const VISUALS := preload("res://scripts/visual_constants.gd")
const COLLISION_OVERLAY := preload("res://scripts/task3_collision_overlay.gd")

const SHOWCASE_SCENES: Dictionary = {
    "house": preload("res://scenes/house.tscn"),
    "farm": preload("res://scenes/farm.tscn"),
    "barracks": preload("res://scenes/barracks_building.tscn"),
    "blacksmith": preload("res://scenes/blacksmith.tscn"),
    "archer_tower": preload("res://scenes/archer_tower.tscn"),
    "ballista": preload("res://scenes/ballista.tscn"),
    "barricade": preload("res://scenes/barricade.tscn"),
    "shrine": preload("res://scenes/shrine.tscn"),
    "survivor": preload("res://scenes/survivor.tscn"),
    "guard": preload("res://scenes/guard.tscn"),
    "archer": preload("res://scenes/archer_soldier.tscn"),
    "skull": preload("res://scenes/enemy.tscn"),
    "troll": preload("res://scenes/enemy_brute.tscn"),
    "gnoll": preload("res://scenes/enemy_ranged.tscn"),
    "bat": preload("res://scenes/forest_enemy.tscn"),
    "spider": preload("res://scenes/mine_enemy.tscn"),
    "wraith": preload("res://scenes/ruins_enemy.tscn"),
    "grave_ox": preload("res://scenes/grave_ox.tscn"),
}

var main_scene: Node
var showcase_nodes: Array[Node] = []


func _initialize() -> void:
    call_deferred("_run_capture")


func _run_capture() -> void:
    RenderingServer.set_default_clear_color(Color("162232"))
    main_scene = MAIN_SCENE.instantiate()
    main_scene.day_duration = 999.0
    main_scene.night_duration = 999.0
    main_scene.final_boss_spawn_delay = 999.0
    main_scene.exploration_debug_seed = 11
    root.add_child(main_scene)

    await _frames(12)
    main_scene._choose_starting_weapon("sword")
    await _frames(8)
    main_scene.player.global_position = Vector2(260, 1300)
    _add_showcase()
    await _frames(8)
    await _capture("res://visual_comparison/task3_entities_normal.png")

    var overlay := COLLISION_OVERLAY.new() as GloamTask3CollisionOverlay
    overlay.name = "Task3CollisionOverlay"
    main_scene.add_child(overlay)
    overlay.configure(main_scene)
    await _frames(4)
    await _capture("res://visual_comparison/task3_entities_debug_collisions.png")
    overlay.queue_free()

    main_scene._start_night()
    await _frames(10)
    main_scene.player.global_position = Vector2(260, 1300)
    await _frames(6)
    await _capture("res://visual_comparison/task3_night_scale.png")

    _print_calibration_report()
    quit()


func _add_showcase() -> void:
    _add("house", Vector2(92, 1325), main_scene.get_node("VillageBuildings"))
    _add("farm", Vector2(430, 1325), main_scene.get_node("VillageBuildings"))
    _add("barracks", Vector2(92, 1080), main_scene.get_node("VillageBuildings"))
    _add("blacksmith", Vector2(430, 1080), main_scene.get_node("VillageBuildings"))
    _add("archer_tower", Vector2(155, 1045), main_scene.get_node("Defenses"))
    _add("ballista", Vector2(370, 1045), main_scene.get_node("Defenses"))
    _add("barricade", Vector2(500, 1320), main_scene.get_node("Defenses"))
    _add("shrine", Vector2(560, 1320), main_scene.get_node("Shrines"))
    _add("guard", Vector2(170, 1255), main_scene.get_node("Soldiers"))
    _add("archer", Vector2(350, 1255), main_scene.get_node("Soldiers"))
    _add("survivor", Vector2(260, 1360), main_scene.get_node("Survivors"))

    _add_enemy("skull", Vector2(125, 1380), main_scene.get_node("Enemies"))
    _add_enemy("troll", Vector2(300, 1380), main_scene.get_node("Enemies"))
    _add_enemy("gnoll", Vector2(475, 1380), main_scene.get_node("Enemies"))
    _add_enemy("bat", Vector2(55, 1260), main_scene.get_node("DayEnemies"))
    _add_enemy("spider", Vector2(520, 1150), main_scene.get_node("DayEnemies"))
    _add_enemy("wraith", Vector2(520, 1235), main_scene.get_node("DayEnemies"))
    _add_enemy("grave_ox", Vector2(520, 1370), main_scene.get_node("Enemies"))

    for node: Node in showcase_nodes:
        if node.has_method("set_targets"):
            node.set_targets(main_scene.village_core, main_scene.player)
        if node.has_method("set_player"):
            node.set_player(main_scene.player)
        if node is CharacterBody2D:
            (node as CharacterBody2D).velocity = Vector2.ZERO
        node.set_process(false)
        node.set_physics_process(false)


func _add(scene_key: String, position: Vector2, parent: Node) -> Node:
    var instance: Node = (SHOWCASE_SCENES[scene_key] as PackedScene).instantiate()
    instance.name = "Task3_%s" % scene_key
    parent.add_child(instance)
    if instance is Node2D:
        (instance as Node2D).global_position = position
    showcase_nodes.append(instance)
    return instance


func _add_enemy(scene_key: String, position: Vector2, parent: Node) -> Node:
    var instance := _add(scene_key, position, parent)
    if scene_key == "bat":
        (instance as GloamDayEnemy).zone_type = "forest"
    elif scene_key == "spider":
        (instance as GloamDayEnemy).zone_type = "mine"
    elif scene_key == "wraith":
        (instance as GloamDayEnemy).zone_type = "ruins"
    return instance


func _frames(count: int) -> void:
    for _index: int in range(count):
        await process_frame


func _capture(path: String) -> void:
    await RenderingServer.frame_post_draw
    var image := root.get_viewport().get_texture().get_image()
    var result := image.save_png(path)
    if result != OK:
        push_error("Task3 capture failed: %s" % path)
    else:
        print("Task3 capture: %s" % path)


func _print_calibration_report() -> void:
    print("Task3 scales: unit=%0.2f lancer=%0.2f large=%0.2f castle=%0.2f building=%0.2f tree=%0.2f camera=%s" % [
        VISUALS.UNIT_SPRITE_SCALE,
        VISUALS.LANCER_SPRITE_SCALE,
        VISUALS.LARGE_ENEMY_SPRITE_SCALE,
        VISUALS.BUILDING_SPRITE_SCALE,
        VISUALS.SMALL_BUILDING_SPRITE_SCALE,
        VISUALS.TREE_SPRITE_SCALE,
        str(VISUALS.CAMERA_ZOOM),
    ])
