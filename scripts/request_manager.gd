extends Node

## Manages a tiered request system. One active request at a time.
## Requests are loaded from res://data/requests.json and organized by tier.
## Progress is saved to user://request_data.json.

signal request_changed
signal request_completed(request: BaseRequest)

const SAVE_PATH := "user://request_data.json"
const REQUESTS_PATH := "res://data/requests.json"
const NPCS_PATH := "res://data/npcs.json"
const COMPLETIONS_TO_ADVANCE := 2
const BLENDS_TO_ROTATE := 4

var _all_requests: Array[BaseRequest] = []
var _requests_by_tier: Dictionary = {}  # { tier_int: Array[BaseRequest] }
var _npcs: Dictionary = {}  # { npc_id: Dictionary }

## The single active request shown on the board.
var active_request: BaseRequest = null
var current_tier: int = 1
var _completed_ids: Array[String] = []
var _completed_count_per_tier: Dictionary = {}
var _current_request_index: int = 0
var blends_since_last_fulfill: int = 0
var _seen_current: bool = false


func _ready() -> void:
	_load_npcs()
	_load_requests_from_json()
	_organize_by_tier()
	_load_progress()
	_pick_request()


# ---------------------------------------------------------------------------
# Loading
# ---------------------------------------------------------------------------

func _load_npcs() -> void:
	if not FileAccess.file_exists(NPCS_PATH):
		push_warning("RequestManager: Could not find %s" % NPCS_PATH)
		return

	var file := FileAccess.open(NPCS_PATH, FileAccess.READ)
	if file == null:
		push_warning("RequestManager: Could not open %s" % NPCS_PATH)
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("RequestManager: Failed to parse %s" % NPCS_PATH)
		return

	var data = json.data
	if not data is Dictionary or not data.has("npcs"):
		push_warning("RequestManager: Invalid format in %s" % NPCS_PATH)
		return

	for entry in data["npcs"]:
		if entry is Dictionary and entry.has("id"):
			_npcs[entry["id"]] = entry


## Returns the NPC dictionary for the given npc_id, or an empty dict if not found.
func get_npc(npc_id: String) -> Dictionary:
	return _npcs.get(npc_id, {})


## Returns the display name for a request's NPC, or "" if none.
func get_npc_name(request: BaseRequest) -> String:
	var npc := get_npc(request.npc_id)
	return npc.get("name", "")


## Returns the personality tag for a request's NPC, or "" if none.
func get_npc_personality(request: BaseRequest) -> String:
	var npc := get_npc(request.npc_id)
	return npc.get("personality", "")


func _load_requests_from_json() -> void:
	if not FileAccess.file_exists(REQUESTS_PATH):
		push_warning("RequestManager: Could not find %s" % REQUESTS_PATH)
		return

	var file := FileAccess.open(REQUESTS_PATH, FileAccess.READ)
	if file == null:
		push_warning("RequestManager: Could not open %s" % REQUESTS_PATH)
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("RequestManager: Failed to parse %s" % REQUESTS_PATH)
		return

	var data = json.data
	if not data is Dictionary or not data.has("requests"):
		push_warning("RequestManager: Invalid format in %s" % REQUESTS_PATH)
		return

	for entry in data["requests"]:
		if entry is Dictionary:
			_all_requests.append(BaseRequest.from_dict(entry))


func _organize_by_tier() -> void:
	_requests_by_tier.clear()
	for req in _all_requests:
		if not _requests_by_tier.has(req.tier):
			_requests_by_tier[req.tier] = []
		_requests_by_tier[req.tier].append(req)


# ---------------------------------------------------------------------------
# Request picking and rotation
# ---------------------------------------------------------------------------

func _pick_request() -> void:
	var pool := _get_uncompleted_for_tier(current_tier)

	# If current tier is empty, try advancing.
	if pool.is_empty():
		if current_tier < 4:
			current_tier += 1
			_current_request_index = 0
			_pick_request()
			return
		else:
			# All requests completed.
			active_request = null
			_seen_current = true
			request_changed.emit()
			return

	_current_request_index = _current_request_index % pool.size()
	active_request = pool[_current_request_index]
	_seen_current = false
	request_changed.emit()


