extends Node

## Tracks player XP, rank, recipe history, and ingredient variety.
## Awards XP for crafting, discovering accords, and completing requests.
## Saves to user://progression_data.json.

signal xp_changed(total_xp: int)
signal rank_up(old_rank: String, new_rank: String)

const SAVE_PATH := "user://progression_data.json"

const RANK_ORDER: Array[String] = ["Novice", "Apprentice", "Journeyman", "Master"]
const RANK_THRESHOLDS := {
	"Novice": 0,
	"Apprentice": 200,
	"Journeyman": 600,
	"Master": 1500,
}

const TIER_XP := { "Poor": 5, "Decent": 15, "Good": 30, "Excellent": 50 }
const FIRST_RECIPE_BONUS := 10
const VARIETY_BONUS_PER := 5
const ACCORD_XP := 25
const REQUEST_TIER_XP := { 1: 20, 2: 35, 3: 50, 4: 75 }

var current_xp: int = 0
var current_rank: String = "Novice"

## Each entry is a sorted array of ingredient display_names.
var _bottled_recipes: Array = []

## All ingredient display_names ever used in a bottled blend.
var _used_ingredients: Array[String] = []


func _ready() -> void:
	_load_data()
	AccordManager.accord_discovered.connect(_on_accord_discovered)
	RequestManager.request_completed.connect(_on_request_completed)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func award_crafting_xp(bottle: BottledPerfume) -> void:
	var total := 0

	# Quality-based XP.
	total += TIER_XP.get(bottle.tier, 5)

	# First-time recipe bonus.
	var recipe_key := _make_recipe_key(bottle)
	if not _bottled_recipes.has(recipe_key):
		_bottled_recipes.append(recipe_key)
		total += FIRST_RECIPE_BONUS

	# Variety bonus — new ingredients the player has never bottled before.
	for entry in bottle.blend_summary:
		var ing_name: String = entry["name"]
		if not _used_ingredients.has(ing_name):
			_used_ingredients.append(ing_name)
			total += VARIETY_BONUS_PER

	_add_xp(total)


func get_xp_progress() -> Dictionary:
	var rank_start: int = RANK_THRESHOLDS.get(current_rank, 0)
	var next_rank: String = get_next_rank()
	var rank_end: int = RANK_THRESHOLDS.get(next_rank, rank_start) if next_rank != "" else rank_start
	return { "current": current_xp, "rank_start": rank_start, "rank_end": rank_end }


func get_next_rank() -> String:
	var idx: int = RANK_ORDER.find(current_rank)
	if idx < 0 or idx >= RANK_ORDER.size() - 1:
		return ""
	return RANK_ORDER[idx + 1]


func is_max_rank() -> bool:
	return current_rank == RANK_ORDER[RANK_ORDER.size() - 1]


func get_rank_index(rank: String) -> int:
	return RANK_ORDER.find(rank)


func has_rank(required_rank: String) -> bool:
	return get_rank_index(current_rank) >= get_rank_index(required_rank)


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _on_accord_discovered(_accord: BaseAccord) -> void:
	_add_xp(ACCORD_XP)


func _on_request_completed(request: BaseRequest) -> void:
	_add_xp(REQUEST_TIER_XP.get(request.tier, 20))


func _add_xp(amount: int) -> void:
	if amount <= 0:
		return
	current_xp += amount

	var new_rank: String = _get_rank_for_xp(current_xp)
	var old_rank: String = current_rank
	if new_rank != current_rank:
		current_rank = new_rank
		rank_up.emit(old_rank, new_rank)

	xp_changed.emit(current_xp)
	_save_data()


func _get_rank_for_xp(xp: int) -> String:
	var result: String = "Novice"
	for i in RANK_ORDER.size():
		var rank: String = RANK_ORDER[i]
		if xp >= RANK_THRESHOLDS[rank]:
			result = rank
	return result


func _make_recipe_key(bottle: BottledPerfume) -> Array:
	var names: Array[String] = []
	for entry in bottle.blend_summary:
		var n: String = entry["name"]
		if not names.has(n):
			names.append(n)
	names.sort()
	return names


# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

func _save_data() -> void:
	var data := {
		"current_xp": current_xp,
		"current_rank": current_rank,
		"bottled_recipes": _bottled_recipes,
		"used_ingredients": _used_ingredients,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("ProgressionManager: Could not open save file for writing.")
		return
	file.store_string(JSON.stringify(data, "\t"))


func _load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("ProgressionManager: Could not open save file for reading.")
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("ProgressionManager: Save file is corrupt, starting fresh.")
		return

	var data = json.data
	if not data is Dictionary:
		return

	current_xp = int(data.get("current_xp", 0))
	current_rank = String(data.get("current_rank", "Novice"))

	_bottled_recipes.clear()
	for entry in data.get("bottled_recipes", []):
		if entry is Array:
			var recipe: Array[String] = []
			for name in entry:
				recipe.append(String(name))
			_bottled_recipes.append(recipe)

	_used_ingredients.clear()
	for name in data.get("used_ingredients", []):
		if name is String:
			_used_ingredients.append(name)
