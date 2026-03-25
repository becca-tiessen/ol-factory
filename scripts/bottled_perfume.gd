extends Resource
class_name BottledPerfume

## A committed perfume blend stored as a bottle.
## Created at the mixing bench on commit. Aged on the cellar rack.

## Each entry: { "path": String, "name": String, "amount": int, "family": String, "note": String }
var blend_summary: Array = []
var base_quality: float = 0.0
var tier: String = "Poor"
var breakdown: Dictionary = {}
var total_drops: int = 0
var age_bonus: float = 0.0
var aged: bool = false
var has_accord: bool = false
## Custom name given by the player when displaying on the shelf.
var display_name: String = ""
## Generated description text — created once at bottling time, persists with the bottle.
var description: String = ""


static func create_from_blend(blend: Array, bd: Dictionary, accords_used: Array = []) -> BottledPerfume:
	var bottle := BottledPerfume.new()
	var drops := 0
	for entry in blend:
		var ing: BaseIngredient = entry["ingredient"]
		var amt := int(entry["amount"])
		drops += amt
		bottle.blend_summary.append({
			"path": ing.resource_path,
			"name": ing.display_name,
			"amount": amt,
			"family": ing.scent_family,
			"note": ing.note_position,
		})
	bottle.base_quality = bd["quality"]
	bottle.tier = bd["tier"]
	bottle.breakdown = bd.duplicate()
	bottle.total_drops = drops
	bottle.has_accord = not accords_used.is_empty()
	bottle.description = _generate_description(bottle.blend_summary, bd)
	return bottle


func get_final_quality() -> float:
	return minf(base_quality + age_bonus, 10.0)


func get_final_tier() -> String:
	return MixingManager._get_tier(get_final_quality())


func get_label() -> String:
	var names: Array[String] = []
	for entry in blend_summary:
		names.append("%s x%d" % [entry["name"], entry["amount"]])
	return ", ".join(names)


## Check this bottle against a request's requirements.
func matches_request(request: BaseRequest) -> bool:
	# Min drops
	if request.min_drops > 0 and total_drops < request.min_drops:
		return false

	# Min distinct ingredients (counts unique ingredient paths)
	if request.min_distinct_ingredients > 0:
		if blend_summary.size() < request.min_distinct_ingredients:
			return false

	# Required families — value is the minimum number of DISTINCT ingredients
	# from that family (not drop count). E.g. { "floral": 2 } means 2 different
	# floral oils, not just 2 drops of one.
	if not request.required_families.is_empty():
		var family_distinct: Dictionary = {}
		for entry in blend_summary:
			var fam: String = entry["family"]
			family_distinct[fam] = family_distinct.get(fam, 0) + 1
		for family: String in request.required_families:
			if family_distinct.get(family, 0) < int(request.required_families[family]):
				return false

	# Required notes — value is the minimum number of DISTINCT ingredients
	# with that note position. E.g. { "base": 2 } means 2 different base-note
	# oils present in the blend.
	if not request.required_notes.is_empty():
		var note_distinct: Dictionary = {}
		for entry in blend_summary:
			var n: String = entry["note"]
			note_distinct[n] = note_distinct.get(n, 0) + 1
		for note: String in request.required_notes:
			if note_distinct.get(note, 0) < int(request.required_notes[note]):
				return false

	# Min quality (uses aged quality)
	if request.min_quality > 0.0:
		if get_final_quality() < request.min_quality:
			return false

	# Requires a discovered accord
	if request.requires_accord and not has_accord:
		return false

	# Requires aging
	if request.requires_aged and not aged:
		return false

	return true


## Serialize to a dictionary for saving.
func to_dict() -> Dictionary:
	var d := {
		"blend_summary": blend_summary.duplicate(true),
		"base_quality": base_quality,
		"tier": tier,
		"breakdown": breakdown.duplicate(),
		"total_drops": total_drops,
		"age_bonus": age_bonus,
		"aged": aged,
		"has_accord": has_accord,
	}
	if display_name != "":
		d["display_name"] = display_name
	if description != "":
		d["description"] = description
	return d


## Reconstruct from a saved dictionary.
static func from_dict(data: Dictionary) -> BottledPerfume:
	var bottle := BottledPerfume.new()
	bottle.blend_summary = data.get("blend_summary", [])
	bottle.base_quality = float(data.get("base_quality", 0.0))
	bottle.tier = data.get("tier", "Poor")
	bottle.breakdown = data.get("breakdown", {})
	bottle.total_drops = int(data.get("total_drops", 0))
	bottle.age_bonus = float(data.get("age_bonus", 0.0))
	bottle.aged = bool(data.get("aged", false))
	bottle.has_accord = bool(data.get("has_accord", false))
	bottle.display_name = data.get("display_name", "")
	bottle.description = data.get("description", "")
	return bottle


# ---------------------------------------------------------------------------
# Description Generator — builds an evocative 2-3 sentence description
# from blend composition and quality at bottling time.
# ---------------------------------------------------------------------------

