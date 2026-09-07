extends StaticBody2D
class_name GloamGroundFootprint

## A compact, ground-contact-only collision for a visual entity.
## The sprite, hurtbox, and attack range intentionally remain separate.
var footprint_size: Vector2 = Vector2(18, 10)


func setup(new_size: Vector2, new_layer: int = 8) -> GloamGroundFootprint:
    footprint_size = new_size
    collision_layer = new_layer
    collision_mask = 0
    set_meta("collision_category", "prop")
    add_to_group("prop_collision")
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = footprint_size
    collision.shape = shape
    collision.position = Vector2(0.0, -footprint_size.y * 0.5)
    add_child(collision)
    return self
