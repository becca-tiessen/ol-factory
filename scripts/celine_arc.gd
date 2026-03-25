class_name CelineArc
extends Npc

## Céline's arc-driven NPC controller. Extends the base Npc class and overrides
## _start_dialogue() to route through arc stages 0–5 instead of the standard
## intro/hint/idle system.
##
## Arc stage summary:
##   0 — First meeting (intro). Advances to 1 automatically.
##   1 — She mentions her hobby. Triggers when player has bottled >= 3 perfumes.
##   2 — Player shows her a Good+ perfume. She asks to see her bottle next time.
##   3 — She shows her bottle. Reveals her talent.
##   4 — The push. Triggers when player has an Excellent perfume AND >= 3 completed requests.
##        She decides to set up a stall. Starts the stall timer.
##   5 — Stall is open. Shop dialogue plays when she is present.

const NPC_ID := "celine"
## Seconds of play-time that must pass between Stage 4 and the stall appearing.
const STALL_DELAY_SECONDS := 240.0  # 4 minutes

## Emitted when the stall becomes ready to show in the scene.
signal stall_ready

var _stall_node: Node2D = null  # set by the courtyard scene


func _ready() -> void:
	super._ready()
	npc_id = NPC_ID
	# Find stall node by group after scene is fully loaded.
	call_deferred("_find_stall_node")
	set_process(true)


func _find_stall_node() -> void:
	var stalls: Array[Node] = get_tree().get_nodes_in_group("celine_stall")
	if not stalls.is_empty():
		set_stall_node(stalls[0] as Node2D)


func _process(delta: float) -> void:
	if NpcDialogueManager.get_arc_stage(NPC_ID) == 4 and not NpcDialogueManager.is_stall_placed(NPC_ID):
		var started: float = NpcDialogueManager.get_stall_timer_started(NPC_ID)
		if started >= 0.0 and CellarManager.play_time - started >= STALL_DELAY_SECONDS:
			NpcDialogueManager.set_stall_placed(NPC_ID, true)
			NpcDialogueManager.set_arc_stage(NPC_ID, 5)
			stall_ready.emit()
			_show_stall()


# ---------------------------------------------------------------------------
# Stall visibility
# ---------------------------------------------------------------------------

func set_stall_node(node: Node2D) -> void:
	_stall_node = node
	_refresh_stall_visibility()


func _refresh_stall_visibility() -> void:
	if _stall_node == null:
		return
	var stage: int = NpcDialogueManager.get_arc_stage(NPC_ID)
	_stall_node.visible = stage >= 5


func _show_stall() -> void:
	if _stall_node != null:
		_stall_node.visible = true


# ---------------------------------------------------------------------------
# Dialogue override
# ---------------------------------------------------------------------------

func _start_dialogue() -> void:
	if npc_id == "":
		push_warning("CelineArc: npc_id is not set.")
		return

	var stage: int = NpcDialogueManager.get_arc_stage(NPC_ID)
	var lines: Array[String] = []

	# Stage 0 — First meeting.
	if not NpcDialogueManager.has_met(NPC_ID):
		for line: String in NpcDialogueManager.get_intro_lines(NPC_ID):
			lines.append(line)
		_open_plain(lines)
		NpcDialogueManager.mark_met(NPC_ID)
		# Advance to stage 1 immediately after intro.
		NpcDialogueManager.set_arc_stage(NPC_ID, 1)
		return

	match stage:
		1:
			_dialogue_stage1()
		2:
			_dialogue_stage2()
		3:
			_dialogue_stage3()
		4:
			_dialogue_stage4()
		5:
			_dialogue_stage5()
		_:
			# Fallback idle.
			var idle: String = NpcDialogueManager.get_next_idle_line(NPC_ID)
			if idle != "":
				_open_plain([idle])


func _dialogue_stage1() -> void:
	# Trigger when player has bottled at least 3 perfumes total.
	var total_bottles: int = CellarManager.bottles.size() + CellarManager.aging_rack.size()
	# Also count displayed bottles if accessible.
	var has_enough: bool = total_bottles >= 3 or _count_ever_bottled() >= 3

	if has_enough:
		var lines: Array[String] = []
		for line: String in NpcDialogueManager.get_stage_lines(NPC_ID, "stage1"):
			lines.append(line)
		_open_plain(lines)
		NpcDialogueManager.set_arc_stage(NPC_ID, 2)
	else:
		# Still stage 1 but player hasn't bottled enough yet — idle lines.
		var idle_lines: Array = NpcDialogueManager.get_stage_lines(NPC_ID, "idle")
		if not idle_lines.is_empty():
			var line: String = NpcDialogueManager.get_next_idle_line(NPC_ID)
			if line == "":
				line = idle_lines[0]
			_open_plain([line])


