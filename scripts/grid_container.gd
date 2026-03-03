extends GridContainer

var mixing_manager: MixingManager
var committed := false

func _ready():
	await get_tree().process_frame
	_refresh()
	InventoryManager.inventory_changed.connect(_refresh)


func _refresh() -> void:
	var inventory := InventoryManager.get_all()
	var all_ingredients := _load_all_ingredients()
	var beaker_counts := _get_beaker_counts()
	populate_ingredients(all_ingredients, inventory, beaker_counts)
	_populate_accords()


func _get_beaker_counts() -> Dictionary:
	if not mixing_manager:
		return {}
	var counts: Dictionary = {}
	for ing in mixing_manager.get_current_mixture():
		counts[ing] = counts.get(ing, 0) + 1
	return counts


# Scans the data/ directory and returns every .tres that is a BaseIngredient.
func _load_all_ingredients() -> Array[BaseIngredient]:
	var ingredients: Array[BaseIngredient] = []
	var dir := DirAccess.open("res://data/")
	if dir == null:
		return ingredients
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var resource := load("res://data/" + file_name)
			if resource is BaseIngredient:
				ingredients.append(resource as BaseIngredient)
		file_name = dir.get_next()
	dir.list_dir_end()
	return ingredients


# Shows all ingredients as styled tags with scent-family colored pips.
func populate_ingredients(all_ingredients: Array[BaseIngredient], inventory: Dictionary, beaker_counts: Dictionary):
	for child in get_children():
		child.queue_free()

	for ingredient in all_ingredients:
		var owned: int = inventory.get(ingredient, 0)
		var in_beaker: int = beaker_counts.get(ingredient, 0)
		var available: int = owned - in_beaker
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
	var owned := InventoryManager.get_count(ingredient_data)
	var in_beaker := 0
	for ing in mixing_manager.get_current_mixture():
		if ing == ingredient_data:
			in_beaker += 1
	if owned - in_beaker > 0:
		mixing_manager.add_ingredient(ingredient_data)


func _populate_accords() -> void:
	var discovered := AccordManager.get_discovered_accords()
	if discovered.is_empty():
		return

	# Section separator
	var sep := Label.new()
	sep.text = "Accords"
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep.custom_minimum_size = Vector2(64, 28)
	UITheme.style_section_title(sep)
	add_child(sep)

	for accord in discovered:
		var btn := Button.new()
		btn.text = accord.accord_name
		btn.tooltip_text = accord.description
		if accord.icon:
			btn.icon = accord.icon
			btn.expand_icon = true
		btn.custom_minimum_size = Vector2(64, 32)
		if committed:
			btn.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
			btn.add_theme_color_override("font_disabled_color", UITheme.TEXT_MUTED)
			btn.disabled = true
		else:
			btn.pressed.connect(func(): _on_accord_clicked(accord))
		add_child(btn)


func _on_accord_clicked(accord: BaseAccord) -> void:
	if committed or not mixing_manager:
		return
	mixing_manager.add_accord(accord)
