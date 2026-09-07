extends Node2D

var marks: Array[Dictionary] = []


func configure(new_marks: Array[Dictionary]) -> void:
    marks = new_marks
    queue_redraw()


func _draw() -> void:
    for mark: Dictionary in marks:
        var anchor: Vector2 = mark.get("anchor", Vector2.ZERO)
        var footprint: Vector2 = mark.get("footprint", Vector2.ZERO)
        var color: Color = mark.get("color", Color(1.0, 0.8, 0.3, 0.85))
        var top_left := anchor - Vector2(footprint.x * 0.5, footprint.y)
        draw_rect(Rect2(top_left, footprint), color, false, 2.0)
        draw_line(anchor - Vector2(8.0, 0.0), anchor + Vector2(8.0, 0.0), color, 2.0)
        draw_line(anchor - Vector2(0.0, 8.0), anchor + Vector2(0.0, 8.0), color, 2.0)
        draw_circle(anchor, 3.0, color)
