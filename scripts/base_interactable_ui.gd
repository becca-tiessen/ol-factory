class_name BaseInteractableUI
extends CanvasLayer

signal closed


func _ready() -> void:
	var panel = get_node_or_null("Panel")
	if panel:
		panel.hide()
		var close_button = panel.get_node_or_null("VBoxContainer/CloseButton")
		if close_button:
			close_button.pressed.connect(_on_close_button_pressed)
	_apply_workshop_theme()


func _unhandled_input(event: InputEvent) -> void:
	var panel = get_node_or_null("Panel")
	if panel and panel.visible and event.is_action_pressed("interact"):
		_close_ui()


func open() -> void:
	var panel = get_node_or_null("Panel")
	if panel:
		panel.show()
	get_tree().root.set_input_as_handled()


func _close_ui() -> void:
	var panel = get_node_or_null("Panel")
	if panel:
		panel.hide()
	closed.emit()
	get_tree().root.set_input_as_handled()


func _on_close_button_pressed() -> void:
	_close_ui()


# ---------------------------------------------------------------------------
# Workshop theme — applied automatically to every UI panel
# ---------------------------------------------------------------------------

func _apply_workshop_theme() -> void:
	var panel = get_node_or_null("Panel")
	if panel == null:
		return

	# Parchment background with warm brown border
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_bg())

	# Propagate warm colors to all children via Theme
	panel.theme = UITheme.create_workshop_theme()

	# Generous spacing
	var vbox = panel.get_node_or_null("VBoxContainer")
	if vbox:
		vbox.offset_left = 20
		vbox.offset_top = 16
		vbox.offset_right = -20
		vbox.offset_bottom = -16
		vbox.add_theme_constant_override("separation", 8)

	# Auto-style any "-- Title --" pattern labels as headers/section titles
	_style_dashed_labels(panel)


func _style_dashed_labels(node: Node) -> void:
	if node is Label:
		var lbl := node as Label
		if lbl.text.begins_with("-- ") and lbl.text.ends_with(" --"):
			var clean := lbl.text.trim_prefix("-- ").trim_suffix(" --")
			lbl.text = clean
			# The top-level Title node gets the large header style
			if lbl.name == "Title":
				UITheme.style_header(lbl)
			else:
				UITheme.style_section_title(lbl)
	for child in node.get_children():
		_style_dashed_labels(child)
