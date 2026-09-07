extends Control
class_name GloamTinyUIFrame

const PAPER_TEXTURE := preload("res://assets/generated/tiny_swords/ui/papers/special_paper.png")
const BUTTON_TEXTURE := preload("res://assets/generated/tiny_swords/ui/buttons/big_blue_button_regular.png")
const BUTTON_PRESSED_TEXTURE := preload("res://assets/generated/tiny_swords/ui/buttons/big_blue_button_pressed.png")

@export var button_frame: bool = false
@export_range(0.0, 1.0, 0.05) var frame_opacity: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _process(_delta: float) -> void:
	if button_frame:
		queue_redraw()


func _draw() -> void:
	var texture: Texture2D = PAPER_TEXTURE

	if button_frame:
		var button: BaseButton = get_parent() as BaseButton
		texture = BUTTON_PRESSED_TEXTURE if is_instance_valid(button) and button.button_pressed else BUTTON_TEXTURE

	_draw_nine_slice(texture)


func _draw_nine_slice(texture: Texture2D) -> void:
	var corner: float = minf(12.0, minf(size.x, size.y) * 0.5)
	var middle: Rect2 = Rect2(corner, corner, maxf(0.0, size.x - corner * 2.0), maxf(0.0, size.y - corner * 2.0))
	var left: float = 19.0 if button_frame else 10.0
	var right: float = 256.0
	var top: float = 17.0 if button_frame else 20.0
	var bottom: float = 256.0
	var side_width: float = 45.0 if button_frame else 54.0
	var top_height: float = 47.0 if button_frame else 44.0
	var bottom_height: float = 47.0 if button_frame else 43.0

	_draw_piece(texture, Rect2(0, 0, corner, corner), Rect2(left, top, side_width, top_height))
	_draw_piece(texture, Rect2(corner, 0, middle.size.x, corner), Rect2(128, top, 64, top_height))
	_draw_piece(texture, Rect2(corner + middle.size.x, 0, corner, corner), Rect2(right, top, side_width, top_height))
	_draw_piece(texture, Rect2(0, corner, corner, middle.size.y), Rect2(left, 128, side_width, 64))
	_draw_piece(texture, middle, Rect2(128, 128, 64, 64))
	_draw_piece(texture, Rect2(corner + middle.size.x, corner, corner, middle.size.y), Rect2(right, 128, side_width, 64))
	_draw_piece(texture, Rect2(0, corner + middle.size.y, corner, corner), Rect2(left, bottom, side_width, bottom_height))
	_draw_piece(texture, Rect2(corner, corner + middle.size.y, middle.size.x, corner), Rect2(128, bottom, 64, bottom_height))
	_draw_piece(texture, Rect2(corner + middle.size.x, corner + middle.size.y, corner, corner), Rect2(right, bottom, side_width, bottom_height))


func _draw_piece(texture: Texture2D, destination: Rect2, source: Rect2) -> void:
	if destination.size.x > 0.0 and destination.size.y > 0.0:
		draw_texture_rect_region(texture, destination, source, Color(1.0, 1.0, 1.0, frame_opacity))
