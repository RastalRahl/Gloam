extends RefCounted
class_name GloamUIStyle

const COMPACT_CONTENT_MARGIN := 13.0
const MODAL_CONTENT_MARGIN := 22.0
const BUTTON_CONTENT_MARGIN_HORIZONTAL := 14.0
const BUTTON_CONTENT_MARGIN_VERTICAL := 9.0

const PAPER_PANEL := preload("res://assets/generated/tiny_swords/ui/papers/special_paper.png")
const MODAL_PAPER := preload("res://assets/generated/tiny_swords/ui/papers/regular_paper.png")
const BLUE_BUTTON := preload("res://assets/generated/tiny_swords/ui/buttons/big_blue_button_regular.png")
const BLUE_BUTTON_PRESSED := preload("res://assets/generated/tiny_swords/ui/buttons/big_blue_button_pressed.png")
const RED_BUTTON := preload("res://assets/generated/tiny_swords/ui/buttons/big_red_button_regular.png")
const RED_BUTTON_PRESSED := preload("res://assets/generated/tiny_swords/ui/buttons/big_red_button_pressed.png")
const BAR_BASE := preload("res://assets/generated/tiny_swords/ui/bars/big_bar_base.png")


static func create_theme() -> Theme:
    var theme_resource: Theme = Theme.new()

    theme_resource.default_font_size = 12

    # General text.
    theme_resource.set_color("font_color", "Label", Color(0.89, 0.86, 0.77, 1.0))
    theme_resource.set_color("font_shadow_color", "Label", Color(0.0, 0.0, 0.0, 0.65))
    theme_resource.set_constant("shadow_offset_x", "Label", 1)
    theme_resource.set_constant("shadow_offset_y", "Label", 1)
    theme_resource.set_constant("outline_size", "Label", 0)

    # Containers.
    theme_resource.set_constant("separation", "VBoxContainer", 4)
    theme_resource.set_constant("separation", "HBoxContainer", 5)
    theme_resource.set_stylebox(
        "panel",
        "PanelContainer",
        _make_panel_style(Color(0.045, 0.070, 0.085, 0.88), Color(0.55, 0.42, 0.18, 0.92), 6, 8)
    )

    # Buttons.
    theme_resource.set_color("font_color", "Button", Color(0.90, 0.87, 0.78, 1.0))
    theme_resource.set_color("font_hover_color", "Button", Color(1.0, 0.92, 0.67, 1.0))
    theme_resource.set_color("font_pressed_color", "Button", Color(1.0, 0.95, 0.77, 1.0))
    theme_resource.set_color("font_disabled_color", "Button", Color(0.48, 0.47, 0.43, 1.0))

    theme_resource.set_stylebox(
        "normal",
        "Button",
        _make_button_style(Color(0.055, 0.115, 0.13, 0.98), Color(0.28, 0.52, 0.58, 0.95))
    )
    theme_resource.set_stylebox(
        "hover",
        "Button",
        _make_button_style(Color(0.11, 0.18, 0.18, 1.0), Color(0.90, 0.67, 0.24, 1.0))
    )
    theme_resource.set_stylebox(
        "pressed",
        "Button",
        _make_button_style(Color(0.15, 0.13, 0.075, 1.0), Color(0.92, 0.68, 0.25, 1.0))
    )
    theme_resource.set_stylebox(
        "disabled",
        "Button",
        _make_button_style(
            Color(0.065, 0.068, 0.070, 0.86),
            Color(0.18, 0.18, 0.17, 0.90)
        )
    )
    theme_resource.set_stylebox(
        "focus",
        "Button",
        _make_focus_style()
    )

    # Progress bars.
    theme_resource.set_stylebox(
        "background",
        "ProgressBar",
        _make_progress_background()
    )
    theme_resource.set_stylebox(
        "fill",
        "ProgressBar",
        make_progress_fill(Color(0.70, 0.52, 0.20, 1.0))
    )

    return theme_resource


static func make_progress_fill(fill_color: Color) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = fill_color
    style.corner_radius_top_left = 4
    style.corner_radius_top_right = 4
    style.corner_radius_bottom_left = 4
    style.corner_radius_bottom_right = 4
    return style


static func make_modal_panel_style() -> StyleBox:
    return _make_transparent_style(0.0)


