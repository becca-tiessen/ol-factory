extends Node

## Manages play-time tracking, bottled perfume inventory, and the aging rack.
## Registered as an autoload so any script can access it via CellarManager.
## Persists to user://cellar_data.json.

signal bottles_changed
signal rack_changed
signal display_changed

const SAVE_PATH := "user://cellar_data.json"
const BASE_RACK_SLOTS := 5
const MAX_EXTRA_RACK_SLOTS := 2
## +0.25 quality per 120 seconds of gameplay.
const AGE_RATE := 0.25 / 120.0
const AGE_CAP := 1.5
## How often (seconds) to auto-save play time.
const PLAY_TIME_SAVE_INTERVAL := 30.0

## Total accumulated gameplay seconds (persisted).
var play_time: float = 0.0

## Bottled perfumes the player is carrying (not on rack).
var bottles: Array[BottledPerfume] = []

## Bottles placed on the aging rack.
## Each entry: { "bottle": BottledPerfume, "placed_at": float (play_time when placed) }
var aging_rack: Array = []

## Extra rack slots purchased from the shop (0 to MAX_EXTRA_RACK_SLOTS).
var extra_rack_slots: int = 0

## Bottles on the display shelf (trophies).
var displayed_bottles: Array[BottledPerfume] = []

var _save_timer: float = 0.0


func _ready() -> void:
	_load_data()


func _process(delta: float) -> void:
	play_time += delta
	_save_timer += delta
	if _save_timer >= PLAY_TIME_SAVE_INTERVAL:
		_save_timer = 0.0
		_save_data()


# ---------------------------------------------------------------------------
# Bottle inventory
# ---------------------------------------------------------------------------

func add_bottle(bottle: BottledPerfume) -> void:
	bottles.append(bottle)
	bottles_changed.emit()
	_save_data()


func remove_bottle(bottle: BottledPerfume) -> void:
	bottles.erase(bottle)
	bottles_changed.emit()
	_save_data()


# ---------------------------------------------------------------------------
# Aging rack
# ---------------------------------------------------------------------------

func get_rack_slots() -> int:
	return BASE_RACK_SLOTS + extra_rack_slots


func rack_has_space() -> bool:
	return aging_rack.size() < get_rack_slots()


func can_buy_rack_slot() -> bool:
	return extra_rack_slots < MAX_EXTRA_RACK_SLOTS


func buy_rack_slot() -> bool:
	if not can_buy_rack_slot():
		return false
	extra_rack_slots += 1
	rack_changed.emit()
	_save_data()
	return true


func place_on_rack(bottle: BottledPerfume) -> bool:
	if not rack_has_space():
		return false
	bottles.erase(bottle)
	aging_rack.append({ "bottle": bottle, "placed_at": play_time })
	bottles_changed.emit()
	rack_changed.emit()
	_save_data()
	return true


func retrieve_from_rack(index: int) -> BottledPerfume:
	if index < 0 or index >= aging_rack.size():
		return null
	var entry: Dictionary = aging_rack[index]
	var bottle: BottledPerfume = entry["bottle"]
	bottle.age_bonus = get_age_bonus(index)
	bottle.aged = true
	aging_rack.remove_at(index)
	rack_changed.emit()
	_save_data()
	return bottle


func get_age_bonus(rack_index: int) -> float:
	if rack_index < 0 or rack_index >= aging_rack.size():
		return 0.0
	var entry: Dictionary = aging_rack[rack_index]
	var elapsed: float = play_time - float(entry["placed_at"])
	return minf(elapsed * AGE_RATE, AGE_CAP)


func is_ready(rack_index: int) -> bool:
	return get_age_bonus(rack_index) >= AGE_CAP


# ---------------------------------------------------------------------------
# Display shelf
# ---------------------------------------------------------------------------

func display_bottle(bottle: BottledPerfume) -> void:
	bottles.erase(bottle)
	displayed_bottles.append(bottle)
	bottles_changed.emit()
	display_changed.emit()
	_save_data()


func undisplay_bottle(bottle: BottledPerfume) -> void:
	displayed_bottles.erase(bottle)
	bottles.append(bottle)
	display_changed.emit()
	bottles_changed.emit()
	_save_data()


# ---------------------------------------------------------------------------
# Delivery — consume a bottle (caller handles request logic)
# ---------------------------------------------------------------------------

func deliver_bottle(bottle: BottledPerfume) -> void:
	remove_bottle(bottle)


# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

func _save_data() -> void:
	var bottle_entries := []
	for b: BottledPerfume in bottles:
		bottle_entries.append(b.to_dict())

	var rack_entries := []
	for entry in aging_rack:
		rack_entries.append({
			"bottle": (entry["bottle"] as BottledPerfume).to_dict(),
			"placed_at": entry["placed_at"],
		})

	var display_entries := []
	for b: BottledPerfume in displayed_bottles:
		display_entries.append(b.to_dict())

	var data := {
		"play_time": play_time,
		"bottles": bottle_entries,
		"aging_rack": rack_entries,
		"displayed": display_entries,
		"extra_rack_slots": extra_rack_slots,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("CellarManager: Could not open save file for writing.")
		return
	file.store_string(JSON.stringify(data, "\t"))


func _load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("CellarManager: Could not open save file for reading.")
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("CellarManager: Save file is corrupt, starting fresh.")
		return

	var data = json.data
	if not data is Dictionary:
		return

	play_time = float(data.get("play_time", 0.0))

	bottles.clear()
	for entry in data.get("bottles", []):
		if entry is Dictionary:
			bottles.append(BottledPerfume.from_dict(entry))

	aging_rack.clear()
	for entry in data.get("aging_rack", []):
		if entry is Dictionary and entry.has("bottle") and entry.has("placed_at"):
			aging_rack.append({
				"bottle": BottledPerfume.from_dict(entry["bottle"]),
				"placed_at": float(entry["placed_at"]),
			})

	displayed_bottles.clear()
	for entry in data.get("displayed", []):
		if entry is Dictionary:
			displayed_bottles.append(BottledPerfume.from_dict(entry))

	extra_rack_slots = clampi(int(data.get("extra_rack_slots", 0)), 0, MAX_EXTRA_RACK_SLOTS)
