extends Node
class_name MixingManager

signal mixture_updated(current_mixture: Array[BaseIngredient], final_color: Color, final_scent: Vector3)

var _current_mixture: Array[BaseIngredient] = []
var _current_accords: Array[BaseAccord] = []
# Tracks which ingredients in _current_mixture came from accords (by index ranges).
# Each entry: { "accord": BaseAccord, "start": int, "count": int }
var _accord_ranges: Array = []

func add_ingredient(ingredient: BaseIngredient) -> void:
	_current_mixture.append(ingredient)
	_emit_mixture_updated()

func remove_ingredient(ingredient: BaseIngredient) -> void:
	_current_mixture.erase(ingredient)
	_emit_mixture_updated()

## Removes the most recently added manual drop (not accord-expanded ones).
## Returns true if a drop was removed, false if nothing to undo.
func undo_last_drop() -> bool:
	# Build set of indices that belong to accord expansions.
	var accord_indices: Dictionary = {}
	for r in _accord_ranges:
		for i in range(r["start"], r["start"] + r["count"]):
			accord_indices[i] = true

	# Walk backwards to find the last manual drop.
	for i in range(_current_mixture.size() - 1, -1, -1):
		if not accord_indices.has(i):
			_current_mixture.remove_at(i)
			# Adjust accord ranges that come after the removed index.
			for r in _accord_ranges:
				if r["start"] > i:
					r["start"] -= 1
			_emit_mixture_updated()
			return true
	return false


func add_accord(accord: BaseAccord) -> void:
	_current_accords.append(accord)
	# Expand accord's recipe into component ingredients for scoring.
	var components := AccordManager.get_recipe_ingredients(accord)
	var start_index := _current_mixture.size()
	var count := 0
	for entry in components:
		var ing: BaseIngredient = entry["ingredient"]
		var amt: int = int(entry["amount"])
		for i in range(amt):
			_current_mixture.append(ing)
			count += 1
	_accord_ranges.append({ "accord": accord, "start": start_index, "count": count })
	_emit_mixture_updated()


func get_current_accords() -> Array[BaseAccord]:
	return _current_accords


func reset_beaker() -> void:
	_current_mixture.clear()
	_current_accords.clear()
	_accord_ranges.clear()
	_emit_mixture_updated()

func get_current_mixture() -> Array[BaseIngredient]:
	return _current_mixture

func _calculate_final_color() -> Color:
	if _current_mixture.is_empty():
		return Color.WHITE

	var total_color := Color.BLACK
	for ingredient in _current_mixture:
		total_color += ingredient.liquid_color

	return total_color / _current_mixture.size()

func _calculate_final_scent() -> Vector3:
	if _current_mixture.is_empty():
		return Vector3.ZERO

	var total_scent := Vector3.ZERO
	for ingredient in _current_mixture:
		total_scent += ingredient.scent_profile

	return total_scent / _current_mixture.size()

func _emit_mixture_updated() -> void:
	var final_color = _calculate_final_color()
	var final_scent = _calculate_final_scent()
	mixture_updated.emit(_current_mixture.duplicate(), final_color, final_scent)


# ---------------------------------------------------------------------------
# Blend helpers
# ---------------------------------------------------------------------------

# Consolidates duplicate ingredients in the current mixture into
# [{ "ingredient": BaseIngredient, "amount": float (drop count) }, ...]
# Accord components are included in the totals (they expand into real drops).
func get_blend_summary() -> Array:
	var counts: Dictionary = {}
	for ingredient in _current_mixture:
		if counts.has(ingredient):
			counts[ingredient] += 1.0
		else:
			counts[ingredient] = 1.0
	var blend: Array = []
	for ingredient in counts:
		blend.append({ "ingredient": ingredient, "amount": counts[ingredient] })
	return blend


## Returns only the manually-added ingredient drops (excludes accord-expanded ones).
## Used for inventory consumption on commit.
func get_manual_blend_summary() -> Array:
	# Build a set of indices that belong to accord expansions.
	var accord_indices: Dictionary = {}
	for r in _accord_ranges:
		for i in range(r["start"], r["start"] + r["count"]):
			accord_indices[i] = true

	var counts: Dictionary = {}
	for i in range(_current_mixture.size()):
		if accord_indices.has(i):
			continue
		var ingredient := _current_mixture[i]
		if counts.has(ingredient):
			counts[ingredient] += 1.0
		else:
			counts[ingredient] = 1.0
	var blend: Array = []
	for ingredient in counts:
		blend.append({ "ingredient": ingredient, "amount": counts[ingredient] })
	return blend


## Returns the list of accords used in the current blend (for display/recording).
func get_accord_summary() -> Array:
	var counts: Dictionary = {}
	var order: Array[BaseAccord] = []
	for accord in _current_accords:
		if not counts.has(accord):
			counts[accord] = 0
			order.append(accord)
		counts[accord] += 1
	var result: Array = []
	for accord in order:
		result.append({ "accord": accord, "count": counts[accord] })
	return result


