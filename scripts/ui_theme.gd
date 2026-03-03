class_name UITheme

## Static helper providing the cozy French workshop visual theme.
## All UI panels share this palette via BaseInteractableUI._apply_workshop_theme().

# ─── Palette ───────────────────────────────────────────────────────────────────

const PARCHMENT      := Color(0.96, 0.93, 0.87)
const PARCHMENT_DARK := Color(0.92, 0.88, 0.80)
const CARD_BG        := Color(0.93, 0.89, 0.82)
const BORDER         := Color(0.62, 0.47, 0.30)
const BORDER_LIGHT   := Color(0.75, 0.65, 0.50)
const SHELF_BG       := Color(0.55, 0.42, 0.28, 0.30)

# Text hierarchy
const TEXT_DARK      := Color(0.28, 0.22, 0.16)
const TEXT_MUTED     := Color(0.58, 0.52, 0.42)
const HEADER_BROWN   := Color(0.50, 0.32, 0.18)

# Semantic accent colors (dark enough to read against parchment)
const GOLD           := Color(0.65, 0.50, 0.12)
const SOFT_BLUE      := Color(0.28, 0.40, 0.58)
const SOFT_GREEN     := Color(0.22, 0.48, 0.20)
const SOFT_RED       := Color(0.62, 0.30, 0.18)
const WARM_AMBER     := Color(0.60, 0.42, 0.15)

# Note indicators
const NOTE_DIM       := Color(0.70, 0.64, 0.54)
const NOTE_LIT       := Color(0.32, 0.50, 0.25)

# Button backgrounds
const BTN_NORMAL_BG  := Color(0.82, 0.75, 0.62)
const BTN_HOVER_BG   := Color(0.87, 0.80, 0.67)
const BTN_PRESSED_BG := Color(0.75, 0.68, 0.56)
const BTN_DISABLED_BG := Color(0.85, 0.82, 0.77)
const BTN_DISABLED_FC := Color(0.62, 0.58, 0.52)

const BTN_COMMIT_BG  := Color(0.30, 0.48, 0.28)
const BTN_COMMIT_HV  := Color(0.36, 0.55, 0.33)
const BTN_CLEAR_BG   := Color(0.58, 0.28, 0.24)
const BTN_CLEAR_HV   := Color(0.65, 0.34, 0.28)

# Scent-family pip colors
const FAMILY_COLORS  := {
	"floral": Color(0.85, 0.45, 0.55),
	"green":  Color(0.38, 0.65, 0.35),
	"woody":  Color(0.70, 0.50, 0.26),
	"citrus": Color(0.88, 0.78, 0.28),
	"sweet":  Color(0.85, 0.72, 0.48),
	"spicy":  Color(0.72, 0.40, 0.28),
}


# ─── Theme factory ─────────────────────────────────────────────────────────────

static func create_workshop_theme() -> Theme:
	var theme := Theme.new()

	# Label defaults
	theme.set_color("font_color", "Label", TEXT_DARK)

	# Button
	theme.set_color("font_color", "Button", TEXT_DARK)
	theme.set_color("font_hover_color", "Button", TEXT_DARK)
	theme.set_color("font_pressed_color", "Button", TEXT_DARK)
	theme.set_color("font_disabled_color", "Button", BTN_DISABLED_FC)
	theme.set_stylebox("normal",   "Button", _make_btn_box(BTN_NORMAL_BG, BORDER_LIGHT, Vector2(0, 2)))
	theme.set_stylebox("hover",    "Button", _make_btn_box(BTN_HOVER_BG, BORDER, Vector2(0, 2)))
	theme.set_stylebox("pressed",  "Button", _make_btn_box(BTN_PRESSED_BG, BORDER, Vector2.ZERO))
	theme.set_stylebox("disabled", "Button", _make_btn_box(BTN_DISABLED_BG, Color(0.78, 0.74, 0.68), Vector2.ZERO))

	# PanelContainer (cards)
	var card := StyleBoxFlat.new()
	card.bg_color = CARD_BG
	_set_corners(card, 6)
	_set_border(card, 1, BORDER_LIGHT)
	card.content_margin_left = 8
	card.content_margin_right = 8
	card.content_margin_top = 6
	card.content_margin_bottom = 6
	theme.set_stylebox("panel", "PanelContainer", card)

	# HSeparator
	var hsep := StyleBoxLine.new()
	hsep.color = BORDER_LIGHT
	hsep.thickness = 1
	hsep.grow_begin = 6
	hsep.grow_end = 6
	theme.set_stylebox("separator", "HSeparator", hsep)

	# VSeparator
	var vsep := StyleBoxLine.new()
	vsep.color = BORDER_LIGHT
	vsep.thickness = 1
	vsep.vertical = true
	vsep.grow_begin = 6
	vsep.grow_end = 6
	theme.set_stylebox("separator", "VSeparator", vsep)

	# ProgressBar
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.72, 0.67, 0.58)
	_set_corners(pb_bg, 4)
	theme.set_stylebox("background", "ProgressBar", pb_bg)

	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = GOLD
	_set_corners(pb_fill, 4)
	theme.set_stylebox("fill", "ProgressBar", pb_fill)
	theme.set_color("font_color", "ProgressBar", TEXT_DARK)

	# ScrollContainer — transparent
	theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())

	return theme


