extends Node
class_name MixingManager

signal mixture_updated(current_mixture: Array[BaseIngredient], final_color: Color, final_scent: Vector3)
signal accord_just_discovered(accords: Array[BaseAccord])

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
	# Live accord detection: check after every change (only fires for new discoveries).
	if not _current_mixture.is_empty():
		var blend := get_blend_summary()
		var new_accords := AccordManager.check_blend_for_new_accords(blend)
		if not new_accords.is_empty():
			accord_just_discovered.emit(new_accords)


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
		# A single ingredient can't make a great perfume — cap at Decent range.
		var raw: float = (blend[0]["ingredient"] as BaseIngredient).intensity
		var score: float = clampf(raw * 0.5, 0.0, 5.0)
		return { "quality": score, "tier": _get_tier(score), "compatibility": raw, "balance": 1.0, "pyramid": 0.0 }

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


# ---------------------------------------------------------------------------
# Hint Generation — explains what's helping or hurting the blend quality.
# Returns 1-2 short, warm sentences for the player.
# ---------------------------------------------------------------------------

static func generate_hints(blend: Array, breakdown: Dictionary) -> String:
	if blend.is_empty():
		return ""

	var quality: float = breakdown.get("quality", 0.0)
	var tier: String = breakdown.get("tier", "Poor")
	var balance: float = breakdown.get("balance", 1.0)
	var compatibility: float = breakdown.get("compatibility", 0.0)
	var pyramid: float = breakdown.get("pyramid", 0.0)

	# --- Positive feedback for good blends ---
	if tier == "Excellent":
		return "A masterful blend — the scent families complement each other beautifully."
	if tier == "Good":
		var hints: Array[String] = []
		hints.append("A well-balanced blend with good depth.")
		if pyramid > 0.0:
			hints.append("The layered notes give it a lovely complexity.")
		return " ".join(hints)

	# --- Identify problems for weaker blends (most relevant first) ---
	var hints: Array[String] = []

	# 1. Only one unique ingredient — not really a blend.
	if blend.size() == 1:
		hints.append("A single ingredient isn't much of a blend. Try mixing in something different to add complexity.")
		return " ".join(hints)

	# 2. Too few drops.
	var total_drops := 0
	for entry in blend:
		total_drops += int(entry["amount"])
	if total_drops <= 2:
		hints.append("This blend is too thin. Add more drops to develop the scent.")
		return " ".join(hints)

	# 2. One ingredient dominates.
	if balance < 1.0:
		# Find the dominant ingredient.
		var max_weighted := 0.0
		var dominant_name := ""
		var total_weighted := 0.0
		for entry in blend:
			var ing: BaseIngredient = entry["ingredient"]
			var w: float = ing.intensity * float(entry["amount"])
			total_weighted += w
			if w > max_weighted:
				max_weighted = w
				dominant_name = ing.display_name
		if total_weighted > 0.0 and max_weighted / total_weighted > 0.5:
			hints.append("This blend is overpowered by %s. Try balancing it with other scents." % dominant_name)

	# 3. Clashing scent families (low compatibility).
	if compatibility < 5.0 and blend.size() >= 2:
		# Find the worst-pairing pair.
		var worst_score := 999.0
		var worst_a := ""
		var worst_b := ""
		for i in range(blend.size()):
			for j in range(i + 1, blend.size()):
				var ing_a: BaseIngredient = blend[i]["ingredient"]
				var ing_b: BaseIngredient = blend[j]["ingredient"]
				if ing_a.scent_family != ing_b.scent_family:
					var score := ScentCompatibility.get_compatibility(ing_a.scent_family, ing_b.scent_family)
					if score < worst_score:
						worst_score = score
						worst_a = ing_a.scent_family
						worst_b = ing_b.scent_family
		if worst_score < 0.5 and worst_a != "":
			hints.append("The %s and %s notes are clashing. Try ingredients that complement each other." % [worst_a, worst_b])
		elif hints.is_empty():
			hints.append("These scent families aren't harmonizing well. Try ingredients that complement each other.")

	# 4. Missing note layers.
	if pyramid == 0.0:
		var note_positions: Dictionary = {}
		for entry in blend:
			note_positions[(entry["ingredient"] as BaseIngredient).note_position] = true
		var missing: Array[String] = []
		if not note_positions.has("top"):
			missing.append("top")
		if not note_positions.has("middle"):
			missing.append("heart")
		if not note_positions.has("base"):
			missing.append("base")
		if not missing.is_empty():
			hints.append("This blend is missing %s notes. A complete perfume needs all three layers." % " and ".join(missing))

	# Show the most important issue only — don't stack multiple hints.
	if hints.size() > 1:
		hints.resize(1)

	return " ".join(hints)


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
## Each unique ingredient gets one layer, sorted by note position:
## base notes at the bottom, middle in the center, top notes at the top.
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
	# Sort by note position: base at bottom (drawn first), middle, then top at top.
	var note_order := { "base": 0, "middle": 1, "top": 2 }
	order.sort_custom(func(a, b):
		var a_pos: int = note_order.get(ing_map[a].note_position, 1)
		var b_pos: int = note_order.get(ing_map[b].note_position, 1)
		return a_pos < b_pos
	)
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
