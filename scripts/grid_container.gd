extends GridContainer

var mixing_manager: MixingManager
var committed := false

# Note-position filter: "" means show all.
var _note_filter := ""
var _tab_buttons: Array[Button] = []

const TAB_LABELS := {
	"": "All",
	"top": "Top",
	"middle": "Heart",
	"base": "Base",
	"accords": "Accords",
}

func _ready():
	await get_tree().process_frame
	_build_note_tabs()
	_refresh()
	InventoryManager.inventory_changed.connect(_refresh)


func _build_note_tabs() -> void:
	# Insert a tab row above the ScrollContainer (our grandparent is IngredientColumn).
	var scroll := get_parent()
	if scroll == null:
		return
	var column := scroll.get_parent()
	if column == null:
		return
	var scroll_idx := scroll.get_index()

	var tab_row := HBoxContainer.new()
	tab_row.name = "NoteTabRow"
	tab_row.add_theme_constant_override("separation", 4)
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER

	for key in TAB_KEYS:
		var btn := Button.new()
		btn.text = TAB_LABELS[key]
		btn.add_theme_font_size_override("font_size", 12)
		btn.custom_minimum_size = Vector2(0, 26)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var filter_key: String = key
		btn.pressed.connect(func(): _set_note_filter(filter_key))
		tab_row.add_child(btn)
		_tab_buttons.append(btn)

	column.add_child(tab_row)
	column.move_child(tab_row, scroll_idx)
	_style_tabs()


const TAB_KEYS: Array[String] = ["", "top", "middle", "base", "accords"]

func _style_tabs() -> void:
	for i in _tab_buttons.size():
		var btn := _tab_buttons[i]
		var is_active: bool = TAB_KEYS[i] == _note_filter

		var style := StyleBoxFlat.new()
		if is_active:
			style.bg_color = UITheme.WARM_AMBER
			btn.add_theme_color_override("font_color", UITheme.CARD_BG)
		else:
			style.bg_color = UITheme.PARCHMENT_DARK
			btn.add_theme_color_override("font_color", UITheme.TEXT_MUTED)

		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		btn.add_theme_stylebox_override("normal", style)

		var hover_style: StyleBoxFlat = style.duplicate()
		if not is_active:
			hover_style.bg_color = UITheme.BORDER_LIGHT
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", style)


func _set_note_filter(filter: String) -> void:
	if filter == _note_filter:
		return
	_note_filter = filter
	_style_tabs()
	_refresh()


func reset_filter() -> void:
	_note_filter = ""
	_style_tabs()


func _refresh() -> void:
	var inventory := InventoryManager.get_all()
	var all_ingredients := _load_all_ingredients()
	var beaker_counts := _get_beaker_counts()
	if _note_filter == "accords":
		# Accords tab: only show accords.
		for child in get_children():
			child.queue_free()
		_populate_accords()
	else:
		# Ingredient tabs: show ingredients (filtered by note), no accords.
		populate_ingredients(all_ingredients, inventory, beaker_counts)


## Returns counts of manually-added drops in the beaker (excludes accord-expanded).
## Accord ingredients are already consumed from inventory on add, so they don't
## need to be subtracted from the available count again.
func _get_beaker_counts() -> Dictionary:
	if not mixing_manager:
		return {}
	var manual_blend := mixing_manager.get_manual_blend_summary()
	var counts: Dictionary = {}
	for entry in manual_blend:
		counts[entry["ingredient"]] = int(entry["amount"])
	return counts


