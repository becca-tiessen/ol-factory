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

	# Required families
	if not request.required_families.is_empty():
		var family_counts: Dictionary = {}
		for entry in blend_summary:
			family_counts[entry["family"]] = family_counts.get(entry["family"], 0) + int(entry["amount"])
		for family: String in request.required_families:
			if family_counts.get(family, 0) < int(request.required_families[family]):
				return false

	# Required notes
	if not request.required_notes.is_empty():
		var note_counts: Dictionary = {}
		for entry in blend_summary:
			note_counts[entry["note"]] = note_counts.get(entry["note"], 0) + int(entry["amount"])
		for note: String in request.required_notes:
			if note_counts.get(note, 0) < int(request.required_notes[note]):
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
	return {
		"blend_summary": blend_summary.duplicate(true),
		"base_quality": base_quality,
		"tier": tier,
		"breakdown": breakdown.duplicate(),
		"total_drops": total_drops,
		"age_bonus": age_bonus,
		"aged": aged,
		"has_accord": has_accord,
	}


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
	return bottle
