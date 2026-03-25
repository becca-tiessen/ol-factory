extends BaseInteractableUI

## Display shelf UI. Shows trophied perfumes as colored bottles on a visual shelf.
## Includes naming prompt when placing a perfume, and a curated trophy view.

const MAX_DISPLAY_SLOTS := 6

var _pending_bottle: BottledPerfume = null


func _ready() -> void:
	super()
	CellarManager.bottles_changed.connect(_refresh_all)
	CellarManager.display_changed.connect(_refresh_all)
	%ConfirmNameButton.pressed.connect(_on_confirm_name)
	%SkipButton.pressed.connect(_on_skip_name)
	%NameInput.text_submitted.connect(func(_t: String): _on_confirm_name())


func open() -> void:
	_refresh_all()
	_hide_naming_overlay()
	super()


func _refresh_all() -> void:
	_refresh_displayed()
	_refresh_inventory()


# ---------------------------------------------------------------------------
# Trophy display — visual bottles with names
# ---------------------------------------------------------------------------

func _refresh_displayed() -> void:
	for child in %DisplayedGrid.get_children():
		child.queue_free()

	if CellarManager.displayed_bottles.is_empty():
		var lbl := Label.new()
		lbl.text = "Your display shelf is empty.\nPlace a perfume to show it off!"
		lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		%DisplayedGrid.add_child(lbl)
		return

	for bottle in CellarManager.displayed_bottles:
		var slot := _create_display_slot(bottle)
		%DisplayedGrid.add_child(slot)


func _create_display_slot(bottle: BottledPerfume) -> VBoxContainer:
	var slot := VBoxContainer.new()
	slot.custom_minimum_size = Vector2(110, 0)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_theme_constant_override("separation", 4)

	# Beaker with blended color layers
	var beaker := BeakerDisplay.new()
	beaker.custom_minimum_size = Vector2(50, 70)
	beaker.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	beaker.fill_ratio = 0.65
	_apply_bottle_layers(beaker, bottle)
	slot.add_child(beaker)

	# Perfume name
	var name_lbl := Label.new()
	var pname := bottle.display_name if bottle.display_name != "" else "Unnamed Perfume"
	name_lbl.text = pname
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_color_override("font_color", UITheme.HEADER_BROWN)
	name_lbl.add_theme_font_size_override("font_size", 14)
	slot.add_child(name_lbl)

	# Quality tier
	var tier_lbl := Label.new()
	tier_lbl.text = "%s — %.1f" % [bottle.get_final_tier(), bottle.get_final_quality()]
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_lbl.add_theme_color_override("font_color", UITheme.WARM_AMBER)
	tier_lbl.add_theme_font_size_override("font_size", 12)
	slot.add_child(tier_lbl)

	# Description
	if bottle.description != "":
		var desc_lbl := Label.new()
		desc_lbl.text = bottle.description
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.custom_minimum_size.x = 100
		slot.add_child(desc_lbl)

	# Aged indicator
	if bottle.aged:
		var aged_lbl := Label.new()
		aged_lbl.text = "Aged"
		aged_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		aged_lbl.add_theme_color_override("font_color", UITheme.SOFT_GREEN)
		aged_lbl.add_theme_font_size_override("font_size", 11)
		slot.add_child(aged_lbl)

	# Remove button
	var remove_btn := Button.new()
	remove_btn.text = "Remove"
	remove_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var b := bottle
	remove_btn.pressed.connect(func(): _on_remove(b))
	slot.add_child(remove_btn)

	return slot


func _apply_bottle_layers(beaker: BeakerDisplay, bottle: BottledPerfume) -> void:
	if bottle.blend_summary.is_empty():
		return
	var total := 0
	for entry in bottle.blend_summary:
		total += int(entry["amount"])
	if total == 0:
		return
	var layers: Array = []
	for entry in bottle.blend_summary:
		var frac := float(entry["amount"]) / float(total)
		var col := BeakerDisplay.color_for_ingredient(entry["name"])
		layers.append({ "color": col, "fraction": frac })
	beaker.layers = layers
	# Also set fallback liquid_color to the dominant ingredient color
	var best_entry = bottle.blend_summary[0]
	for entry in bottle.blend_summary:
		if int(entry["amount"]) > int(best_entry["amount"]):
			best_entry = entry
	beaker.liquid_color = BeakerDisplay.color_for_ingredient(best_entry["name"])


# ---------------------------------------------------------------------------
# Naming overlay
# ---------------------------------------------------------------------------

func _show_naming_overlay() -> void:
	%NamingOverlay.show()
	%NameInput.text = ""
	%NameInput.grab_focus()


func _hide_naming_overlay() -> void:
	%NamingOverlay.hide()
	_pending_bottle = null


func _on_confirm_name() -> void:
	if _pending_bottle == null:
		_hide_naming_overlay()
		return
	var custom_name: String = %NameInput.text.strip_edges()
	CellarManager.display_bottle(_pending_bottle, custom_name)
	_hide_naming_overlay()


func _on_skip_name() -> void:
	if _pending_bottle == null:
		_hide_naming_overlay()
		return
	CellarManager.display_bottle(_pending_bottle, "")
	_hide_naming_overlay()


# ---------------------------------------------------------------------------
# Inventory — bottles available to place
# ---------------------------------------------------------------------------

func _refresh_inventory() -> void:
	for child in %InventoryList.get_children():
		child.queue_free()

	if CellarManager.bottles.is_empty():
		var lbl := Label.new()
		lbl.text = "(no bottles in inventory)"
		lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		%InventoryList.add_child(lbl)
		return

	var can_display := CellarManager.displayed_bottles.size() < MAX_DISPLAY_SLOTS

	for bottle in CellarManager.bottles:
		var hbox := HBoxContainer.new()

		var info := Label.new()
		info.text = "%s  [%s, %.1f]" % [bottle.get_label(), bottle.get_final_tier(), bottle.get_final_quality()]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.clip_text = true
		hbox.add_child(info)

		var display_btn := Button.new()
		if can_display:
			display_btn.text = "Display"
			var b := bottle
			display_btn.pressed.connect(func(): _on_display(b))
		else:
			display_btn.text = "Shelf Full"
			display_btn.disabled = true
		hbox.add_child(display_btn)

		%InventoryList.add_child(hbox)


func _on_display(bottle: BottledPerfume) -> void:
	_pending_bottle = bottle
	_show_naming_overlay()


func _on_remove(bottle: BottledPerfume) -> void:
	CellarManager.undisplay_bottle(bottle)


# ---------------------------------------------------------------------------
# Block closing while naming overlay is open
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if %NamingOverlay.visible:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
			_hide_naming_overlay()
			get_tree().root.set_input_as_handled()
		return
	super(event)
