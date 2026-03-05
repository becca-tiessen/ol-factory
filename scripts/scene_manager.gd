extends Node

# Name of the Marker2D to spawn at in the next scene
var spawn_marker_name: String = ""

var _overlay: ColorRect
var _is_transitioning: bool = false

const FADE_DURATION: float = 0.35

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	# CanvasLayer needs a Control child to anchor against
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(anchor)

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor.add_child(_overlay)

func transition_to_scene(target_scene: String) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	# Freeze the game tree so the player stops moving during fade
	get_tree().paused = true

	# Fade to black
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_overlay, "color:a", 1.0, FADE_DURATION)
	await tween.finished

	# Unpause before changing scene so change_scene_to_file works normally
	get_tree().paused = false

	# Change scene and wait for it to actually load
	get_tree().change_scene_to_file(target_scene)
	await get_tree().tree_changed
	await get_tree().process_frame

	# Fade back in
	var tween_in := create_tween()
	tween_in.tween_property(_overlay, "color:a", 0.0, FADE_DURATION)
	await tween_in.finished

	_is_transitioning = false
