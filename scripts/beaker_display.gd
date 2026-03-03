class_name BeakerDisplay
extends Control

## Simple beaker drawn with _draw(). Set liquid_color and fill_ratio to update.

var liquid_color := Color(0.7, 0.85, 0.95, 0.25):
	set(value):
		liquid_color = value
		queue_redraw()

## 0.0 = empty, 1.0 = full (visually caps at ~80% of beaker height).
var fill_ratio := 0.0:
	set(value):
		fill_ratio = clampf(value, 0.0, 1.0)
		queue_redraw()

const GLASS_COLOR := Color(0.75, 0.82, 0.88, 0.55)
const GLASS_WIDTH := 2.0
const HIGHLIGHT_COLOR := Color(1.0, 1.0, 1.0, 0.22)
const MAX_FILL := 0.80


func _draw() -> void:
	var w := size.x
	var h := size.y
	var pad := 8.0
	if w < pad * 3 or h < pad * 3:
		return

	var cx := w * 0.5
	# Beaker dimensions within padding.
	var top_y := pad
	var bot_y := h - pad
	var body_h := bot_y - top_y

	# Widths: rim is wider, body tapers slightly, bottom is rounded.
	var rim_half := w * 0.28
	var body_half := w * 0.26
	var neck_y := top_y + body_h * 0.08  # small lip/rim zone
	var round_start_y := bot_y - body_h * 0.18  # where bottom rounding begins

	# Build outline as a closed shape (top-left, down left side, across bottom, up right side, top-right).
	var outline := PackedVector2Array()

	# Rim top-left.
	outline.append(Vector2(cx - rim_half, top_y))
	# Rim to body transition (slight taper inward).
	outline.append(Vector2(cx - rim_half, neck_y))
	# Left wall going down.
	outline.append(Vector2(cx - body_half, neck_y + body_h * 0.05))
	outline.append(Vector2(cx - body_half, round_start_y))

	# Rounded bottom — simple arc from left to right.
	var arc_steps := 12
	for i in range(1, arc_steps):
		var t := float(i) / float(arc_steps)
		var angle := PI + t * PI  # PI to 2*PI, sweeping left-to-right underneath
		var rx := body_half  # horizontal radius
		var ry := bot_y - round_start_y  # vertical radius (depth of the curve)
		outline.append(Vector2(cx + cos(angle) * rx, round_start_y - sin(angle) * ry))

	# Right wall going up.
	outline.append(Vector2(cx + body_half, round_start_y))
	outline.append(Vector2(cx + body_half, neck_y + body_h * 0.05))
	# Rim right.
	outline.append(Vector2(cx + rim_half, neck_y))
	outline.append(Vector2(cx + rim_half, top_y))

	# ── Liquid fill ──
	if fill_ratio > 0.0:
		var fill_top_y := bot_y - (bot_y - neck_y) * fill_ratio * MAX_FILL
		_draw_liquid(outline, fill_top_y, cx)

	# ── Glass outline ──
	for i in range(outline.size() - 1):
		draw_line(outline[i], outline[i + 1], GLASS_COLOR, GLASS_WIDTH, true)
	# Close the top rim.
	draw_line(outline[-1], outline[0], GLASS_COLOR, GLASS_WIDTH, true)

	# ── Glass highlight ──
	var hx := cx - body_half + 5.0
	draw_line(Vector2(hx, neck_y + 10), Vector2(hx, round_start_y - 8), HIGHLIGHT_COLOR, 2.0, true)
	draw_line(Vector2(hx + 3, neck_y + 16), Vector2(hx + 3, round_start_y - 16), Color(1, 1, 1, 0.1), 1.0, true)


func _draw_liquid(outline: PackedVector2Array, liquid_top_y: float, cx: float) -> void:
	var liquid_poly := PackedVector2Array()

	for i in range(outline.size()):
		var curr := outline[i]
		var next := outline[(i + 1) % outline.size()]
		var curr_below := curr.y >= liquid_top_y
		var next_below := next.y >= liquid_top_y

		if curr_below:
			liquid_poly.append(curr)

		if curr_below != next_below and absf(next.y - curr.y) > 0.01:
			var t := (liquid_top_y - curr.y) / (next.y - curr.y)
			liquid_poly.append(Vector2(lerpf(curr.x, next.x, t), liquid_top_y))

	if liquid_poly.size() >= 3:
		var col := liquid_color
		col.a = clampf(col.a, 0.35, 0.8)
		draw_colored_polygon(liquid_poly, col)

		# Surface line.
		var left_x := cx
		var right_x := cx
		for pt in liquid_poly:
			if absf(pt.y - liquid_top_y) < 1.5:
				left_x = minf(left_x, pt.x)
				right_x = maxf(right_x, pt.x)
		if right_x - left_x > 4.0:
			draw_line(Vector2(left_x + 2, liquid_top_y), Vector2(right_x - 2, liquid_top_y), Color(1, 1, 1, 0.12), 1.0, true)
