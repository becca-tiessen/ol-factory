extends Node

## Manages the beach's wash-up spots: rolls each visit to determine what washed ashore.
## Tracks which bottle notes have been read so the player doesn't see duplicates
## until all messages have been found.
## Saves to user://beach_data.json.

signal note_found(note: Dictionary)

const SAVE_PATH := "user://beach_data.json"
const SAVE_VERSION := 1

# Probability thresholds (cumulative, 0.0–1.0)
const PROB_NOTHING   := 0.60
const PROB_COMMON    := 0.85   # 25% chance (0.60–0.85)
const PROB_NOTE      := 0.95   # 10% chance (0.85–0.95)
# Ambergris: remaining 5% (0.95–1.0)

# Which ingredient paths can appear as common finds on the shore
const COMMON_FIND_PATHS: Array[String] = [
	"res://data/sea_salt.tres",
	"res://data/driftwood.tres",
]

# All bottle notes. Each has an id, a text body, and an optional accord_hint tag.
const ALL_NOTES: Array = [
	{
		"id": "note_candy_cane",
		"text": "On cold nights I mix the warmth of vanilla with the bite of peppermint. It reminds me of the sweets my mother made — simple, true, utterly comforting.",
		"tag": "accord_hint",
	},
	{
		"id": "note_cedar_rose",
		"text": "The secret is cedar and rose together. One grounds what the other lifts. I have never made a finer thing.",
		"tag": "accord_hint",
	},
	{
		"id": "note_pyramid",
		"text": "Three ingredients, no more: something floral for the heart, something bright for the opening, something deep to hold it all together. The pyramid is everything.",
		"tag": "wisdom",
	},
	{
		"id": "note_aging",
		"text": "I aged my finest blend for a full season before giving it away. She wept when she smelled it. The patience was rewarded tenfold.",
		"tag": "wisdom",
	},
	{
		"id": "note_sandalwood_jasmine",
		"text": "Sandalwood and jasmine, balanced so neither wins. Let them argue softly until they become something neither could be alone.",
		"tag": "accord_hint",
	},
	{
		"id": "note_sea_air",
		"text": "I have tried for years to capture the smell of the sea. Something mineral, something clean — an ingredient the ocean itself seems to hoard. Perhaps you will find it where I could not.",
		"tag": "atmosphere",
	},
	{
		"id": "note_bergamot_cedar",
		"text": "Bergamot alone is restless. Cedar alone is heavy. But together they settle into something almost architectural — a room you would want to live inside.",
		"tag": "accord_hint",
	},
	{
		"id": "note_balance",
		"text": "Never let one voice shout above the others. A blend is a conversation, not a sermon. The moment one ingredient dominates, the perfume is finished.",
		"tag": "wisdom",
	},
	{
		"id": "note_green_woods",
		"text": "After rain, the forest smells of peppermint and old wood. I never found a way to bottle that moment exactly. But every time I try, something good comes out anyway.",
		"tag": "accord_hint",
	},
	{
		"id": "note_mystery",
		"text": "Somewhere out there is a substance the old perfumers called grey gold. The sea makes it. It takes everything else and makes it last. I spent thirty years looking. Perhaps you will be luckier.",
		"tag": "atmosphere",
	},
]

# Tracks which note ids the player has already read (in order, no duplicates until all seen)
var _read_note_ids: Array[String] = []
# Which notes remain unseen this cycle
var _unseen_note_ids: Array[String] = []

# Results of the last wash-up roll, keyed by spot index (0, 1, 2)
# Each entry: { "type": "nothing"/"common"/"note"/"ambergris", "ingredient_path": String, "note": Dictionary }
var _current_washup: Array = []

func _ready() -> void:
	_load()
	_rebuild_unseen_pool()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Call this when the player enters the beach scene.
## Returns an Array of 3 Dictionaries (one per wash-up spot), each with:
##   { "type": String, "ingredient_path": String, "note": Dictionary }
## "type" is one of: "nothing", "common", "note", "ambergris"
func roll_washup() -> Array:
	_current_washup = []
	for i in range(3):
		_current_washup.append(_roll_single_spot())
	return _current_washup

## Returns the cached result from the last roll (so the scene can re-query without re-rolling).
func get_current_washup() -> Array:
	return _current_washup

## Mark a note as read. Saves state and emits signal.
func mark_note_read(note_id: String) -> void:
	if note_id not in _read_note_ids:
		_read_note_ids.append(note_id)
	_unseen_note_ids.erase(note_id)
	if _unseen_note_ids.is_empty():
		_rebuild_unseen_pool()
	_save()

## Returns all notes the player has ever found, in order of discovery.
func get_collected_notes() -> Array:
	var out: Array = []
	for note_id: String in _read_note_ids:
		for note in ALL_NOTES:
			if note["id"] == note_id:
				out.append(note)
				break
	return out

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _roll_single_spot() -> Dictionary:
	var roll: float = randf()
	if roll < PROB_NOTHING:
		return { "type": "nothing", "ingredient_path": "", "note": {} }
	elif roll < PROB_COMMON:
		var path: String = COMMON_FIND_PATHS[randi() % COMMON_FIND_PATHS.size()]
		return { "type": "common", "ingredient_path": path, "note": {} }
	elif roll < PROB_NOTE:
		var note: Dictionary = _pick_next_note()
		return { "type": "note", "ingredient_path": "", "note": note }
	else:
		return { "type": "ambergris", "ingredient_path": "", "note": {} }

func _pick_next_note() -> Dictionary:
	if _unseen_note_ids.is_empty():
		_rebuild_unseen_pool()
	var idx: int = randi() % _unseen_note_ids.size()
	var note_id: String = _unseen_note_ids[idx]
	for note in ALL_NOTES:
		if note["id"] == note_id:
			return note
	return ALL_NOTES[0]

func _rebuild_unseen_pool() -> void:
	_unseen_note_ids = []
	for note in ALL_NOTES:
		var note_id: String = note["id"]
		if note_id not in _read_note_ids:
			_unseen_note_ids.append(note_id)
	# If somehow everything is read, reset so cycle repeats
	if _unseen_note_ids.is_empty():
		for note in ALL_NOTES:
			_unseen_note_ids.append(note["id"])

# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

func _save() -> void:
	var data := {
		"version": SAVE_VERSION,
		"read_note_ids": _read_note_ids,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("BeachManager: Could not open save file for writing.")
		return
	file.store_string(JSON.stringify(data, "\t"))

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("BeachManager: Save file corrupt, starting fresh.")
		return
	var data = json.data
	if not data is Dictionary:
		return
	var ids = data.get("read_note_ids", [])
	_read_note_ids = []
	for id in ids:
		_read_note_ids.append(str(id))
