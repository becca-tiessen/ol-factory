extends Control
class_name ScentRadarGraph

# Clockwise from top: a balanced pairing of complementary families.
const FAMILIES: Array[String] = ["floral", "citrus", "spicy", "sweet", "woody", "green"]

# Mirrors MixingManager.FAMILY_COLORS.
const FAMILY_COLORS: Dictionary = {
	"floral": Color(0.92, 0.45, 0.65),
	"citrus": Color(0.95, 0.85, 0.25),
	"spicy":  Color(0.80, 0.30, 0.20),
	"sweet":  Color(0.85, 0.55, 0.75),
	"woody":  Color(0.55, 0.35, 0.20),
	"green":  Color(0.40, 0.75, 0.35),
}

const GRID_COLOR   := Color(0.55, 0.45, 0.28, 0.30)
const FILL_COLOR   := Color(0.90, 0.70, 0.35, 0.25)
const STROKE_COLOR := Color(0.90, 0.70, 0.35, 0.85)
const AXIS_COLOR   := Color(0.55, 0.45, 0.28, 0.45)

const GRID_RINGS     := 3
const LABEL_GAP      := 14.0   # px from outer ring to label centre
const LABEL_MARGIN   := 22.0   # total px reserved outside outer ring for labels
const LABEL_FONT_SIZE := 11

# Normalised family weights: family → 0.0 … 1.0  (1.0 = dominant family).
var family_weights: Dictionary = {}


func set_weights(weights: Dictionary) -> void:
	family_weights = weights
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var n := FAMILIES.size()
	var font := ThemeDB.fallback_font

	# Leave room around the edge for labels.
	var outer_radius := minf(center.x, center.y) - LABEL_MARGIN - 10.0
	if outer_radius <= 4.0:
		return

	# Axis angles: start at top (−π/2), step clockwise by τ/n.
	var angles: Array[float] = []
	for i in range(n):
		angles.append(-PI * 0.5 + TAU * float(i) / float(n))

	# --- Concentric reference rings ---
	for ring in range(1, GRID_RINGS + 1):
		var r := outer_radius * float(ring) / float(GRID_RINGS)
		var ring_pts := PackedVector2Array()
		for angle in angles:
			ring_pts.append(center + Vector2(cos(angle), sin(angle)) * r)
		ring_pts.append(ring_pts[0])
		draw_polyline(ring_pts, GRID_COLOR, 1.0, true)

	# --- Axis spokes ---
	for i in range(n):
		var tip := center + Vector2(cos(angles[i]), sin(angles[i])) * outer_radius
		draw_line(center, tip, AXIS_COLOR, 1.0, true)

	# --- Data polygon ---
	if not family_weights.is_empty():
		var data_pts := PackedVector2Array()
		var any_nonzero := false
		for i in range(n):
			var w: float = family_weights.get(FAMILIES[i], 0.0)
			if w > 0.001:
				any_nonzero = true
			data_pts.append(center + Vector2(cos(angles[i]), sin(angles[i])) * outer_radius * w)

		if any_nonzero:
			# Filled shape.
			draw_colored_polygon(data_pts, FILL_COLOR)
			# Border stroke.
			var border := PackedVector2Array(data_pts)
			border.append(data_pts[0])
			draw_polyline(border, STROKE_COLOR, 2.0, true)
			# Vertex dots for non-zero axes.
			for i in range(n):
				var w: float = family_weights.get(FAMILIES[i], 0.0)
				if w > 0.001:
					draw_circle(data_pts[i], 3.5, STROKE_COLOR)

	# --- Axis labels ---
	var ascent := font.get_ascent(LABEL_FONT_SIZE)
	for i in range(n):
		var family := FAMILIES[i]
		var angle  := angles[i]
		var col    : Color = FAMILY_COLORS.get(family, Color.WHITE)
		var label  := family.capitalize()
		var text_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE).x
		# Centre the label on the axis tip beyond the outer ring.
		var tip     := center + Vector2(cos(angle), sin(angle)) * (outer_radius + LABEL_GAP)
		var draw_pos := Vector2(tip.x - text_w * 0.5, tip.y + ascent * 0.5)
		draw_string(font, draw_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, col)
