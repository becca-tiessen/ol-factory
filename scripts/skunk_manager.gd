extends Node

## Autoload that keeps the skunk companion alive across scene transitions.
## The skunk instance is re-parented into each new scene.

var _skunk_scene: PackedScene = preload("res://scenes/skunk.tscn")
var _skunk: CharacterBody2D = null

func _ready() -> void:
	get_tree().tree_changed.connect(_on_tree_changed)
	# Defer initial spawn to let the first scene load
	call_deferred("_ensure_skunk")

func _on_tree_changed() -> void:
	call_deferred("_ensure_skunk")

func _ensure_skunk() -> void:
	var current: Node = get_tree().current_scene
	if not current:
		return

	# Check if skunk already lives in this scene
	if _skunk and is_instance_valid(_skunk) and _skunk.is_inside_tree():
		if _skunk.get_parent() == current:
			return
		# Remove from old parent before re-adding
		_skunk.get_parent().remove_child(_skunk)

	if not _skunk or not is_instance_valid(_skunk):
		_skunk = _skunk_scene.instantiate() as CharacterBody2D

	current.add_child(_skunk)
	_skunk.spawn_near_player()
