extends Area2D

## A door that requires a minimum rank to open.
## When locked, touching it shows a floating hint. When unlocked, behaves
## like a normal door (transitions to target_scene via SceneManager).

@export_file("*.tscn") var target_scene: String
@export var spawn_marker_name: String = "SpawnPoint"
@export var required_rank: String = "Apprentice"

var _locked := true


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_update_lock_state()
	ProgressionManager.rank_up.connect(_on_rank_up)


func _update_lock_state() -> void:
	_locked = not ProgressionManager.has_rank(required_rank)
	if has_node("Sprite2D"):
		var sprite := get_node("Sprite2D") as Sprite2D
		sprite.modulate = Color(0.5, 0.5, 0.5, 0.7) if _locked else Color.WHITE


func _on_rank_up(_old: String, _new: String) -> void:
	_update_lock_state()


func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return
	if _locked:
		_show_locked_message()
		return
	if target_scene == "":
		return
	SceneManager.spawn_marker_name = spawn_marker_name
	SceneManager.transition_to_scene(target_scene)


func _show_locked_message() -> void:
	var label := Label.new()
	label.text = "Locked — keep honing your craft."
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	label.position = global_position + Vector2(-80, -40)
	get_tree().root.add_child(label)

	var tween := get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 25.0, 1.5)
	tween.tween_property(label, "modulate:a", 0.0, 1.5)
	tween.chain().tween_callback(label.queue_free)