# Scans data/ and data/oils/ for BaseIngredient resources.
# Only returns processed oils (ingredients where result_item is null).
func _load_all_ingredients() -> Array[BaseIngredient]:
	var ingredients: Array[BaseIngredient] = []
	for scan_path in ["res://data/", "res://data/oils/"]:
		var dir := DirAccess.open(scan_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var resource := load(scan_path + file_name)
				if resource is BaseIngredient:
					var ing := resource as BaseIngredient
					if not (ing.result_item is BaseIngredient) and ing.scent_family != "amber":
						ingredients.append(ing)
			file_name = dir.get_next()
		dir.list_dir_end()
	return ingredients


# Shows all ingredients as styled tags with scent-family colored pips.
func populate_ingredients(all_ingredients: Array[BaseIngredient], inventory: Dictionary, beaker_counts: Dictionary):
	for child in get_children():
		child.queue_free()

	for ingredient in all_ingredients:
		# Apply note-position filter.
		if _note_filter != "" and ingredient.note_position != _note_filter:
			continue

		var owned: int = inventory.get(ingredient, 0)
		var in_beaker: int = beaker_counts.get(ingredient, 0)
		var available: int = owned - in_beaker

		# Hide ingredients the player doesn't have (and hasn't added to the beaker).
		if owned <= 0 and in_beaker <= 0:
			continue
		var enabled := available > 0 and not committed

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		# Scent-family colored pip
		var pip := Label.new()
		pip.text = "\u25cf"
		pip.add_theme_color_override("font_color", UITheme.get_family_color(ingredient.scent_family))
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if not enabled:
			pip.modulate.a = 0.4
		row.add_child(pip)

		# Ingredient button styled as a tag
		var btn := Button.new()
		btn.text = "%s (%d)" % [ingredient.display_name, maxi(available, 0)]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 32)
		btn.icon = ingredient.icon
		btn.expand_icon = true

		if enabled:
			btn.add_theme_stylebox_override("normal", UITheme.make_ingredient_tag_bg(true))
			btn.add_theme_stylebox_override("hover", UITheme.make_ingredient_tag_bg(true))
			btn.pressed.connect(func(): _on_ingredient_clicked(ingredient))
		else:
			btn.add_theme_stylebox_override("normal", UITheme.make_ingredient_tag_bg(false))
			btn.add_theme_stylebox_override("disabled", UITheme.make_ingredient_tag_bg(false))
			btn.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
			btn.add_theme_color_override("font_disabled_color", UITheme.TEXT_MUTED)
			btn.disabled = true

		row.add_child(btn)
		add_child(row)


func _on_ingredient_clicked(ingredient_data: BaseIngredient):
	if committed or not mixing_manager:
		return
	var beaker_counts := _get_beaker_counts()
	var owned := InventoryManager.get_count(ingredient_data)
	var in_beaker: int = beaker_counts.get(ingredient_data, 0)
	if owned - in_beaker > 0:
		mixing_manager.add_ingredient(ingredient_data)


func _populate_accords() -> void:
	var discovered := AccordManager.get_discovered_accords()
	if discovered.is_empty():
		var lbl := Label.new()
		lbl.text = "No accords discovered yet."
		lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		lbl.add_theme_font_size_override("font_size", 12)
		add_child(lbl)
		return

	for accord in discovered:
		var uses_available := 0
		if mixing_manager:
			uses_available = mixing_manager.get_accord_uses_available(accord)
		var enabled := uses_available > 0 and not committed

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		# Scent-family colored pip
		var pip := Label.new()
		pip.text = "\u25cf"
		pip.add_theme_color_override("font_color", UITheme.get_family_color(accord.scent_family))
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if not enabled:
			pip.modulate.a = 0.4
		row.add_child(pip)

		var btn := Button.new()
		btn.text = "%s (%d)" % [accord.accord_name, uses_available]
		btn.tooltip_text = _build_accord_tooltip(accord)
		if accord.icon:
			btn.icon = accord.icon
			btn.expand_icon = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 32)

		if enabled:
			btn.add_theme_stylebox_override("normal", UITheme.make_ingredient_tag_bg(true))
			btn.add_theme_stylebox_override("hover", UITheme.make_ingredient_tag_bg(true))
			btn.pressed.connect(func(): _on_accord_clicked(accord))
		else:
			btn.add_theme_stylebox_override("normal", UITheme.make_ingredient_tag_bg(false))
			btn.add_theme_stylebox_override("disabled", UITheme.make_ingredient_tag_bg(false))
			btn.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
			btn.add_theme_color_override("font_disabled_color", UITheme.TEXT_MUTED)
			btn.disabled = true

		row.add_child(btn)
		add_child(row)


func _build_accord_tooltip(accord: BaseAccord) -> String:
	var components := AccordManager.get_recipe_ingredients(accord)
	var parts: Array[String] = []
	for entry in components:
		var ing: BaseIngredient = entry["ingredient"]
		var amt: int = int(entry["amount"])
		parts.append("%d %s" % [amt, ing.display_name])
	var recipe_text := " + ".join(parts)
	if accord.description != "":
		return "%s\n%s" % [accord.description, recipe_text]
	return recipe_text


func _on_accord_clicked(accord: BaseAccord) -> void:
	if committed or not mixing_manager:
		return
	mixing_manager.add_accord(accord)
