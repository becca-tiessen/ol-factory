class_name Npc
extends Area2D

## A stationary NPC the player can talk to by pressing E while nearby.
## Attach to an Area2D node. Requires a child CollisionShape2D.
## Collision layer 4, mask 1 (detects Player CharacterBody2D on layer 1).

@export var npc_id: String = ""
@export var npc_display_name: String = ""

## Optional: sprite sheet texture override. If blank, uses the default npc sprite.
@export var sprite_texture: Texture2D = null
## Region rect within the sprite sheet (x, y, width, height). Only used if sprite_texture is set.
@export var sprite_region: Rect2 = Rect2(0, 0, 16, 32)

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _name_label: Label = $NameLabel

var _player_nearby: bool = false
var _dialogue_box: DialogueBox = null

const DIALOGUE_BOX_SCENE := "res://scenes/dialogue_box.tscn"


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if sprite_texture != null:
		var atlas := AtlasTexture.new()
		atlas.atlas = sprite_texture
		atlas.region = sprite_region
		_sprite.texture = atlas

	_name_label.text = npc_display_name
	_name_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and event.is_action_pressed("interact"):
		if BaseInteractableUI.open_count == 0:
			_start_dialogue()
			get_tree().root.set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		_player_nearby = true
		_name_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		_player_nearby = false
		_name_label.visible = false


func _start_dialogue() -> void:
	if npc_id == "":
		push_warning("Npc: npc_id is not set.")
		return

	# Build the dialogue sequence to show.
	var lines: Array[String] = []
	var mode: String = "idle"

	# Priority 1: intro (first meeting)
	if not NpcDialogueManager.has_met(npc_id):
		for line: String in NpcDialogueManager.get_intro_lines(npc_id):
			lines.append(line)
		mode = "intro"

	# Priority 2 & 3: request-related
	elif RequestManager.active_request != null and RequestManager.active_request.npc_id == npc_id:
		var matching_bottle := _find_matching_bottle()
		if matching_bottle != null:
			# Priority 2: player has a matching bottle — offer delivery
			mode = "delivery"
			var bottle_label: String = matching_bottle.display_name if matching_bottle.display_name != "" else matching_bottle.get_label()
			var prompt: String = NpcDialogueManager.get_delivery_prompt(
				npc_id,
				bottle_label,
				npc_display_name
			)
			lines.append(prompt)
		else:
			# Priority 3: hint about the request
			var hint: String = NpcDialogueManager.get_request_hint(npc_id)
			if hint != "":
				lines.append(hint)
				mode = "hint"
			else:
				lines.append(NpcDialogueManager.get_next_idle_line(npc_id))
				mode = "idle"

	# Priority 4: idle chatter
	else:
		var idle_line: String = NpcDialogueManager.get_next_idle_line(npc_id)
		if idle_line != "":
			lines.append(idle_line)
		mode = "idle"

	if lines.is_empty():
		return

	# Instantiate dialogue box
	var dialogue_scene := load(DIALOGUE_BOX_SCENE)
	if dialogue_scene == null:
		push_warning("Npc: Could not load dialogue box scene.")
		return

	_dialogue_box = dialogue_scene.instantiate() as DialogueBox
	if _dialogue_box == null:
		push_warning("Npc: dialogue_box scene did not instantiate as DialogueBox.")
		return
	get_tree().root.add_child(_dialogue_box)

	# Connect signals before opening
	_dialogue_box.dialogue_closed.connect(_on_dialogue_closed)
	if mode == "delivery":
		_dialogue_box.delivery_confirmed.connect(_on_delivery_confirmed)
		_dialogue_box.open_delivery(npc_display_name, lines, _find_matching_bottle())
	else:
		_dialogue_box.open(npc_display_name, lines)

	if mode == "intro":
		NpcDialogueManager.mark_met(npc_id)


func _find_matching_bottle() -> BottledPerfume:
	if RequestManager.active_request == null:
		return null
	for bottle: BottledPerfume in CellarManager.bottles:
		if bottle.matches_request(RequestManager.active_request):
			return bottle
	return null


func _on_dialogue_closed() -> void:
	if _dialogue_box != null:
		_dialogue_box.queue_free()
		_dialogue_box = null


func _on_delivery_confirmed(bottle: BottledPerfume) -> void:
	var result: Dictionary = RequestManager.deliver_request(bottle)
	if result.get("success", false):
		CellarManager.remove_bottle(bottle)
		var success_line: String = NpcDialogueManager.get_delivery_success(npc_id)
		if _dialogue_box != null:
			_dialogue_box.show_response(success_line)
	else:
		var fail_line: String = NpcDialogueManager.get_delivery_fail(npc_id)
		if _dialogue_box != null:
			_dialogue_box.show_response(fail_line)
