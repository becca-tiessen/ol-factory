extends Node

## Simple inventory that tracks gathered ingredients and their quantities.
## Registered as an autoload so any script can access it via InventoryManager.
## Automatically persists to user://save_data.json on every change.

signal inventory_changed

const SAVE_PATH := "user://save_data.json"
const SAVE_VERSION := 1

# { BaseIngredient resource : int count }
var _items: Dictionary = {}

func _ready() -> void:
	_load_inventory()
	inventory_changed.connect(_save_inventory)

func add_ingredient(ingredient: BaseIngredient, amount: int = 1) -> void:
	if ingredient in _items:
		_items[ingredient] += amount
	else:
		_items[ingredient] = amount
	inventory_changed.emit()

func remove_ingredient(ingredient: BaseIngredient, amount: int = 1) -> bool:
	if ingredient not in _items or _items[ingredient] < amount:
		return false
	_items[ingredient] -= amount
	if _items[ingredient] <= 0:
		_items.erase(ingredient)
	inventory_changed.emit()
	return true

func get_count(ingredient: BaseIngredient) -> int:
	return _items.get(ingredient, 0)

func get_all() -> Dictionary:
	return _items.duplicate()

func has_ingredient(ingredient: BaseIngredient) -> bool:
	return ingredient in _items and _items[ingredient] > 0

# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

func _save_inventory() -> void:
	var entries := []
	for ingredient: BaseIngredient in _items:
		entries.append({
			"path": ingredient.resource_path,
			"count": _items[ingredient],
		})
	var data := {
		"version": SAVE_VERSION,
		"inventory": entries,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("InventoryManager: Could not open save file for writing.")
		return
	file.store_string(JSON.stringify(data, "\t"))

func _load_inventory() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("InventoryManager: Could not open save file for reading.")
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("InventoryManager: Save file is corrupt, starting fresh.")
		return

	var data = json.data
	if not data is Dictionary or not data.has("inventory"):
		push_warning("InventoryManager: Save file has unexpected format, starting fresh.")
		return

	for entry in data["inventory"]:
		if not entry is Dictionary or not entry.has("path") or not entry.has("count"):
			continue
		var res_path: String = entry["path"]
		if not ResourceLoader.exists(res_path):
			continue
		var ingredient := load(res_path) as BaseIngredient
		if ingredient == null:
			continue
		_items[ingredient] = int(entry["count"])