# ---------------------------------------------------------------------------
# Quality Calculation
# ---------------------------------------------------------------------------

# Full breakdown for an explicit blend.
# Each entry: { "ingredient": BaseIngredient, "amount": float }
func calculate_quality_breakdown(blend: Array) -> Dictionary:
	if blend.is_empty():
		return { "quality": 0.0, "tier": "Poor", "compatibility": 0.0, "balance": 1.0, "pyramid": 0.0 }

	if blend.size() == 1:
		var score: float = clampf((blend[0]["ingredient"] as BaseIngredient).intensity, 0.0, 10.0)
		return { "quality": score, "tier": _get_tier(score), "compatibility": score, "balance": 1.0, "pyramid": 0.0 }

	# --- 1. Compatibility score ---
	var pair_count := 0
	var total_compat := 0.0
	for i in range(blend.size()):
		for j in range(i + 1, blend.size()):
			var ing_a: BaseIngredient = blend[i]["ingredient"]
			var ing_b: BaseIngredient = blend[j]["ingredient"]
			total_compat += ScentCompatibility.get_compatibility(ing_a.scent_family, ing_b.scent_family)
			pair_count += 1
	var compatibility_score: float = (total_compat / float(pair_count)) * 10.0

	# --- 2. Balance modifier ---
	var total_weighted := 0.0
	for entry in blend:
		total_weighted += (entry["ingredient"] as BaseIngredient).intensity * float(entry["amount"])

	var max_fraction := 0.0
	if total_weighted > 0.0:
		for entry in blend:
			var frac: float = ((entry["ingredient"] as BaseIngredient).intensity * float(entry["amount"])) / total_weighted
			if frac > max_fraction:
				max_fraction = frac

	var balance_modifier := 1.0
	if max_fraction > 0.5:
		balance_modifier = clamp(1.0 - (max_fraction - 0.5) * 1.4, 0.3, 1.0)

	# --- 3. Pyramid bonus ---
	var note_positions: Dictionary = {}
	for entry in blend:
		note_positions[(entry["ingredient"] as BaseIngredient).note_position] = true
	var pyramid_bonus := 0.5 if (note_positions.has("top") and note_positions.has("middle") and note_positions.has("base")) else 0.0

	# --- 4. Final score ---
	var quality: float = clampf(compatibility_score * balance_modifier + pyramid_bonus, 0.0, 10.0)

	return {
		"quality": quality,
		"tier": _get_tier(quality),
		"compatibility": compatibility_score,
		"balance": balance_modifier,
		"pyramid": pyramid_bonus,
	}


# Just the score for an explicit blend.
func calculate_quality(blend: Array) -> float:
	return calculate_quality_breakdown(blend)["quality"]


# Convenience: score for the current mixture (drops consolidated).
func calculate_current_quality() -> float:
	return calculate_quality(get_blend_summary())


# Convenience: full breakdown for the current mixture.
func get_current_breakdown() -> Dictionary:
	return calculate_quality_breakdown(get_blend_summary())


static func _get_tier(score: float) -> String:
	if score >= 7.5:
		return "Excellent"
	elif score >= 5.5:
		return "Good"
	elif score >= 3.0:
		return "Decent"
	else:
		return "Poor"


# ---------------------------------------------------------------------------
# Live Preview (real-time feedback before commit)
# ---------------------------------------------------------------------------

# Family → representative color for the beaker display.
const FAMILY_COLORS: Dictionary = {
	"floral": Color(0.92, 0.45, 0.65),   # pink
	"woody":  Color(0.55, 0.35, 0.20),   # brown
	"citrus": Color(0.95, 0.85, 0.25),   # yellow
	"sweet":  Color(0.85, 0.55, 0.75),   # soft mauve
	"green":  Color(0.40, 0.75, 0.35),   # green
	"spicy":  Color(0.80, 0.30, 0.20),   # red-orange
}

const DEFAULT_FAMILY_COLOR := Color(0.6, 0.6, 0.6)