func _dialogue_stage2() -> void:
	# Check if player is carrying a Good or Excellent perfume.
	var good_bottle: BottledPerfume = _find_good_bottle()
	if good_bottle != null:
		var lines: Array[String] = []
		for line: String in NpcDialogueManager.get_stage_lines(NPC_ID, "stage2_prompt"):
			lines.append(line)
		_open_plain(lines)
		NpcDialogueManager.set_arc_stage(NPC_ID, 3)
	else:
		# Player doesn't have a good perfume yet — stage1 idle lines.
		var idle_lines: Array = NpcDialogueManager.get_stage_lines(NPC_ID, "stage1_idle")
		if not idle_lines.is_empty():
			var line: String = NpcDialogueManager.get_next_idle_line(NPC_ID)
			if line == "":
				line = idle_lines[0]
			_open_plain([line])


func _dialogue_stage3() -> void:
	var lines: Array[String] = []
	for line: String in NpcDialogueManager.get_stage_lines(NPC_ID, "stage3"):
		lines.append(line)
	_open_plain(lines)
	NpcDialogueManager.set_arc_stage(NPC_ID, 4)


func _dialogue_stage4() -> void:
	# Trigger when player has an Excellent perfume AND >= 3 completed requests.
	var has_excellent: bool = _has_excellent_perfume()
	var completed_count: int = RequestManager._completed_ids.size()

	if has_excellent and completed_count >= 3:
		var lines: Array[String] = []
		for line: String in NpcDialogueManager.get_stage_lines(NPC_ID, "stage4"):
			lines.append(line)
		_open_plain(lines)
		# Start the stall timer.
		NpcDialogueManager.set_stall_timer_started(NPC_ID, CellarManager.play_time)
	else:
		# Not yet — stage3 idle (reuse stage1_idle).
		var idle_lines: Array = NpcDialogueManager.get_stage_lines(NPC_ID, "stage1_idle")
		if not idle_lines.is_empty():
			_open_plain([idle_lines[0]])


func _dialogue_stage5() -> void:
	# 60% chance she's present at the stall; otherwise use absent idle lines.
	var is_present: bool = (randi() % 100) < 60
	if is_present:
		var lines: Array[String] = []
		for line: String in NpcDialogueManager.get_stage_lines(NPC_ID, "stage5_present"):
			lines.append(line)
		# Append shop prompt hint.
		lines.append("She gestures toward the small table beside her.")
		_open_plain(lines)
	else:
		var idle_lines: Array = NpcDialogueManager.get_stage_lines(NPC_ID, "stage5_absent_idle")
		if not idle_lines.is_empty():
			var line: String = idle_lines[randi() % idle_lines.size()]
			_open_plain([line])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Counts total perfumes the player has ever created (bottles + rack + progression receipts).
func _count_ever_bottled() -> int:
	# ProgressionManager._bottled_recipes tracks unique recipes ever bottled.
	return ProgressionManager._bottled_recipes.size()


func _find_good_bottle() -> BottledPerfume:
	for bottle: BottledPerfume in CellarManager.bottles:
		if bottle.tier == "Good" or bottle.tier == "Excellent":
			return bottle
	return null


func _has_excellent_perfume() -> bool:
	for bottle: BottledPerfume in CellarManager.bottles:
		if bottle.tier == "Excellent":
			return true
	# Also check aging rack.
	for entry in CellarManager.aging_rack:
		var bottle: BottledPerfume = entry.get("bottle")
		if bottle != null and bottle.tier == "Excellent":
			return true
	return false


func _open_plain(lines: Array[String]) -> void:
	if lines.is_empty():
		return
	var dialogue_scene := load("res://scenes/dialogue_box.tscn")
	if dialogue_scene == null:
		push_warning("CelineArc: Could not load dialogue box scene.")
		return
	_dialogue_box = dialogue_scene.instantiate() as DialogueBox
	if _dialogue_box == null:
		return
	get_tree().root.add_child(_dialogue_box)
	_dialogue_box.dialogue_closed.connect(_on_dialogue_closed)
	_dialogue_box.open(npc_display_name, lines)