static func make_asset_button_style() -> StyleBoxFlat:
    # The Tiny Swords button art is drawn by GloamTinyUIFrame. Keep the
    # Button's own style transparent so it does not cover that atlas frame.
    var style := _make_transparent_style(0.0)
    style.content_margin_left = BUTTON_CONTENT_MARGIN_HORIZONTAL
    style.content_margin_right = BUTTON_CONTENT_MARGIN_HORIZONTAL
    style.content_margin_top = BUTTON_CONTENT_MARGIN_VERTICAL
    style.content_margin_bottom = BUTTON_CONTENT_MARGIN_VERTICAL
    return style


static func make_hud_panel_style() -> StyleBoxFlat:
    return _make_panel_style(
        Color(0.045, 0.070, 0.085, 0.88),
        Color(0.55, 0.42, 0.18, 0.92),
        6,
        8
    )


static func make_asset_panel_style() -> StyleBoxFlat:
    # GloamTinyUIFrame draws the migrated Tiny Swords nine-slice. The
    # container contributes only compact content margins.
    return _make_transparent_style(0.0)


static func make_alert_panel_style() -> StyleBox:
    return _make_panel_style(Color(0.12, 0.045, 0.04, 0.96), Color(0.86, 0.30, 0.20, 1.0), 8, 12)


static func make_toast_panel_style(tone: String) -> StyleBoxFlat:
    var background: Color = Color(0.065, 0.07, 0.075, 0.97)
    var border: Color = Color(0.50, 0.43, 0.29, 1.0)

    match tone:
        "success":
            background = Color(0.055, 0.105, 0.075, 0.97)
            border = Color(0.31, 0.65, 0.40, 1.0)

        "warning":
            background = Color(0.13, 0.085, 0.035, 0.97)
            border = Color(0.84, 0.52, 0.17, 1.0)

        "danger":
            background = Color(0.13, 0.045, 0.045, 0.97)
            border = Color(0.82, 0.24, 0.20, 1.0)

        _:
            pass

    return _make_panel_style(background, border, 9, 0)


static func _make_panel_style(
    background: Color,
    border: Color,
    radius: int,
    content_margin: int
) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = background

    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.border_color = border

    style.corner_radius_top_left = radius
    style.corner_radius_top_right = radius
    style.corner_radius_bottom_left = radius
    style.corner_radius_bottom_right = radius

    style.content_margin_left = float(content_margin)
    style.content_margin_top = float(content_margin)
    style.content_margin_right = float(content_margin)
    style.content_margin_bottom = float(content_margin)

    return style


static func _make_button_style(background: Color, border: Color) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = background

    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.border_color = border

    style.corner_radius_top_left = 7
    style.corner_radius_top_right = 7
    style.corner_radius_bottom_left = 7
    style.corner_radius_bottom_right = 7

    style.content_margin_left = 12.0
    style.content_margin_top = 8.0
    style.content_margin_right = 12.0
    style.content_margin_bottom = 8.0

    return style


static func _make_focus_style() -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color(0, 0, 0, 0)
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 2
    style.border_color = Color(0.92, 0.71, 0.30, 0.95)

    style.corner_radius_top_left = 7
    style.corner_radius_top_right = 7
    style.corner_radius_bottom_left = 7
    style.corner_radius_bottom_right = 7

    return style


static func _make_progress_background() -> StyleBox:
    # The source bar is authored as a 320 x 64 frame. Nine-slicing preserves
    # its end caps while allowing compact combat bars.
    var style: StyleBoxTexture = StyleBoxTexture.new()
    style.texture = BAR_BASE
    style.texture_margin_left = 54.0
    style.texture_margin_right = 54.0
    style.texture_margin_top = 14.0
    style.texture_margin_bottom = 14.0
    style.content_margin_left = 2.0
    style.content_margin_top = 2.0
    style.content_margin_right = 2.0
    style.content_margin_bottom = 2.0
    style.draw_center = true
    return style


static func _make_texture_style(
    texture: Texture2D,
    texture_margin: float,
    content_margin: float
) -> StyleBoxTexture:
    var style: StyleBoxTexture = StyleBoxTexture.new()
    style.texture = texture
    style.texture_margin_left = texture_margin
    style.texture_margin_top = texture_margin
    style.texture_margin_right = texture_margin
    style.texture_margin_bottom = texture_margin
    style.content_margin_left = content_margin
    style.content_margin_top = content_margin
    style.content_margin_right = content_margin
    style.content_margin_bottom = content_margin
    style.draw_center = true
    return style


static func _make_transparent_style(content_margin: float) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color.TRANSPARENT
    style.content_margin_left = content_margin
    style.content_margin_top = content_margin
    style.content_margin_right = content_margin
    style.content_margin_bottom = content_margin
    return style