## Returns a dictionary with all live preview data for the current mixture.
## Keys: "family_color", "description", "balance_ratio", "has_top", "has_middle", "has_base",
##       "family_weights" (normalised: dominant family = 1.0, others proportional)
func get_live_preview() -> Dictionary:
	var result := {
		"family_color": Color(0.7, 0.85, 0.95, 0.25),
		"description": "",
		"balance_ratio": 0.0,  # 0.0 = perfectly balanced, 1.0 = completely dominated
		"has_top": false,
		"has_middle": false,
		"has_base": false,
		"family_weights": {},  # normalised weights for radar display
	}

	if _current_mixture.is_empty():
		return result

	# --- Gather family weights and note presence ---
	var family_weights: Dictionary = {}  # family -> total weighted intensity
	var total_weighted := 0.0
	var notes: Dictionary = {}

	for ing in _current_mixture:
		var w := ing.intensity
		family_weights[ing.scent_family] = family_weights.get(ing.scent_family, 0.0) + w
		total_weighted += w
		notes[ing.note_position] = true

	result["has_top"] = notes.has("top")
	result["has_middle"] = notes.has("middle")
	result["has_base"] = notes.has("base")

	# --- Family-blended color ---
	var blended_color := Color(0.0, 0.0, 0.0, 0.0)
	if total_weighted > 0.0:
		for family in family_weights:
			var frac: float = family_weights[family] / total_weighted
			var col: Color = FAMILY_COLORS.get(family, DEFAULT_FAMILY_COLOR)
			blended_color.r += col.r * frac
			blended_color.g += col.g * frac
			blended_color.b += col.b * frac
		blended_color.a = 0.75
	result["family_color"] = blended_color

	# --- Balance ratio (how dominated by one family) ---
	var max_frac := 0.0
	if total_weighted > 0.0:
		for family in family_weights:
			var frac: float = family_weights[family] / total_weighted
			if frac > max_frac:
				max_frac = frac
	# Normalize: 1 family = max_frac 1.0, perfectly even among N families → 1/N.
	# Map so that <= 0.5 → 0.0 (balanced), 1.0 → 1.0 (overpowering).
	result["balance_ratio"] = clampf((max_frac - 0.5) / 0.5, 0.0, 1.0) if max_frac > 0.5 else 0.0

	# --- Description ---
	result["description"] = _generate_description(family_weights, total_weighted, notes)

	# --- Normalised family weights for radar display ---
	# Dominant family → 1.0; others are proportional to it.
	var max_w := 0.0
	for f in family_weights:
		if family_weights[f] > max_w:
			max_w = family_weights[f]
	var normalised: Dictionary = {}
	if max_w > 0.0:
		for f in family_weights:
			normalised[f] = family_weights[f] / max_w
	result["family_weights"] = normalised

	# --- Per-ingredient layers for the beaker display ---
	result["ingredient_layers"] = _build_ingredient_layers()

	return result


## Returns an array of { "color": Color, "fraction": float } for beaker layer display.
## Each unique ingredient gets one layer, ordered by first appearance.
func _build_ingredient_layers() -> Array:
	if _current_mixture.is_empty():
		return []
	var total_drops := _current_mixture.size()
	var counts: Dictionary = {}
	var order: Array[String] = []
	var ing_map: Dictionary = {}  # name -> BaseIngredient
	for ing in _current_mixture:
		var name := ing.display_name
		if not counts.has(name):
			counts[name] = 0
			order.append(name)
			ing_map[name] = ing
		counts[name] += 1
	var result: Array = []
	for name in order:
		result.append({
			"color": BeakerDisplay.color_for_ingredient(name),
			"fraction": float(counts[name]) / float(total_drops),
		})
	return result


func _generate_description(family_weights: Dictionary, total_weighted: float, notes: Dictionary) -> String:
	if total_weighted <= 0.0:
		return ""

	# Sort families by weight descending.
	var families: Array = []
	for family in family_weights:
		families.append({ "name": family, "weight": family_weights[family] })
	families.sort_custom(func(a, b): return a["weight"] > b["weight"])

	# Descriptive adjectives per family.
	var adjectives: Dictionary = {
		"floral": "floral",
		"woody": "warm woody",
		"citrus": "bright citrus",
		"sweet": "sweet",
		"green": "fresh green",
		"spicy": "bold spicy",
	}

	# Note position descriptors.
	var note_words: Dictionary = {
		"top": "opening",
		"middle": "heart",
		"base": "base",
	}

	var primary: Dictionary = families[0]
	var primary_adj: String = adjectives.get(primary["name"], primary["name"])
	var primary_frac: float = primary["weight"] / total_weighted

	# Single ingredient / single family.
	if families.size() == 1:
		return "A purely %s blend." % primary_adj

	var secondary: Dictionary = families[1]
	var secondary_adj: String = adjectives.get(secondary["name"], secondary["name"])

	# Build note position context.
	var note_parts: Array[String] = []
	if notes.has("top"):
		note_parts.append("a lively opening")
	if notes.has("middle"):
		note_parts.append("depth at its heart")
	if notes.has("base"):
		note_parts.append("a lasting base")

	# Dominant vs balanced phrasing.
	var desc := ""
	if primary_frac > 0.65:
		desc = "A %s blend with hints of %s." % [primary_adj, secondary_adj]
	elif primary_frac > 0.45:
		desc = "A %s blend balanced by %s notes." % [primary_adj, secondary_adj]
	else:
		desc = "An even mix of %s and %s tones." % [primary_adj, secondary_adj]

	if note_parts.size() >= 2:
		desc += " It has %s." % " and ".join(note_parts)

	return desc
