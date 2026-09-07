extends Area2D
class_name GloamXpOrb

@export var xp_value: int = 1
@export var magnet_radius: float = 155.0
@export var magnet_speed: float = 430.0
@export var collect_radius: float = 24.0

var player: GloamPlayer


func _ready() -> void:
    body_entered.connect(_on_body_entered)
    player = get_tree().current_scene.get_node_or_null("Player") as GloamPlayer


func _physics_process(delta: float) -> void:
    if not is_instance_valid(player):
        var current_scene: Node = get_tree().current_scene
        if not is_instance_valid(current_scene):
            return

        player = current_scene.get_node_or_null("Player") as GloamPlayer
        return

    if player.is_downed:
        return

    var distance: float = global_position.distance_to(player.global_position)

    if distance <= magnet_radius:
        global_position = global_position.move_toward(
            player.global_position,
            magnet_speed * delta
        )

    if distance <= collect_radius:
        _collect(player)


func _on_body_entered(body: Node) -> void:
    var player_body: GloamPlayer = body as GloamPlayer
    if is_instance_valid(player_body) and player_body.is_downed:
        return

    if body.has_method("gain_xp"):
        _collect(body)


func _collect(body: Node) -> void:
    if not is_inside_tree():
        return

    var player_body: GloamPlayer = body as GloamPlayer
    if is_instance_valid(player_body) and player_body.is_downed:
        return

    if body.has_method("gain_xp"):
        body.gain_xp(xp_value)
        if not is_instance_valid(player_body) or not player_body.is_downed:
            queue_free()