# ─── Panel background ──────────────────────────────────────────────────────────

static func make_panel_bg() -> StyleBoxFlat:
	var bg := StyleBoxFlat.new()
	bg.bg_color = PARCHMENT
	_set_corners(bg, 12)
	_set_border(bg, 3, BORDER)
	bg.shadow_color = Color(0, 0, 0, 0.22)
	bg.shadow_size = 8
	bg.shadow_offset = Vector2(2, 4)
	return bg


# ─── Shelf background (behind the beaker) ──────────────────────────────────────

static func make_shelf_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = SHELF_BG
	_set_corners(sb, 8)
	_set_border(sb, 1, Color(0.48, 0.36, 0.24, 0.45))
	sb.border_width_bottom = 2
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


# ─── Ingredient tag background ─────────────────────────────────────────────────

static func make_ingredient_tag_bg(enabled: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PARCHMENT_DARK if enabled else Color(0.90, 0.88, 0.84)
	_set_corners(sb, 5)
	_set_border(sb, 1, BORDER_LIGHT if enabled else Color(0.80, 0.77, 0.72))
	sb.content_margin_left = 6
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


# ─── Button styling helpers ────────────────────────────────────────────────────

static func style_commit_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal",  _make_btn_box(BTN_COMMIT_BG, Color(0.22, 0.38, 0.20), Vector2(0, 3)))
	btn.add_theme_stylebox_override("hover",   _make_btn_box(BTN_COMMIT_HV, Color(0.28, 0.44, 0.25), Vector2(0, 3)))
	btn.add_theme_stylebox_override("pressed", _make_btn_box(Color(0.26, 0.42, 0.24), Color(0.22, 0.38, 0.20), Vector2.ZERO))
	btn.add_theme_stylebox_override("disabled", _make_btn_box(BTN_DISABLED_BG, Color(0.78, 0.74, 0.68), Vector2.ZERO))
	btn.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.90))
	btn.add_theme_color_override("font_pressed_color", Color(0.90, 0.87, 0.80))
	btn.add_theme_color_override("font_disabled_color", BTN_DISABLED_FC)


static func style_clear_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal",  _make_btn_box(BTN_CLEAR_BG, Color(0.45, 0.22, 0.18), Vector2(0, 3)))
	btn.add_theme_stylebox_override("hover",   _make_btn_box(BTN_CLEAR_HV, Color(0.52, 0.28, 0.22), Vector2(0, 3)))
	btn.add_theme_stylebox_override("pressed", _make_btn_box(Color(0.52, 0.24, 0.20), Color(0.45, 0.22, 0.18), Vector2.ZERO))
	btn.add_theme_stylebox_override("disabled", _make_btn_box(BTN_DISABLED_BG, Color(0.78, 0.74, 0.68), Vector2.ZERO))
	btn.add_theme_color_override("font_color", Color(0.95, 0.90, 0.88))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.92))
	btn.add_theme_color_override("font_pressed_color", Color(0.90, 0.86, 0.84))
	btn.add_theme_color_override("font_disabled_color", BTN_DISABLED_FC)


static func style_header(label: Label) -> void:
	label.add_theme_color_override("font_color", HEADER_BROWN)
	label.add_theme_font_size_override("font_size", 20)


static func style_section_title(label: Label) -> void:
	label.add_theme_color_override("font_color", HEADER_BROWN)
	label.add_theme_font_size_override("font_size", 16)


static func get_family_color(family: String) -> Color:
	return FAMILY_COLORS.get(family, Color(0.60, 0.55, 0.48))


# ─── Private helpers ───────────────────────────────────────────────────────────

static func _make_btn_box(bg: Color, border: Color, shadow: Vector2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	_set_corners(sb, 6)
	_set_border(sb, 1, border)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	if shadow != Vector2.ZERO:
		sb.shadow_color = Color(0, 0, 0, 0.15)
		sb.shadow_size = 2
		sb.shadow_offset = shadow
	return sb


static func _set_corners(sb: StyleBoxFlat, r: int) -> void:
	sb.corner_radius_top_left = r
	sb.corner_radius_top_right = r
	sb.corner_radius_bottom_left = r
	sb.corner_radius_bottom_right = r


static func _set_border(sb: StyleBoxFlat, w: int, color: Color) -> void:
	sb.border_width_left = w
	sb.border_width_right = w
	sb.border_width_top = w
	sb.border_width_bottom = w
	sb.border_color = color
