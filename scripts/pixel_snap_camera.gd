extends Camera2D
class_name GloamPixelSnapCamera

## Camera presentation for the TinySwords world.
##
## The camera stays at one orthographic scale in every phase.  Its local offset
## compensates for the followed parent's fractional position so the world
## transform lands on integer pixels without changing gameplay coordinates.

@export var stable_zoom: Vector2 = Vector2.ONE


func _ready() -> void:
	position_smoothing_enabled = false
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	zoom = stable_zoom
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _physics_process(_delta: float) -> void:
	var followed_parent := get_parent() as Node2D
	if not is_instance_valid(followed_parent):
		return
	var target_world_position := followed_parent.global_position.round()
	position = target_world_position - followed_parent.global_position
