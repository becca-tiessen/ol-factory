extends Node

## Tracks the player's coin balance. Persists to user://coin_data.json.

signal coins_changed

const SAVE_PATH := "user://coin_data.json"

var coins: int = 0


func _ready() -> void:
	_load_data()


func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit()
	_save_data()


func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit()
	_save_data()
	return true


func get_coins() -> int:
	return coins


# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

func _save_data() -> void:
	var data := { "coins": coins }
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("CoinManager: Could not open save file for writing.")
		return
	file.store_string(JSON.stringify(data, "\t"))


func _load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("CoinManager: Could not open save file for reading.")
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("CoinManager: Save file is corrupt, starting fresh.")
		return

	var data = json.data
	if not data is Dictionary:
		return

	coins = int(data.get("coins", 0))
