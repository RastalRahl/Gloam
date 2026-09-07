extends Node2D
class_name GloamAnimatedSpriteVisual

const VISUALS := preload("res://scripts/visual_constants.gd")
const ASSET_CONFIG := preload("res://scripts/tiny_swords_asset_config.gd")

@export var pixel_scale: float = VISUALS.UNIT_SPRITE_SCALE

@onready var sprite: AnimatedSprite2D = $Sprite

var pending_animations: Array[Dictionary] = []
var pending_initial_animation: String = "idle"
var authored_anchor_offset: Vector2 = Vector2.ZERO
var manual_sprite_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
    _apply_scale()

    if not pending_animations.is_empty():
        _build_sprite_frames()


# Each definition uses: name, texture, fps, loop. Tiny Swords frame metadata
# comes from the centralized asset registry; explicit overrides are supported
# for non-registry sheets.
func configure(
    animation_definitions: Array[Dictionary],
    initial_animation: String = "idle"
) -> void:
    pending_animations = animation_definitions
    pending_initial_animation = initial_animation

    if is_node_ready():
        _build_sprite_frames()


func play_action(action: String) -> void:
    if not is_instance_valid(sprite) or sprite.sprite_frames == null:
        return

    if sprite.sprite_frames.has_animation(action):
        sprite.play(action)


func set_facing_left(facing_left: bool) -> void:
    if is_instance_valid(sprite):
        sprite.flip_h = facing_left


func set_visual_scale(new_scale: float) -> void:
    pixel_scale = new_scale
    _apply_scale()


func set_sprite_offset(offset: Vector2) -> void:
    # Compatibility hook for non-grounded effects. Gameplay actors use the
    # measured TinySwords feet anchor automatically; this is only an additive
    # offset for a deliberate presentation adjustment.
    manual_sprite_offset = offset
    if is_instance_valid(sprite):
        _apply_scale()


func set_visual_tint(tint: Color) -> void:
    modulate = tint


func _apply_scale() -> void:
    if is_instance_valid(sprite):
        sprite.scale = Vector2.ONE * pixel_scale
        sprite.centered = true
        sprite.position = manual_sprite_offset - authored_anchor_offset * pixel_scale


func _build_sprite_frames() -> void:
    if not is_instance_valid(sprite):
        return

    var frames: SpriteFrames = SpriteFrames.new()
    authored_anchor_offset = Vector2.ZERO
    for definition: Dictionary in pending_animations:
        var definition_texture: Texture2D = definition.get("texture") as Texture2D
        var definition_layout: Dictionary = ASSET_CONFIG.layout_for_texture(definition_texture)
        if definition.has("anchor_offset"):
            authored_anchor_offset = definition["anchor_offset"] as Vector2
            break
        if not definition_layout.is_empty():
            authored_anchor_offset = definition_layout.get("anchor_offset", Vector2.ZERO)
            break

    for definition: Dictionary in pending_animations:
        var animation_name: String = str(definition.get("name", ""))
        var texture: Texture2D = definition.get("texture") as Texture2D
        if animation_name.is_empty() or texture == null:
            continue

        var layout: Dictionary = ASSET_CONFIG.layout_for_texture(texture)
        var frame_size: Vector2i = definition.get("frame_size", Vector2i.ZERO)
        var columns: int = int(definition.get("columns", 0))
        var rows: int = int(definition.get("rows", 1))
        var frame_count: int = int(definition.get("frame_count", 0))

        if not layout.is_empty() and not definition.has("frame_size"):
            frame_size = layout["frame_size"]
            columns = int(layout["columns"])
            rows = int(layout["rows"])
            frame_count = int(layout["frame_count"])

        if frame_size == Vector2i.ZERO or columns <= 0 or rows <= 0 or frame_count <= 0:
            push_error("Missing explicit frame layout for non-registry texture: %s" % animation_name)
            continue

        var expected_size := Vector2i(frame_size.x * columns, frame_size.y * rows)
        var actual_size := Vector2i(texture.get_width(), texture.get_height())
        if actual_size != expected_size or frame_count > columns * rows:
            push_error("Invalid frame layout for %s: expected %s, got %s" % [animation_name, expected_size, actual_size])
            continue

        frames.add_animation(animation_name)
        frames.set_animation_speed(animation_name, float(definition.get("fps", 8.0)))
        frames.set_animation_loop(animation_name, bool(definition.get("loop", true)))

        for frame_index: int in range(frame_count):
            var atlas: AtlasTexture = AtlasTexture.new()
            atlas.atlas = texture
            atlas.region = Rect2(
                (frame_index % columns) * frame_size.x,
                (frame_index / columns) * frame_size.y,
                frame_size.x,
                frame_size.y
            )
            frames.add_frame(animation_name, atlas)

    sprite.sprite_frames = frames
    _apply_scale()

    if frames.has_animation(pending_initial_animation):
        sprite.play(pending_initial_animation)
    elif frames.get_animation_names().size() > 0:
        sprite.play(frames.get_animation_names()[0])
