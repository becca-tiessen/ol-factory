extends Node

## Manages the processing queue (raw ingredients → oils) and ready-oil pickup.
## Registered as an autoload so any script can access it via ProcessingManager.
## Persists queue, ready oils, and intro flag to user://processing_data.json.
##
## Supports two modes: Margot's processor (60s, 5 coins) and the player's
## workshop processor (30s, free), unlocked at Apprentice rank.

signal queue_changed
signal oils_ready

const SAVE_PATH := "user://processing_data.json"
const PROCESS_COST := 5
const PROCESS_DURATION := 60.0  # seconds of play time per batch

const WORKSHOP_COST := 0
const WORKSHOP_DURATION := 30.0

## Whether the player has met Margot and received starter oils.
var has_met_processor: bool = false

## In-progress batches. Each entry: { "raw_path": String, "submitted_at": float, "workshop": bool }
var _queue: Array[Dictionary] = []

## Finished oils awaiting pickup. Each entry: { "path": String, "workshop": bool }
var _ready_oils: Array[Dictionary] = []


func _ready() -> void:
	_load_data()


func _process(_delta: float) -> void:
	_check_completions()


# ---------------------------------------------------------------------------
# Submitting raw ingredients
# ---------------------------------------------------------------------------

func submit(raw_ingredient: BaseIngredient) -> bool:
	if raw_ingredient.result_item == null:
		return false
	if not CoinManager.spend_coins(PROCESS_COST):
		return false
	InventoryManager.remove_ingredient(raw_ingredient)
	_queue.append({
		"raw_path": raw_ingredient.resource_path,
		"submitted_at": CellarManager.play_time,
		"workshop": false,
	})
	queue_changed.emit()
	_save_data()
	return true


func submit_batch(raw_ingredients: Array[BaseIngredient]) -> int:
	var submitted := 0
	var total_cost: int = raw_ingredients.size() * PROCESS_COST
	if CoinManager.get_coins() < total_cost:
		return 0
	for raw in raw_ingredients:
		if submit(raw):
			submitted += 1
	return submitted


func submit_workshop(raw_ingredient: BaseIngredient) -> bool:
	if raw_ingredient.result_item == null:
		return false
	InventoryManager.remove_ingredient(raw_ingredient)
	_queue.append({
		"raw_path": raw_ingredient.resource_path,
		"submitted_at": CellarManager.play_time,
		"workshop": true,
	})
	queue_changed.emit()
	_save_data()
	return true


# ---------------------------------------------------------------------------
# Completion check
# ---------------------------------------------------------------------------

func _check_completions() -> void:
	if _queue.is_empty():
		return

	var completed_any := false
	var remaining: Array[Dictionary] = []

	for entry in _queue:
		var elapsed: float = CellarManager.play_time - float(entry["submitted_at"])
		var duration: float = WORKSHOP_DURATION if entry.get("workshop", false) else PROCESS_DURATION
		if elapsed >= duration:
			var raw_res := load(entry["raw_path"]) as BaseIngredient
			if raw_res and raw_res.result_item is BaseIngredient:
				var oil: BaseIngredient = raw_res.result_item as BaseIngredient
				_ready_oils.append({
					"path": oil.resource_path,
					"workshop": entry.get("workshop", false),
				})
				completed_any = true
		else:
			remaining.append(entry)

	if completed_any:
		_queue = remaining
		queue_changed.emit()
		oils_ready.emit()
		_save_data()


# ---------------------------------------------------------------------------
# Collecting finished oils
# ---------------------------------------------------------------------------

func has_ready_oils() -> bool:
	return not _ready_oils.is_empty()


func get_ready_oils() -> Array[String]:
	var paths: Array[String] = []
	for entry in _ready_oils:
		paths.append(entry["path"])
	return paths


func get_ready_oils_filtered(workshop: bool = false) -> Array[String]:
	var paths: Array[String] = []
	for entry in _ready_oils:
		if entry.get("workshop", false) == workshop:
			paths.append(entry["path"])
	return paths


