extends CanvasLayer

## Global inventory screen opened with Tab from anywhere.
## Shows gathered ingredients and carried perfumes (view-only).

var is_open := false

@onready var panel: Panel = %Panel


func _ready() -> void:
	layer = 10
	panel.hide()
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_bg())
	panel.theme = UITheme.create_workshop_theme()

	# Style the title.
	UITheme.style_header(%Title)

	# Style section headers.
	UITheme.style_section_title(%IngredientsHeader)
	UITheme.style_section_title(%PerfumesHeader)

	%CloseButton.pressed.connect(_close)

	# Live updates.
	InventoryManager.inventory_changed.connect(_refresh)
	CellarManager.bottles_changed.connect(_refresh)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if is_open:
			_close()
		else:
			_open()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _open() -> void:
	if is_open:
		return
	# Don't open over an interactable UI.
	if BaseInteractableUI.open_count > 0:
		return
	is_open = true
	_refresh()
	panel.show()


func _close() -> void:
	if not is_open:
		return
	is_open = false
	panel.hide()


# ---------------------------------------------------------------------------
# Refresh
# ---------------------------------------------------------------------------

func _refresh() -> void:
	if not is_open:
		return
	_refresh_ingredients()
	_refresh_perfumes()


func _refresh_ingredients() -> void:
	for child in %IngredientList.get_children():
		child.queue_free()

	var items := InventoryManager.get_all()
	if items.is_empty():
		var lbl := Label.new()
		lbl.text = "(no ingredients)"
		lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		%IngredientList.add_child(lbl)
		return

	# Sort by display name for consistency.
	var sorted: Array = []
	for ingredient: BaseIngredient in items:
		sorted.append({ "ingredient": ingredient, "count": items[ingredient] })
	sorted.sort_custom(func(a, b): return a["ingredient"].display_name < b["ingredient"].display_name)

	for entry in sorted:
		var ing: BaseIngredient = entry["ingredient"]
		var count: int = entry["count"]

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		# Icon if available, otherwise colored dot.
		if ing.icon:
			var tex_rect := TextureRect.new()
			tex_rect.texture = ing.icon
			tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.custom_minimum_size = Vector2(20, 20)
			tex_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(tex_rect)
		else:
			var dot := ColorRect.new()
			dot.custom_minimum_size = Vector2(12, 12)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			dot.color = ing.liquid_color
			row.add_child(dot)

		# Name and count.
		var is_raw: bool = ing.result_item is BaseIngredient
		var lbl := Label.new()
		lbl.text = "%s  x%d" % [ing.display_name, count]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_raw:
			lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		row.add_child(lbl)

		%IngredientList.add_child(row)


func _refresh_perfumes() -> void:
	for child in %PerfumeList.get_children():
		child.queue_free()

	if CellarManager.bottles.is_empty():
		var lbl := Label.new()
		lbl.text = "(no perfumes)"
		lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		%PerfumeList.add_child(lbl)
		return

	for bottle: BottledPerfume in CellarManager.bottles:
		var card := PanelContainer.new()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)

		# Small beaker icon.
		var beaker := BeakerDisplay.new()
		beaker.custom_minimum_size = Vector2(30, 42)
		beaker.liquid_color = _get_bottle_color(bottle)
		beaker.fill_ratio = 0.65
		beaker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(beaker)

		# Info column.
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)

		var name_lbl := Label.new()
		name_lbl.text = bottle.get_label()
		name_lbl.clip_text = true
		info.add_child(name_lbl)

		var detail_lbl := Label.new()
		var final_q := bottle.get_final_quality()
		var final_tier := bottle.get_final_tier()
		var detail_text := "%s  —  %.1f" % [final_tier, final_q]
		if bottle.aged:
			detail_text += "  (aged +%.1f)" % bottle.age_bonus
		if bottle.has_accord:
			detail_text += "  [accord]"
		detail_lbl.text = detail_text
		detail_lbl.add_theme_font_size_override("font_size", 12)
		detail_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		info.add_child(detail_lbl)

		row.add_child(info)
		%PerfumeList.add_child(card)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _get_bottle_color(bottle: BottledPerfume) -> Color:
	if bottle.blend_summary.is_empty():
		return Color(0.7, 0.85, 0.95, 0.25)
	# Average the liquid colors of all ingredients, weighted by amount.
	var total_color := Color(0, 0, 0, 0)
	var total_drops := 0
	for entry in bottle.blend_summary:
		var path: String = entry.get("path", "")
		if path == "" or not ResourceLoader.exists(path):
			continue
		var ing := load(path) as BaseIngredient
		if ing == null:
			continue
		var amt: int = int(entry.get("amount", 1))
		total_color.r += ing.liquid_color.r * amt
		total_color.g += ing.liquid_color.g * amt
		total_color.b += ing.liquid_color.b * amt
		total_color.a += ing.liquid_color.a * amt
		total_drops += amt
	if total_drops == 0:
		return Color(0.7, 0.85, 0.95, 0.25)
	return Color(
		total_color.r / total_drops,
		total_color.g / total_drops,
		total_color.b / total_drops,
		total_color.a / total_drops,
	)
