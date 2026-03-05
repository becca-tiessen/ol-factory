class_name BeakerDisplay
extends Control

## Beaker drawn with _draw(). Supports stacked color layers (one per ingredient)
## or a single liquid_color fallback.

## Fallback single color (used by celebration card icon, etc.).
var liquid_color := Color(0.7, 0.85, 0.95, 0.25):
	set(value):
		liquid_color = value
		queue_redraw()

## 0.0 = empty, 1.0 = full (visually caps at ~80% of beaker height).
var fill_ratio := 0.0:
	set(value):
		fill_ratio = clampf(value, 0.0, 1.0)
		queue_redraw()

## Per-ingredient color layers. Each entry: { "color": Color, "fraction": float }
## Fractions should sum to 1.0. Layers draw bottom-to-top in array order.
## When non-empty, this overrides liquid_color for the fill.
var layers: Array = []:
	set(value):
		layers = value
		queue_redraw()

const GLASS_COLOR := Color(0.18, 0.26, 0.40, 0.90)
const GLASS_WIDTH := 3.0
const HIGHLIGHT_COLOR := Color(1.0, 1.0, 1.0, 0.22)
const MAX_FILL := 0.80

## Assigned ingredient colors — distinct, readable bands.
const INGREDIENT_COLORS: Dictionary = {
	"Rose": Color("E8A0BF"),
	"Jasmine": Color("F2DC5D"),
	"Cedar": Color("A0522D"),
	"Sandalwood": Color("D2A679"),
	"Vanilla": Color("F5E6CA"),
	"Bergamot": Color("F0C05A"),
	"Peppermint": Color("7EC8A0"),
}
const DEFAULT_INGREDIENT_COLOR := Color(0.6, 0.6, 0.6)


static func color_for_ingredient(ingredient_name: String) -> Color:
	return INGREDIENT_COLORS.get(ingredient_name, DEFAULT_INGREDIENT_COLOR)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var pad := 8.0
	if w < pad * 3 or h < pad * 3:
		return

	var cx := w * 0.5
	var top_y := pad
	var bot_y := h - pad
	var body_h := bot_y - top_y

	var rim_half := w * 0.28
	var body_half := w * 0.26
	var neck_y := top_y + body_h * 0.08
	var round_start_y := bot_y - body_h * 0.18

	# Build outline as a closed shape.
	var outline := PackedVector2Array()
	outline.append(Vector2(cx - rim_half, top_y))
	outline.append(Vector2(cx - rim_half, neck_y))
	outline.append(Vector2(cx - body_half, neck_y + body_h * 0.05))
	outline.append(Vector2(cx - body_half, round_start_y))

	var arc_steps := 12
	for i in range(1, arc_steps):
		var t := float(i) / float(arc_steps)
		var angle := PI + t * PI
		var rx := body_half
		var ry := bot_y - round_start_y
		outline.append(Vector2(cx + cos(angle) * rx, round_start_y - sin(angle) * ry))

	outline.append(Vector2(cx + body_half, round_start_y))
	outline.append(Vector2(cx + body_half, neck_y + body_h * 0.05))
	outline.append(Vector2(cx + rim_half, neck_y))
	outline.append(Vector2(cx + rim_half, top_y))

	# ── Liquid fill ──
	if fill_ratio > 0.0:
		var fill_top_y := bot_y - (bot_y - neck_y) * fill_ratio * MAX_FILL
		if layers.size() > 0:
			_draw_layered_liquid(outline, fill_top_y, bot_y, cx)
		else:
			_draw_liquid(outline, fill_top_y, cx, liquid_color)

	# ── Drop shadow ──
	var shadow_col := Color(0.0, 0.0, 0.0, 0.18)
	var shadow_off := Vector2(1.5, 2.5)
	for i in range(outline.size() - 1):
		draw_line(outline[i] + shadow_off, outline[i + 1] + shadow_off, shadow_col, GLASS_WIDTH + 1.0, true)
	draw_line(outline[-1] + shadow_off, outline[0] + shadow_off, shadow_col, GLASS_WIDTH + 1.0, true)

	# ── Glass outline ──
	for i in range(outline.size() - 1):
		draw_line(outline[i], outline[i + 1], GLASS_COLOR, GLASS_WIDTH, true)
	draw_line(outline[-1], outline[0], GLASS_COLOR, GLASS_WIDTH, true)

	# ── Glass highlight ──
	var hx := cx - body_half + 5.0
	draw_line(Vector2(hx, neck_y + 10), Vector2(hx, round_start_y - 8), HIGHLIGHT_COLOR, 2.0, true)
	draw_line(Vector2(hx + 3, neck_y + 16), Vector2(hx + 3, round_start_y - 16), Color(1, 1, 1, 0.1), 1.0, true)


