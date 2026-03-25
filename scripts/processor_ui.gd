extends BaseInteractableUI

## Margot's processing UI.
## First visit: intro dialogue + starter oil gift.
## Subsequent visits: two-column submit/collect interface.

const STARTER_OIL_PATHS: Array[String] = [
	"res://data/oils/rose_oil.tres",
	"res://data/oils/jasmine_oil.tres",
	"res://data/oils/vanilla_oil.tres",
	"res://data/oils/sandalwood_oil.tres",
	"res://data/oils/bergamot_oil.tres",
	"res://data/oils/peppermint_oil.tres",
]

var _intro_overlay: PanelContainer = null


func _ready() -> void:
	super()
	%CollectAllButton.pressed.connect(_on_collect_all)
	ProcessingManager.queue_changed.connect(_refresh)
	ProcessingManager.oils_ready.connect(_refresh)
	CoinManager.coins_changed.connect(_refresh)
	InventoryManager.inventory_changed.connect(_refresh)


func open() -> void:
	if not ProcessingManager.has_met_processor:
		super()
		_show_intro()
		return
	_refresh()
	super()


# ---------------------------------------------------------------------------
# Intro dialogue
# ---------------------------------------------------------------------------

func _show_intro() -> void:
	if _intro_overlay:
		return

	_intro_overlay = PanelContainer.new()
	_intro_overlay.add_theme_stylebox_override("panel", UITheme.make_panel_bg())

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_intro_overlay.add_child(vbox)

	var lines: Array[String] = [
		"Oh! You must be the new owner. Welcome to Bellefleur — we've been wondering when someone would take on the old château.",
		"I'm Margot. I process materials for the local artisans — oils, essences, that sort of thing. If you're planning to revive the perfumery, you'll need my help.",
		"Here — take these to get started. Consider them a welcome gift.",
	]

	for line in lines:
		var lbl := Label.new()
		lbl.text = line
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_color_override("font_color", UITheme.TEXT_DARK)
		vbox.add_child(lbl)

	# Show each starter oil with a vial icon and name.
	var oils_grid := GridContainer.new()
	oils_grid.columns = 2
	oils_grid.add_theme_constant_override("h_separation", 12)
	oils_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(oils_grid)

	for oil_path in STARTER_OIL_PATHS:
		var oil := load(oil_path) as BaseIngredient
		if oil == null:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var vial := BeakerDisplay.new()
		vial.custom_minimum_size = Vector2(24, 32)
		vial.liquid_color = oil.liquid_color
		vial.fill_ratio = 0.7
		row.add_child(vial)

		var name_lbl := Label.new()
		name_lbl.text = oil.display_name
		name_lbl.add_theme_color_override("font_color", UITheme.TEXT_DARK)
		name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(name_lbl)

		oils_grid.add_child(row)

	var closing_lbl := Label.new()
	closing_lbl.text = "When you gather raw ingredients from around the area, bring them to me. I'll process them into oils you can use at the bench. Small fee for my time — I'm sure you understand. Good luck in there. The old perfumer left quite a legacy."
	closing_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	closing_lbl.add_theme_color_override("font_color", UITheme.TEXT_DARK)
	vbox.add_child(closing_lbl)

	var btn := Button.new()
	btn.text = "Accept starter oils"
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_on_intro_continue)
	vbox.add_child(btn)

	var panel := get_node_or_null("Panel")
	if panel:
		panel.add_child(_intro_overlay)
		_intro_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_intro_overlay.offset_left = 20
		_intro_overlay.offset_top = 20
		_intro_overlay.offset_right = -20
		_intro_overlay.offset_bottom = -20


func _on_intro_continue() -> void:
	ProcessingManager.mark_processor_met()
	_gift_starter_oils()
	if _intro_overlay:
		_intro_overlay.queue_free()
		_intro_overlay = null
	_refresh()


func _gift_starter_oils() -> void:
	for oil_path in STARTER_OIL_PATHS:
		var oil := load(oil_path) as BaseIngredient
		if oil:
			InventoryManager.add_ingredient(oil, 1)


# ---------------------------------------------------------------------------
# Refresh
# ---------------------------------------------------------------------------

func _refresh() -> void:
	_update_coin_label()
	_build_raw_list()
	_build_ready_list()


func _update_coin_label() -> void:
	%CoinLabel.text = "Coins: %d" % CoinManager.get_coins()
	%CoinLabel.add_theme_color_override("font_color", UITheme.GOLD)


# ---------------------------------------------------------------------------
# Left column — raw ingredients + queue
# ---------------------------------------------------------------------------

func _build_raw_list() -> void:
	for child in %RawList.get_children():
		child.queue_free()

	# Show raw ingredients the player has.
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

		# Icon if available, otherwise colored dot.
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

		# Info.
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_lbl := Label.new()
		name_lbl.text = "%s  x%d" % [ing.display_name, count]
		info.add_child(name_lbl)
		hbox.add_child(info)

		# Cost label.
		var cost_lbl := Label.new()
		var can_afford := CoinManager.get_coins() >= ProcessingManager.PROCESS_COST
		cost_lbl.text = "%d coins" % ProcessingManager.PROCESS_COST
		cost_lbl.add_theme_color_override("font_color", UITheme.GOLD if can_afford else UITheme.TEXT_MUTED)
		cost_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(cost_lbl)

		# Process button.
		var btn := Button.new()
		btn.text = "Process"
		btn.disabled = not can_afford
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var raw := ing
		btn.pressed.connect(func(): _on_process(raw))
		hbox.add_child(btn)

		%RawList.add_child(card)

	# Show in-progress queue items (Margot's only, not workshop).
	var queue := ProcessingManager.get_queue_filtered(false)
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

	var ready := ProcessingManager.get_ready_oils_filtered(false)
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
	ProcessingManager.submit(raw)


func _on_collect_all() -> void:
	ProcessingManager.collect_all_filtered(false)
