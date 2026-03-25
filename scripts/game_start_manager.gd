extends Node

## Tracks opening-sequence progress and the player's chosen name.
## Registered as an autoload so any script can check first-visit flags.
## Persists to user://game_start_data.json.

signal opening_completed

const SAVE_PATH := "user://game_start_data.json"

## Whether the contract scene has been completed.
var has_signed_contract: bool = false

## The name the player entered during the contract signing.
var player_name: String = ""

## Whether the player has seen the first mixing bench moment.
var has_seen_bench_intro: bool = false


func _ready() -> void:
	_load_data()


func is_new_game() -> bool:
	return not has_signed_contract


func complete_contract(chosen_name: String) -> void:
	has_signed_contract = true
	player_name = chosen_name
	_save_data()
	opening_completed.emit()


func mark_bench_intro_seen() -> void:
	has_seen_bench_intro = true
	_save_data()


# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

func _save_data() -> void:
	var data := {
		"has_signed_contract": has_signed_contract,
		"player_name": player_name,
		"has_seen_bench_intro": has_seen_bench_intro,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("GameStartManager: Could not open save file for writing.")
		return
	file.store_string(JSON.stringify(data, "\t"))


func _load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("GameStartManager: Could not open save file for reading.")
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("GameStartManager: Save file is corrupt, starting fresh.")
		return

	var data = json.data
	if not data is Dictionary:
		return

	has_signed_contract = bool(data.get("has_signed_contract", false))
	player_name = str(data.get("player_name", ""))
	has_seen_bench_intro = bool(data.get("has_seen_bench_intro", false))
