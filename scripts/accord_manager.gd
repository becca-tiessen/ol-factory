extends Node

## Tracks discovered accords and checks blends for new discoveries.
## Registered as an autoload so any script can access it via AccordManager.
## Persists discoveries to user://accord_data.json.

signal accord_discovered(accord: BaseAccord)
signal accords_changed

const SAVE_PATH := "user://accord_data.json"

var _all_accords: Array[BaseAccord] = []
var _discovered: Dictionary = {}  # { resource_path: true }


func _ready() -> void:
	_load_all_accords()
	_load_discovered()


func _load_all_accords() -> void:
	var dir := DirAccess.open("res://data/accords/")
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var resource := load("res://data/accords/" + file_name)
			if resource is BaseAccord:
				_all_accords.append(resource as BaseAccord)
		file_name = dir.get_next()
	dir.list_dir_end()


## Check a blend for any newly discovered accords.
## blend format: [{ "ingredient": BaseIngredient, "amount": float }, ...]
## Returns only accords that were NOT previously discovered.
func check_blend_for_accords(blend: Array) -> Array[BaseAccord]:
	# Build a lookup: ingredient resource path -> drop count in this blend.
	var blend_counts: Dictionary = {}
	for entry in blend:
		var ing: BaseIngredient = entry["ingredient"]
		blend_counts[ing.resource_path] = int(entry["amount"])

	var newly_discovered: Array[BaseAccord] = []
	for accord in _all_accords:
		if _discovered.has(accord.resource_path):
			continue
		if _blend_matches_recipe(blend_counts, accord.recipe):
			_discovered[accord.resource_path] = true
			newly_discovered.append(accord)
			accord_discovered.emit(accord)

	if not newly_discovered.is_empty():
		accords_changed.emit()
		_save_discovered()

	return newly_discovered


func _blend_matches_recipe(blend_counts: Dictionary, recipe: Dictionary) -> bool:
	# Blend must contain exactly the recipe ingredients — no extras allowed.
	# Drop counts must meet minimums but can exceed them.
	if blend_counts.size() != recipe.size():
		return false
	for ingredient_path: String in recipe:
		var required: int = int(recipe[ingredient_path])
		if blend_counts.get(ingredient_path, 0) < required:
			return false
	return true


func get_all_accords() -> Array[BaseAccord]:
	return _all_accords


func get_discovered_accords() -> Array[BaseAccord]:
	var result: Array[BaseAccord] = []
	for accord in _all_accords:
		if _discovered.has(accord.resource_path):
			result.append(accord)
	return result


func is_discovered(accord: BaseAccord) -> bool:
	return _discovered.has(accord.resource_path)


## Load the component BaseIngredient resources for an accord's recipe.
## Returns [{ "ingredient": BaseIngredient, "amount": int }, ...]
func get_recipe_ingredients(accord: BaseAccord) -> Array:
	var result: Array = []
	for ingredient_path: String in accord.recipe:
		var amount: int = int(accord.recipe[ingredient_path])
		if ResourceLoader.exists(ingredient_path):
			var ing := load(ingredient_path) as BaseIngredient
			if ing:
				result.append({ "ingredient": ing, "amount": amount })
	return result


# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

func _save_discovered() -> void:
	var paths: Array = []
	for path: String in _discovered:
		paths.append(path)
	var data := { "discovered": paths }
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("AccordManager: Could not open save file for writing.")
		return
	file.store_string(JSON.stringify(data, "\t"))


func _load_discovered() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("AccordManager: Could not open save file for reading.")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("AccordManager: Save file is corrupt, starting fresh.")
		return
	var data = json.data
	if not data is Dictionary or not data.has("discovered"):
		return
	for path in data["discovered"]:
		if path is String:
			_discovered[path] = true