func _draw_layered_liquid(outline: PackedVector2Array, fill_top_y: float, bot_y: float, cx: float) -> void:
	# Draw layers bottom-to-top. Each layer is a horizontal band clipped to the beaker outline.
	var total_liquid_height := bot_y - fill_top_y
	var current_bottom := bot_y

	for i in range(layers.size()):
		var layer: Dictionary = layers[i]
		var frac: float = layer["fraction"]
		var col: Color = layer["color"]
		var layer_height := total_liquid_height * frac
		var layer_top := current_bottom - layer_height

		_draw_liquid(outline, layer_top, cx, col, current_bottom)

		# Draw a subtle separator line between layers (skip for bottom layer).
		if i > 0:
			var sep_y := current_bottom
			var left_x := cx
			var right_x := cx
			# Find the beaker width at this y by checking outline edges.
			for pi in range(outline.size()):
				var curr := outline[pi]
				var next := outline[(pi + 1) % outline.size()]
				if (curr.y <= sep_y and next.y >= sep_y) or (curr.y >= sep_y and next.y <= sep_y):
					if absf(next.y - curr.y) > 0.01:
						var t := (sep_y - curr.y) / (next.y - curr.y)
						var x := lerpf(curr.x, next.x, t)
						left_x = minf(left_x, x)
						right_x = maxf(right_x, x)
			if right_x - left_x > 4.0:
				draw_line(Vector2(left_x + 1, sep_y), Vector2(right_x - 1, sep_y), Color(1, 1, 1, 0.15), 1.0, true)

		current_bottom = layer_top

	# Surface line on top of the topmost layer.
	var left_x := cx
	var right_x := cx
	for pi in range(outline.size()):
		var curr := outline[pi]
		var next := outline[(pi + 1) % outline.size()]
		if (curr.y <= fill_top_y and next.y >= fill_top_y) or (curr.y >= fill_top_y and next.y <= fill_top_y):
			if absf(next.y - curr.y) > 0.01:
				var t := (fill_top_y - curr.y) / (next.y - curr.y)
				var x := lerpf(curr.x, next.x, t)
				left_x = minf(left_x, x)
				right_x = maxf(right_x, x)
	if right_x - left_x > 4.0:
		draw_line(Vector2(left_x + 2, fill_top_y), Vector2(right_x - 2, fill_top_y), Color(1, 1, 1, 0.12), 1.0, true)


## Draw a single liquid band clipped to the beaker outline between clip_top_y and clip_bottom_y.
func _draw_liquid(outline: PackedVector2Array, clip_top_y: float, cx: float, color: Color, clip_bottom_y: float = INF) -> void:
	# Sutherland-Hodgman: clip outline against top boundary (keep y >= clip_top_y),
	# then clip result against bottom boundary (keep y <= clip_bottom_y).
	var poly := Array(outline)
	poly = _clip_polygon_half_plane(poly, clip_top_y, true)   # keep y >= top
	if clip_bottom_y < INF:
		poly = _clip_polygon_half_plane(poly, clip_bottom_y, false)  # keep y <= bottom

	if poly.size() >= 3:
		var col := color
		col.a = clampf(col.a, 0.35, 0.8)
		var packed := PackedVector2Array()
		for p in poly:
			packed.append(p)
		draw_colored_polygon(packed, col)


## Sutherland-Hodgman clip against a horizontal line.
## If keep_below is true, keeps points with y >= boundary (clips above).
## If keep_below is false, keeps points with y <= boundary (clips below).
func _clip_polygon_half_plane(poly: Array, boundary: float, keep_below: bool) -> Array:
	if poly.is_empty():
		return []
	var output: Array = []
	for i in range(poly.size()):
		var curr: Vector2 = poly[i]
		var next: Vector2 = poly[(i + 1) % poly.size()]
		var curr_in := (curr.y >= boundary) if keep_below else (curr.y <= boundary)
		var next_in := (next.y >= boundary) if keep_below else (next.y <= boundary)

		if curr_in:
			output.append(curr)
			if not next_in and absf(next.y - curr.y) > 0.001:
				var t := (boundary - curr.y) / (next.y - curr.y)
				output.append(Vector2(lerpf(curr.x, next.x, t), boundary))
		elif next_in and absf(next.y - curr.y) > 0.001:
			var t := (boundary - curr.y) / (next.y - curr.y)
			output.append(Vector2(lerpf(curr.x, next.x, t), boundary))
	return output
