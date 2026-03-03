class_name BaseInteractable
extends StaticBody2D

signal opened

var player_in_range := false
var _ui_instance: CanvasLayer = null
var is_open := false

# Override this in subclasses
var _ui_scene_path: String = ""

func _ready() -> void:
	var interaction_area = get_node_or_null("InteractionArea")
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and not is_open and event.is_action_pressed("interact"):
		_open_ui()

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_in_range = true

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_in_range = false

func _open_ui() -> void:
	is_open = true
	opened.emit()

	if _ui_instance == null:
		_ui_instance = load(_ui_scene_path).instantiate()
		get_tree().root.add_child(_ui_instance)
		_ui_instance.closed.connect(_on_ui_closed)

	_ui_instance.open()

func _on_ui_closed() -> void:
	is_open = false
