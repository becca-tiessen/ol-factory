extends BaseInteractable

## Margot the travelling processor — stands outside the lab.
## Shows a "!" indicator when finished oils are ready to collect.
## Auto-opens her intro dialogue the first time the player arrives after
## signing the contract.

func _ready() -> void:
	_ui_scene_path = "res://scenes/processor_ui.tscn"
	super()
	ProcessingManager.queue_changed.connect(_update_indicator)
	ProcessingManager.oils_ready.connect(_update_indicator)
	_update_indicator()

	# If the player just signed the contract and hasn't met Margot yet,
	# auto-trigger her intro dialogue after a short exploration beat.
	if not ProcessingManager.has_met_processor and GameStartManager.has_signed_contract:
		_auto_open_intro.call_deferred()


func _auto_open_intro() -> void:
	await get_tree().create_timer(1.2).timeout
	_open_ui()


func _update_indicator() -> void:
	var indicator := get_node_or_null("ReadyIndicator")
	if indicator:
		indicator.visible = ProcessingManager.has_ready_oils()
