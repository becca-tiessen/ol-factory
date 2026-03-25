extends Node

## Manages NPC dialogue data and per-NPC persistence (has_met, last_idle_index).
## Registered as autoload: NpcDialogueManager.
## Saves to user://npc_data.json.

const SAVE_PATH := "user://npc_data.json"
const DIALOGUE_PATH := "res://data/npc_dialogue.json"

## { npc_id: { "has_met": bool, "last_idle_index": int } }
## Céline arc extras: "arc_stage": int, "stall_timer_started": float, "stall_placed": bool,
##                    "purchased_designs": Array[String]
var _npc_state: Dictionary = {}

## { npc_id: dialogue Dictionary }
var _dialogue: Dictionary = {}


func _ready() -> void:
	_load_dialogue()
	_load_state()


# ---------------------------------------------------------------------------
# Dialogue loading
# ---------------------------------------------------------------------------

func _load_dialogue() -> void:
	if not FileAccess.file_exists(DIALOGUE_PATH):
		push_warning("NpcDialogueManager: Could not find %s" % DIALOGUE_PATH)
		return

	var file := FileAccess.open(DIALOGUE_PATH, FileAccess.READ)
	if file == null:
		push_warning("NpcDialogueManager: Could not open %s" % DIALOGUE_PATH)
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("NpcDialogueManager: Failed to parse %s" % DIALOGUE_PATH)
		return

	var data = json.data
	if data is Dictionary:
		_dialogue = data


# ---------------------------------------------------------------------------
# State queries
# ---------------------------------------------------------------------------

func has_met(npc_id: String) -> bool:
	return _npc_state.get(npc_id, {}).get("has_met", false)


func mark_met(npc_id: String) -> void:
	_ensure_state(npc_id)
	_npc_state[npc_id]["has_met"] = true
	_save_state()


## Returns the next idle line for this NPC, rotating so no line repeats back-to-back.
func get_next_idle_line(npc_id: String) -> String:
	var data: Dictionary = _dialogue.get(npc_id, {})
	var idle: Array = data.get("idle", [])
	if idle.is_empty():
		return ""

	_ensure_state(npc_id)
	var last_idx: int = _npc_state[npc_id].get("last_idle_index", -1)

	# Pick any index different from last (rotate forward simply)
	var next_idx: int = (last_idx + 1) % idle.size()
	_npc_state[npc_id]["last_idle_index"] = next_idx
	_save_state()
	return idle[next_idx]


## Returns the intro lines for this NPC (array of strings).
func get_intro_lines(npc_id: String) -> Array:
	var data: Dictionary = _dialogue.get(npc_id, {})
	return data.get("intro", [])


## Returns the request-hint line, or "" if none.
func get_request_hint(npc_id: String) -> String:
	var data: Dictionary = _dialogue.get(npc_id, {})
	return data.get("request_hint", "")


## Returns the delivery success line, or "".
func get_delivery_success(npc_id: String) -> String:
	var data: Dictionary = _dialogue.get(npc_id, {})
	return data.get("delivery_success", "")


## Returns the delivery fail line, or "".
func get_delivery_fail(npc_id: String) -> String:
	var data: Dictionary = _dialogue.get(npc_id, {})
	return data.get("delivery_fail", "")


## Returns the delivery prompt template, substituting {perfume_name} and {npc_name}.
func get_delivery_prompt(npc_id: String, perfume_name: String, npc_name: String) -> String:
	var data: Dictionary = _dialogue.get(npc_id, {})
	var template: String = data.get("delivery_prompt", "Give {perfume_name} to {npc_name}?")
	return template.replace("{perfume_name}", perfume_name).replace("{npc_name}", npc_name)


# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Arc state helpers (used by CelineArc)
# ---------------------------------------------------------------------------

func get_arc_stage(npc_id: String) -> int:
	return int(_npc_state.get(npc_id, {}).get("arc_stage", 0))


func set_arc_stage(npc_id: String, stage: int) -> void:
	_ensure_state(npc_id)
	_npc_state[npc_id]["arc_stage"] = stage
	_save_state()


func get_stall_timer_started(npc_id: String) -> float:
	return float(_npc_state.get(npc_id, {}).get("stall_timer_started", -1.0))


func set_stall_timer_started(npc_id: String, play_time: float) -> void:
	_ensure_state(npc_id)
	_npc_state[npc_id]["stall_timer_started"] = play_time
	_save_state()


func is_stall_placed(npc_id: String) -> bool:
	return bool(_npc_state.get(npc_id, {}).get("stall_placed", false))


func set_stall_placed(npc_id: String, value: bool) -> void:
	_ensure_state(npc_id)
	_npc_state[npc_id]["stall_placed"] = value
	_save_state()


func get_purchased_designs(npc_id: String) -> Array:
	return _npc_state.get(npc_id, {}).get("purchased_designs", [])


func add_purchased_design(npc_id: String, design_id: String) -> void:
	_ensure_state(npc_id)
	var designs: Array = _npc_state[npc_id].get("purchased_designs", [])
	if not designs.has(design_id):
		designs.append(design_id)
	_npc_state[npc_id]["purchased_designs"] = designs
	_save_state()


func has_purchased_design(npc_id: String, design_id: String) -> bool:
	return get_purchased_designs(npc_id).has(design_id)


## Returns a dialogue key's lines array, or [] if not found.
func get_stage_lines(npc_id: String, key: String) -> Array:
	var data: Dictionary = _dialogue.get(npc_id, {})
	return data.get(key, [])


func _ensure_state(npc_id: String) -> void:
	if not _npc_state.has(npc_id):
		_npc_state[npc_id] = { "has_met": false, "last_idle_index": -1 }


func _save_state() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("NpcDialogueManager: Could not open save file for writing.")
		return
	file.store_string(JSON.stringify(_npc_state, "\t"))


func _load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return

	var data = json.data
	if data is Dictionary:
		_npc_state = data
