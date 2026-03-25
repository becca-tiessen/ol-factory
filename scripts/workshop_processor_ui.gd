extends BaseInteractableUI

## The player's workshop processing UI.
## Identical layout to Margot's processor but free and faster (30s).
## Only shows workshop queue/ready items, not Margot's.


func _ready() -> void:
	super()
	%CollectAllButton.pressed.connect(_on_collect_all)
	ProcessingManager.queue_changed.connect(_refresh)
	ProcessingManager.oils_ready.connect(_refresh)
	InventoryManager.inventory_changed.connect(_refresh)


func open() -> void:
	_refresh()
	super()


# ---------------------------------------------------------------------------
# Refresh
# ---------------------------------------------------------------------------

func _refresh() -> void:
	_build_raw_list()
	_build_ready_list()


# ---------------------------------------------------------------------------
# Left column — raw ingredients + queue
# ---------------------------------------------------------------------------

func _build_raw_list() -> void:
	for child in %RawList.get_children():
		child.queue_free()

	var items := InventoryManager.get_all()
	var has_any_raw := false

	var sorted: Array = []
	for ingredient: BaseIngredient in items:
		if ingredient.result_item is BaseIngredient:
			sorted.append({ "ingredient": ingredient, "count": items[ingredient] })
	sorted.sort_custom(func(a, b): return a["ingredient"].display_name < b["ingredient"].display_name)

	for entry in sorted:
		has_any_raw = true
		var ing: BaseIngredient = entry["ingredient"]
		var count: int = entry["count"]

		var card := PanelContainer.new()
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		card.add_child(hbox)

		if ing.icon:
			var tex_rect := TextureRect.new()
			tex_rect.texture = ing.icon
			tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.custom_minimum_size = Vector2(20, 20)
			tex_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hbox.add_child(tex_rect)
		else:
			var dot := ColorRect.new()
			dot.custom_minimum_size = Vector2(12, 12)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			dot.color = ing.liquid_color
			hbox.add_child(dot)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_lbl := Label.new()
		name_lbl.text = "%s  x%d" % [ing.display_name, count]
		info.add_child(name_lbl)
		hbox.add_child(info)

		# Free label.
		var cost_lbl := Label.new()
		cost_lbl.text = "Free"
		cost_lbl.add_theme_color_override("font_color", UITheme.SOFT_GREEN)
		cost_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(cost_lbl)

		# Process button.
		var btn := Button.new()
		btn.text = "Process"
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var raw := ing
		btn.pressed.connect(func(): _on_process(raw))
		hbox.add_child(btn)

		%RawList.add_child(card)

	# Show in-progress queue items (workshop only).
	var queue := ProcessingManager.get_queue_filtered(true)
	if not queue.is_empty():
		var sep := HSeparator.new()
		%RawList.add_child(sep)

		var queue_header := Label.new()
		queue_header.text = "In Progress"
		queue_header.add_theme_color_override("font_color", UITheme.WARM_AMBER)
		%RawList.add_child(queue_header)

		for entry in queue:
			var raw_res := load(entry["raw_path"]) as BaseIngredient
			if raw_res == null:
				continue
			var remaining: float = ProcessingManager.get_queue_time_remaining(entry)
			var lbl := Label.new()
			lbl.text = "%s — %ds remaining" % [raw_res.display_name, int(remaining)]
			lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
			%RawList.add_child(lbl)

	if not has_any_raw and queue.is_empty():
		var lbl := Label.new()
		lbl.text = "No raw ingredients to process."
		lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		%RawList.add_child(lbl)


# ---------------------------------------------------------------------------
# Right column — ready oils
# ---------------------------------------------------------------------------

func _build_ready_list() -> void:
	for child in %ReadyList.get_children():
		child.queue_free()

	var ready := ProcessingManager.get_ready_oils_filtered(true)
	%CollectAllButton.visible = not ready.is_empty()

	if ready.is_empty():
		var lbl := Label.new()
		lbl.text = "Nothing ready yet — check back soon."
		lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		%ReadyList.add_child(lbl)
		return

	# Group by oil path for tidy display.
	var counts: Dictionary = {}
	for oil_path in ready:
		if counts.has(oil_path):
			counts[oil_path] += 1
		else:
			counts[oil_path] = 1

	for oil_path: String in counts:
		var oil := load(oil_path) as BaseIngredient
		if oil == null:
			continue
		var count: int = counts[oil_path]

		var card := PanelContainer.new()
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		card.add_child(hbox)

		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.color = oil.liquid_color
		hbox.add_child(dot)

		var lbl := Label.new()
		lbl.text = "%s  x%d" % [oil.display_name, count]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl)

		%ReadyList.add_child(card)


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func _on_process(raw: BaseIngredient) -> void:
	ProcessingManager.submit_workshop(raw)


func _on_collect_all() -> void:
	ProcessingManager.collect_all_filtered(true)
