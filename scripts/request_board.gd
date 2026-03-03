extends BaseInteractable

func _ready() -> void:
	_ui_scene_path = "res://scenes/request_board_ui.tscn"
	super()
	RequestManager.request_changed.connect(_update_indicator)
	_update_indicator()


func _open_ui() -> void:
	RequestManager.mark_seen()
	_update_indicator()
	super()


func _update_indicator() -> void:
	var indicator := get_node_or_null("Indicator")
	if indicator:
		indicator.visible = RequestManager.is_unseen()
