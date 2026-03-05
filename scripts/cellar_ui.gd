extends BaseInteractableUI

## Cellar aging rack UI.
## Top section: rack slots showing aging bottles with visual BeakerDisplay.
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
		card.custom_minimum_size = Vector2(140, 0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)

		if i < CellarManager.aging_rack.size():
			var entry: Dictionary = CellarManager.aging_rack[i]
			var bottle: BottledPerfume = entry["bottle"]
			var bonus := CellarManager.get_age_bonus(i)
			var ready := CellarManager.is_ready(i)
			var progress := clampf(bonus / CellarManager.AGE_CAP, 0.0, 1.0)

			# Bottle beaker visualization
			var beaker := BeakerDisplay.new()
			beaker.custom_minimum_size = Vector2(50, 70)
			beaker.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			beaker.fill_ratio = lerpf(0.45, 0.70, progress)
			_apply_bottle_layers(beaker, bottle, progress)
			vbox.add_child(beaker)

			# Ready sparkle indicator
			if ready:
				var sparkle := Label.new()
				sparkle.text = "~ Ready ~"
				sparkle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				sparkle.add_theme_color_override("font_color", UITheme.SOFT_GREEN)
				sparkle.add_theme_font_size_override("font_size", 11)
				vbox.add_child(sparkle)

			# Perfume name
			var name_lbl := Label.new()
			var pname: String = bottle.display_name if bottle.display_name != "" else bottle.get_label()
			name_lbl.text = pname
			name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_lbl.add_theme_color_override("font_color", UITheme.HEADER_BROWN)
			name_lbl.add_theme_font_size_override("font_size", 13)
			vbox.add_child(name_lbl)

			# Quality tier
			var tier_lbl := Label.new()
			tier_lbl.text = "%s — %.1f" % [bottle.tier, bottle.base_quality]
			tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tier_lbl.add_theme_color_override("font_color", UITheme.WARM_AMBER)
			tier_lbl.add_theme_font_size_override("font_size", 12)
			vbox.add_child(tier_lbl)

			# Age progress
			var age_lbl := Label.new()
			age_lbl.text = "+%.2f / %.1f" % [bonus, CellarManager.AGE_CAP]
			age_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			age_lbl.add_theme_font_size_override("font_size", 11)
			if ready:
				age_lbl.add_theme_color_override("font_color", UITheme.SOFT_GREEN)
			else:
				age_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
			vbox.add_child(age_lbl)

			# Retrieve button
			var retrieve_btn := Button.new()
			retrieve_btn.text = "Retrieve"
			retrieve_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			var idx := i
			retrieve_btn.pressed.connect(func(): _on_retrieve(idx))
			vbox.add_child(retrieve_btn)

			# Tooltip on hover
			card.tooltip_text = _build_tooltip(bottle, bonus, ready)
		else:
			var empty_lbl := Label.new()
			empty_lbl.text = "[ Empty ]"
			empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
			vbox.add_child(empty_lbl)

		%RackSlots.add_child(card)


## Apply layered ingredient colors to a beaker, with aging tint shift.
func _apply_bottle_layers(beaker: BeakerDisplay, bottle: BottledPerfume, progress: float) -> void:
	if bottle.blend_summary.is_empty():
		return
	var total := 0
	for entry in bottle.blend_summary:
		total += int(entry["amount"])
	if total == 0:
		return

	# Slight brown tint as aging progresses (richer color)
	var age_tint := Color("6B4226")
	var tint_strength := progress * 0.15

	var layers: Array = []
	for entry in bottle.blend_summary:
		var frac := float(entry["amount"]) / float(total)
		var col := BeakerDisplay.color_for_ingredient(entry["name"])
		col = col.lerp(age_tint, tint_strength)
		layers.append({ "color": col, "fraction": frac })
	beaker.layers = layers

	# Fallback liquid_color to the dominant ingredient
	var best_entry = bottle.blend_summary[0]
	for entry in bottle.blend_summary:
		if int(entry["amount"]) > int(best_entry["amount"]):
			best_entry = entry
	var dominant_col := BeakerDisplay.color_for_ingredient(best_entry["name"])
	beaker.liquid_color = dominant_col.lerp(age_tint, tint_strength)


## Build a tooltip string with perfume details.
func _build_tooltip(bottle: BottledPerfume, bonus: float, ready: bool) -> String:
	var lines: Array[String] = []
	var pname: String = bottle.display_name if bottle.display_name != "" else "Unnamed Perfume"
	lines.append(pname)
	lines.append("Blend: %s" % bottle.get_label())
	lines.append("Base quality: %.1f (%s)" % [bottle.base_quality, bottle.tier])
	lines.append("Age bonus: +%.2f / %.1f" % [bonus, CellarManager.AGE_CAP])
	if ready:
		lines.append("Fully aged and ready to retrieve!")
	else:
		var pct := int(bonus / CellarManager.AGE_CAP * 100.0)
		lines.append("Aging... %d%% complete" % pct)
	return "\n".join(lines)


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