func collect_all() -> int:
	if _ready_oils.is_empty():
		return 0
	var count := _ready_oils.size()
	for entry in _ready_oils:
		var oil := load(entry["path"]) as BaseIngredient
		if oil:
			InventoryManager.add_ingredient(oil)
	_ready_oils.clear()
	queue_changed.emit()
	_save_data()
	return count


func collect_all_filtered(workshop: bool = false) -> int:
	var to_collect: Array[Dictionary] = []
	var remaining: Array[Dictionary] = []
	for entry in _ready_oils:
		if entry.get("workshop", false) == workshop:
			to_collect.append(entry)
		else:
			remaining.append(entry)
	if to_collect.is_empty():
		return 0
	for entry in to_collect:
		var oil := load(entry["path"]) as BaseIngredient
		if oil:
			InventoryManager.add_ingredient(oil)
	_ready_oils = remaining
	queue_changed.emit()
	_save_data()
	return to_collect.size()


func collect_oil(oil_path: String) -> bool:
	var idx := -1
	for i in _ready_oils.size():
		if _ready_oils[i]["path"] == oil_path:
			idx = i
			break
	if idx == -1:
		return false
	var oil := load(oil_path) as BaseIngredient
	if oil == null:
		return false
	_ready_oils.remove_at(idx)
	InventoryManager.add_ingredient(oil)
	queue_changed.emit()
	_save_data()
	return true


# ---------------------------------------------------------------------------
# Queue info
# ---------------------------------------------------------------------------

func get_queue() -> Array[Dictionary]:
	return _queue.duplicate()


func get_queue_filtered(workshop: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _queue:
		if entry.get("workshop", false) == workshop:
			result.append(entry)
	return result


func get_queue_time_remaining(entry: Dictionary) -> float:
	var elapsed: float = CellarManager.play_time - float(entry["submitted_at"])
	var duration: float = WORKSHOP_DURATION if entry.get("workshop", false) else PROCESS_DURATION
	return maxf(duration - elapsed, 0.0)


# ---------------------------------------------------------------------------
# Intro state
# ---------------------------------------------------------------------------

func mark_processor_met() -> void:
	has_met_processor = true
	_save_data()


# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

func _save_data() -> void:
	var queue_entries := []
	for entry in _queue:
		queue_entries.append({
			"raw_path": entry["raw_path"],
			"submitted_at": entry["submitted_at"],
			"workshop": entry.get("workshop", false),
		})

	var ready_entries := []
	for entry in _ready_oils:
		ready_entries.append({
			"path": entry["path"],
			"workshop": entry.get("workshop", false),
		})

	var data := {
		"has_met_processor": has_met_processor,
		"ready_oils": ready_entries,
		"queue": queue_entries,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("ProcessingManager: Could not open save file for writing.")
		return
	file.store_string(JSON.stringify(data, "\t"))


func _load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("ProcessingManager: Could not open save file for reading.")
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("ProcessingManager: Save file is corrupt, starting fresh.")
		return

	var data = json.data
	if not data is Dictionary:
		return

	has_met_processor = bool(data.get("has_met_processor", false))

	_ready_oils.clear()
	for entry in data.get("ready_oils", []):
		# Support legacy format (plain string paths) and new format (dicts).
		if entry is String and ResourceLoader.exists(entry):
			_ready_oils.append({ "path": entry, "workshop": false })
		elif entry is Dictionary and entry.has("path"):
			var p: String = entry["path"]
			if ResourceLoader.exists(p):
				_ready_oils.append({ "path": p, "workshop": bool(entry.get("workshop", false)) })

	_queue.clear()
	for entry in data.get("queue", []):
		if entry is Dictionary and entry.has("raw_path") and entry.has("submitted_at"):
			if ResourceLoader.exists(entry["raw_path"]):
				_queue.append({
					"raw_path": String(entry["raw_path"]),
					"submitted_at": float(entry["submitted_at"]),
					"workshop": bool(entry.get("workshop", false)),
				})
