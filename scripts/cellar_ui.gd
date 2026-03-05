extends BaseInteractableUI

## Cellar aging rack UI.
## Top section: rack slots showing aging bottles.
## Bottom section: bottle inventory with "Place on Rack" buttons.
## Retrieved bottles go straight to inventory. Delivery is handled at the request board.

func _ready() -> void:
	super()
	CellarManager.bottles_changed.connect(_refresh_all)
	CellarManager.rack_changed.connect(_refresh_all)


func open() -> void:
	_refresh_all()
	super()


func _refresh_all() -> void:
	_refresh_rack()
	_refresh_bottles()


# ---------------------------------------------------------------------------
# Aging rack display
# ---------------------------------------------------------------------------

func _refresh_rack() -> void:
	for child in %RackSlots.get_children():
		child.queue_free()

	for i in range(CellarManager.get_rack_slots()):
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(160, 0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var vbox := VBoxContainer.new()
		card.add_child(vbox)

		if i < CellarManager.aging_rack.size():
			var entry: Dictionary = CellarManager.aging_rack[i]
			var bottle: BottledPerfume = entry["bottle"]
			var bonus := CellarManager.get_age_bonus(i)
			var ready := CellarManager.is_ready(i)

			var name_lbl := Label.new()
			name_lbl.text = bottle.get_label()
			name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			vbox.add_child(name_lbl)

			var quality_lbl := Label.new()
			quality_lbl.text = "Base: %.1f" % bottle.base_quality
			vbox.add_child(quality_lbl)

			var age_lbl := Label.new()
			age_lbl.text = "Age bonus: +%.2f / %.1f" % [bonus, CellarManager.AGE_CAP]
			if ready:
				age_lbl.add_theme_color_override("font_color", UITheme.SOFT_GREEN)
			vbox.add_child(age_lbl)

			if ready:
				var ready_lbl := Label.new()
				ready_lbl.text = "Ready!"
				ready_lbl.add_theme_color_override("font_color", UITheme.SOFT_GREEN)
				vbox.add_child(ready_lbl)

			var retrieve_btn := Button.new()
			retrieve_btn.text = "Retrieve"
			var idx := i
			retrieve_btn.pressed.connect(func(): _on_retrieve(idx))
			vbox.add_child(retrieve_btn)
		else:
			var empty_lbl := Label.new()
			empty_lbl.text = "[ Empty ]"
			empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
			vbox.add_child(empty_lbl)

		%RackSlots.add_child(card)


# ---------------------------------------------------------------------------
# Bottle inventory (bottles not on rack)
# ---------------------------------------------------------------------------

func _refresh_bottles() -> void:
	for child in %BottleList.get_children():
		child.queue_free()

	if CellarManager.bottles.is_empty():
		var lbl := Label.new()
		lbl.text = "(no bottles)"
		lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		%BottleList.add_child(lbl)
		return

	for bottle in CellarManager.bottles:
		var hbox := HBoxContainer.new()

		var info := Label.new()
		info.text = "%s  [%s, %.1f]" % [bottle.get_label(), bottle.tier, bottle.base_quality]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.clip_text = true
		hbox.add_child(info)

		if bottle.aged:
			var aged_lbl := Label.new()
			aged_lbl.text = "(aged +%.2f)" % bottle.age_bonus
			aged_lbl.add_theme_color_override("font_color", UITheme.SOFT_GREEN)
			hbox.add_child(aged_lbl)

		var place_btn := Button.new()
		if bottle.aged:
			place_btn.text = "Already aged"
			place_btn.disabled = true
		elif CellarManager.rack_has_space():
			place_btn.text = "Place on Rack"
			var b := bottle
			place_btn.pressed.connect(func(): _on_place(b))
		else:
			place_btn.text = "Rack Full"
			place_btn.disabled = true
		hbox.add_child(place_btn)

		%BottleList.add_child(hbox)


# ---------------------------------------------------------------------------
# Retrieve
# ---------------------------------------------------------------------------

func _on_place(bottle: BottledPerfume) -> void:
	CellarManager.place_on_rack(bottle)


func _on_retrieve(rack_index: int) -> void:
	var bottle := CellarManager.retrieve_from_rack(rack_index)
	if bottle == null:
		return
	CellarManager.add_bottle(bottle)


# ---------------------------------------------------------------------------
# Periodic refresh for aging display (every 5 seconds)
# ---------------------------------------------------------------------------

var _refresh_timer: float = 0.0

func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer >= 5.0:
		_refresh_timer = 0.0
		var panel = get_node_or_null("Panel")
		if panel and panel.visible:
			_refresh_rack()
