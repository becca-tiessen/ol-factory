extends BaseInteractable

func _ready() -> void:
	_ui_scene_path = "res://scenes/mixing_bench_ui.tscn"

	# Add MixingManager as a child node so it persists
	if get_node_or_null("MixingManager") == null:
		var mixing_manager = MixingManager.new()
		add_child(mixing_manager)
		mixing_manager.name = "MixingManager"

	super()
