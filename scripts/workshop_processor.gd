extends BaseInteractable

## The player's own processing equipment, unlocked at Apprentice rank.
## Faster than Margot (30s vs 60s) and free to use.

func _ready() -> void:
	_ui_scene_path = "res://scenes/workshop_processor_ui.tscn"
	super()
	ProcessingManager.queue_changed.connect(_update_indicator)
	ProcessingManager.oils_ready.connect(_update_indicator)
	_update_indicator()


func _update_indicator() -> void:
	var indicator := get_node_or_null("ReadyIndicator")
	if indicator:
		var ready := ProcessingManager.get_ready_oils_filtered(true)
		indicator.visible = not ready.is_empty()
