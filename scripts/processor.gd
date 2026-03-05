extends BaseInteractable

## Marguerite the travelling processor — stands outside the lab.
## Shows a "!" indicator when finished oils are ready to collect.

func _ready() -> void:
	_ui_scene_path = "res://scenes/processor_ui.tscn"
	super()
	ProcessingManager.queue_changed.connect(_update_indicator)
	ProcessingManager.oils_ready.connect(_update_indicator)
	_update_indicator()


func _update_indicator() -> void:
	var indicator := get_node_or_null("ReadyIndicator")
	if indicator:
		indicator.visible = ProcessingManager.has_ready_oils()