const _OPENING_LINES: Dictionary = {
	"floral": ["A delicate floral fragrance", "A lush bouquet of blossoms", "A soft, petal-sweet scent"],
	"woody": ["A warm, grounded fragrance", "A deep scent of aged wood", "An earthy, rich aroma"],
	"citrus": ["A bright, zesty fragrance", "A crisp burst of citrus", "A sharp, sun-kissed scent"],
	"sweet": ["A rich, indulgent fragrance", "A warm and honeyed scent", "A comforting, velvety aroma"],
	"green": ["A fresh, verdant fragrance", "A cool, leafy scent", "A crisp breath of green"],
	"spicy": ["A bold, smoldering fragrance", "A dusky, ember-touched scent"],
	"smoky": ["A bold, smoldering fragrance", "A dusky, ember-touched scent"],
	"earthy": ["A grounded, mineral fragrance", "A deep, rain-washed scent"],
	"fresh": ["A clean, airy fragrance", "A light, ocean-touched scent"],
}

const _SECONDARY_MODIFIERS: Dictionary = {
	"floral": "softened by a floral heart",
	"woody": "with a woody undertone",
	"citrus": "brightened by citrus notes",
	"sweet": "grounded in sweet warmth",
	"green": "lifted by green freshness",
	"spicy": "with a hint of spice",
	"smoky": "with a hint of smoke",
	"earthy": "with an earthy depth",
	"fresh": "with a breath of freshness",
}

const _SOLO_MODIFIERS: Array = ["pure and unblended", "simple and bold", "singular in character"]


static func _generate_description(summary: Array, bd: Dictionary) -> String:
	if summary.is_empty():
		return ""

	var quality: float = bd.get("quality", 0.0)
	var tier: String = bd.get("tier", "Poor")

	# Tally drops per family and per note position.
	var family_drops: Dictionary = {}
	var note_drops: Dictionary = {}
	var total_drops := 0
	for entry in summary:
		var amt: int = int(entry["amount"])
		var family: String = entry["family"]
		var note: String = entry["note"]
		family_drops[family] = family_drops.get(family, 0) + amt
		note_drops[note] = note_drops.get(note, 0) + amt
		total_drops += amt

	# Sort families by drop count descending.
	var sorted_families: Array = []
	for family in family_drops:
		sorted_families.append({ "name": family, "drops": family_drops[family] })
	sorted_families.sort_custom(func(a, b): return a["drops"] > b["drops"])

	var dominant_family: String = sorted_families[0]["name"]

	# --- Component A: Opening line ---
	var openings: Array = _OPENING_LINES.get(dominant_family, ["A curious fragrance"])
	var opening: String = openings[randi() % openings.size()]

	# --- Component B: Secondary modifier ---
	var modifier := ""
	if sorted_families.size() >= 2:
		var secondary: Dictionary = sorted_families[1]
		var secondary_frac: float = float(secondary["drops"]) / float(total_drops)
		if secondary["drops"] >= 2 or secondary_frac >= 0.25:
			modifier = _SECONDARY_MODIFIERS.get(secondary["name"], "")
		else:
			modifier = _SOLO_MODIFIERS[randi() % _SOLO_MODIFIERS.size()]
	else:
		modifier = _SOLO_MODIFIERS[randi() % _SOLO_MODIFIERS.size()]

	# --- Component C: Structure line (note positions) ---
	var has_top := note_drops.has("top")
	var has_mid := note_drops.has("middle")
	var has_base := note_drops.has("base")
	var structure := _get_structure_line(has_top, has_mid, has_base, tier)

	# --- Assemble ---
	var result := opening
	if modifier != "":
		result += ", " + modifier
	result += "."
	if structure != "":
		result += " " + structure

	return result


static func _get_structure_line(has_top: bool, has_mid: bool, has_base: bool, tier: String) -> String:
	# Quality-colored word choices.
	var is_excellent := tier == "Excellent"
	var is_good := tier == "Good"
	var is_decent := tier == "Decent"
	# Poor is the fallback.

	if has_top and has_mid and has_base:
		if is_excellent:
			return "It unfolds beautifully — a bright opening, a lush heart, and a warm, lasting finish."
		elif is_good:
			return "It unfolds in layers — a lively opening, a rich heart, and a lasting finish."
		elif is_decent:
			return "It tries to unfold in layers, but the notes feel unevenly matched."
		else:
			return "It tries to unfold in layers but the notes fight each other."

	if has_top and has_mid and not has_base:
		if is_excellent or is_good:
			return "It opens brightly and settles into a warm core, though it fades quickly."
		elif is_decent:
			return "It opens brightly but fades before it can leave a lasting impression."
		else:
			return "It sparks and sputters — gone almost as soon as it arrives."

	if has_top and has_base and not has_mid:
		if is_excellent or is_good:
			return "A striking first impression that leaps to a deep base — bold but missing its heart."
		else:
			return "A striking first impression that jumps to a deep base — the middle is missing."

	if has_mid and has_base and not has_top:
		if is_excellent or is_good:
			return "It builds slowly from a quiet start into something deep and enduring."
		elif is_decent:
			return "It builds slowly but never quite finds its opening."
		else:
			return "It plods along without a clear beginning — heavy and searching."

	if has_top and not has_mid and not has_base:
		if is_good:
			return "All sparkle and first impression — pleasant but fleeting."
		else:
			return "All sparkle and first impression — gone almost as soon as you notice it."

	if has_mid and not has_top and not has_base:
		return "A steady, centered scent with no opening and no anchor."

	if has_base and not has_top and not has_mid:
		if is_good:
			return "Deep and heavy from the start — a scent that clings and lingers."
		else:
			return "Deep and heavy from the start — it clings but never quite blooms."

	return ""
