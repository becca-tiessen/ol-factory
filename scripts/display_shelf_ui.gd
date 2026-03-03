extends BaseInteractableUI

## Display shelf UI. Shows trophied perfumes and lets the player place or remove bottles.

func _ready() -> void:
	super()
	CellarManager.bottles_changed.connect(_refresh_all)
	CellarManager.display_changed.connect(_refresh_all)


func open() -> void:
	_refresh_all()
	super()


func _refresh_all() -> void:
	_refresh_displayed()
	_refresh_inventory()


# ---------------------------------------------------------------------------
# Displayed perfumes (trophies)
# ---------------------------------------------------------------------------

func _refresh_displayed() -> void:
	for child in %DisplayedList.get_children():
		child.queue_free()

	if CellarManager.displayed_bottles.is_empty():
		var lbl := Label.new()
		lbl.text = "No perfumes on display yet."
		lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		%DisplayedList.add_child(lbl)
		return

	for bottle in CellarManager.displayed_bottles:
		var card := PanelContainer.new()
		var hbox := HBoxContainer.new()
		card.add_child(hbox)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_lbl := Label.new()
		name_lbl.text = bottle.get_label()
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(name_lbl)

		var summary_lbl := Label.new()
		var families := {}
		var notes := {}
		for entry in bottle.blend_summary:
			families[entry["family"]] = families.get(entry["family"], 0) + int(entry["amount"])
			notes[entry["note"]] = notes.get(entry["note"], 0) + int(entry["amount"])
		var family_parts: Array[String] = []
		for f: String in families:
			family_parts.append("%s x%d" % [f, families[f]])
		summary_lbl.text = "Families: " + ", ".join(family_parts)
		summary_lbl.add_theme_color_override("font_color", UITheme.SOFT_BLUE)
		info.add_child(summary_lbl)

		var quality_lbl := Label.new()
		quality_lbl.text = "%s — Quality: %.1f" % [bottle.get_final_tier(), bottle.get_final_quality()]
		if bottle.aged:
			quality_lbl.text += " (aged +%.2f)" % bottle.age_bonus
		quality_lbl.add_theme_color_override("font_color", UITheme.WARM_AMBER)
		info.add_child(quality_lbl)

		hbox.add_child(info)

		var remove_btn := Button.new()
		remove_btn.text = "Remove"
		remove_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var b := bottle
		remove_btn.pressed.connect(func(): _on_remove(b))
		hbox.add_child(remove_btn)

		%DisplayedList.add_child(card)


# ---------------------------------------------------------------------------
# Bottles available to place on shelf
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

	for bottle in CellarManager.bottles:
		var hbox := HBoxContainer.new()

		var info := Label.new()
		info.text = "%s  [%s, %.1f]" % [bottle.get_label(), bottle.get_final_tier(), bottle.get_final_quality()]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.clip_text = true
		hbox.add_child(info)

		var display_btn := Button.new()
		display_btn.text = "Display"
		var b := bottle
		display_btn.pressed.connect(func(): _on_display(b))
		hbox.add_child(display_btn)

		%InventoryList.add_child(hbox)


func _on_display(bottle: BottledPerfume) -> void:
	CellarManager.display_bottle(bottle)


func _on_remove(bottle: BottledPerfume) -> void:
	CellarManager.undisplay_bottle(bottle)
