extends Area2D
class_name GloamVillageBuildSpot

@onready var marker: Node2D = $ConstructionMarker

var occupied: bool = false
var player_inside: bool = false
var building: GloamVillageBuilding = null
var building_kind: String = ""


func _ready() -> void:
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)
    set_process(true)
    _refresh_marker()


func _process(_delta: float) -> void:
    _refresh_marker()


func _on_body_entered(body: Node) -> void:
    if body.name != "Player":
        return

    player_inside = true
    var main: Node = get_tree().current_scene

    if is_instance_valid(main) and main.has_method("set_active_village_build_spot"):
        main.set_active_village_build_spot(self)
    _refresh_marker()


func _on_body_exited(body: Node) -> void:
    if body.name != "Player":
        return

    player_inside = false
    var main: Node = get_tree().current_scene

    if is_instance_valid(main) and main.has_method("clear_active_village_build_spot"):
        main.clear_active_village_build_spot(self)
    _refresh_marker()


func assign_building(new_building: GloamVillageBuilding, kind: String) -> void:
    occupied = true
    building = new_building
    building_kind = kind

    if is_instance_valid(building) and building.has_signal("destroyed"):
        building.destroyed.connect(_on_building_destroyed)
    _refresh_marker()


func _on_building_destroyed(_building: Node) -> void:
    occupied = false
    building = null
    building_kind = ""
    var main: Node = get_tree().current_scene
    if is_instance_valid(main) and main.has_method("notify_interaction_target_changed"):
        main.notify_interaction_target_changed()
    _refresh_marker()


func _refresh_marker() -> void:
    if not is_instance_valid(marker):
        return
    var main: Node = get_tree().current_scene
    var day_active: bool = is_instance_valid(main) and main.has_method("_is_day_phase") and bool(main.call("_is_day_phase"))
    var affordable: bool = day_active
    if day_active and main.has_method("is_build_spot_affordable"):
        affordable = bool(main.call("is_build_spot_affordable", true))
    var selected: bool = day_active and main.get("active_village_build_spot") == self
    marker.set_state(selected, player_inside, affordable, occupied)
    marker.visible = day_active and not occupied