func on_blend_committed() -> void:
	if active_request == null:
		return
	blends_since_last_fulfill += 1
	if blends_since_last_fulfill >= BLENDS_TO_ROTATE:
		_rotate_request()
	_save_progress()


func _rotate_request() -> void:
	blends_since_last_fulfill = 0
	var pool := _get_uncompleted_for_tier(current_tier)
	if pool.size() <= 1:
		return
	_current_request_index = (_current_request_index + 1) % pool.size()
	_pick_request()


# ---------------------------------------------------------------------------
# Delivery
# ---------------------------------------------------------------------------

## Attempt to deliver a bottle for the active request.
## Returns { "success": bool, "feedback": String }.
## Does NOT consume the bottle — caller should handle that on success.
func deliver_request(bottle: BottledPerfume) -> Dictionary:
	if active_request == null:
		return { "success": false, "feedback": "No active request." }

	if not bottle.matches_request(active_request):
		return { "success": false, "feedback": active_request.failure_feedback }

	# Success — mark complete and grant reward.
	var completed_req := active_request
	_completed_ids.append(completed_req.id)
	var tier := completed_req.tier
	_completed_count_per_tier[tier] = _completed_count_per_tier.get(tier, 0) + 1
	blends_since_last_fulfill = 0

	_grant_reward(completed_req)

	var feedback := completed_req.reward_text
	request_completed.emit(completed_req)

	# Check tier advancement.
	if _completed_count_per_tier.get(tier, 0) >= COMPLETIONS_TO_ADVANCE and current_tier == tier and current_tier < 4:
		current_tier += 1
		_current_request_index = 0

	_pick_request()
	_save_progress()
	return { "success": true, "feedback": feedback }


func _grant_reward(request: BaseRequest) -> void:
	match request.reward_type:
		"coin":
			CoinManager.add_coins(request.reward_amount)
		"ingredient":
			if request.reward_ingredient_path != "" and ResourceLoader.exists(request.reward_ingredient_path):
				var ing := load(request.reward_ingredient_path) as BaseIngredient
				if ing:
					InventoryManager.add_ingredient(ing, request.reward_amount)
		"hint":
			pass  # reward_text contains the hint; the UI displays it.


# ---------------------------------------------------------------------------
# Seen / unseen indicator
# ---------------------------------------------------------------------------

func mark_seen() -> void:
	_seen_current = true


func is_unseen() -> bool:
	return active_request != null and not _seen_current


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _get_uncompleted_for_tier(tier: int) -> Array[BaseRequest]:
	var pool: Array[BaseRequest] = []
	for req in _requests_by_tier.get(tier, []):
		if req.id not in _completed_ids:
			pool.append(req)
	return pool


func get_requirements_text(request: BaseRequest) -> String:
	var parts: Array[String] = []
	if request.min_drops > 0:
		parts.append("%d+ drops" % request.min_drops)
	for family: String in request.required_families:
		parts.append("%d+ %s" % [request.required_families[family], family])
	for note: String in request.required_notes:
		parts.append("%d+ %s note" % [request.required_notes[note], note])
	if request.min_quality > 0.0:
		parts.append("quality %.0f+" % request.min_quality)
	if request.requires_accord:
		parts.append("uses a discovered accord")
	if request.requires_aged:
		parts.append("properly aged")
	if parts.is_empty():
		return "No special requirements."
	return "Requires: " + ", ".join(parts)


# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

func _save_progress() -> void:
	var data := {
		"completed_ids": _completed_ids.duplicate(),
		"current_tier": current_tier,
		"current_request_index": _current_request_index,
		"blends_since_last_fulfill": blends_since_last_fulfill,
		"completed_count_per_tier": _completed_count_per_tier.duplicate(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("RequestManager: Could not open save file for writing.")
		return
	file.store_string(JSON.stringify(data, "\t"))


func _load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return

	var data = json.data
	if not data is Dictionary:
		return

	for id: String in data.get("completed_ids", []):
		_completed_ids.append(id)

	current_tier = int(data.get("current_tier", 1))
	_current_request_index = int(data.get("current_request_index", 0))
	blends_since_last_fulfill = int(data.get("blends_since_last_fulfill", 0))

	var saved_counts = data.get("completed_count_per_tier", {})
	if saved_counts is Dictionary:
		for key in saved_counts:
			_completed_count_per_tier[int(key)] = int(saved_counts[key])
