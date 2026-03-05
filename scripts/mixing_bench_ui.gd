extends BaseInteractableUI

var mixing_manager: MixingManager
var _committed := false
var _bottle: BeakerDisplay
var _radar: ScentRadarGraph
var _celebration_card: PanelContainer
var _celebration_tween: Tween

func _ready() -> void:
	super()
	mixing_manager = get_tree().root.find_child("MixingManager", true, false)
	if mixing_manager:
		mixing_manager.mixture_updated.connect(_on_mixture_updated)
		var grid_container = %GridContainer
		if grid_container:
			grid_container.mixing_manager = mixing_manager

	# Store references before any reparenting.
	_bottle = %Bottle
	_radar  = %ScentRadar as ScentRadarGraph

	%CommitButton.pressed.connect(_on_commit_pressed)
	%UndoButton.pressed.connect(_on_undo_pressed)
	%ClearButton.pressed.connect(_on_clear_pressed)

	# Style the action buttons
	UITheme.style_commit_button(%CommitButton)
	UITheme.style_clear_button(%UndoButton)
	UITheme.style_clear_button(%ClearButton)

	# Wrap beaker in a wooden-shelf panel
	_add_beaker_shelf()

	# Style request banner
	%RequestName.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	%RequestReqs.add_theme_color_override("font_color", UITheme.SOFT_BLUE)
	%RequestReqs.add_theme_font_size_override("font_size", 12)

	# Style the note pyramid legend
	_style_pyramid_legend()

	RequestManager.request_changed.connect(_update_request_tracker)
	_update_request_tracker()


func _unhandled_input(event: InputEvent) -> void:
	super(event)


func open() -> void:
	# If the previous blend was committed, reset for a fresh start.
	if _committed:
		_committed = false
		if mixing_manager:
			mixing_manager.reset_beaker()
		_reset_results()
	# Clean up any lingering celebration state.
	if _celebration_card and is_instance_valid(_celebration_card):
		_celebration_card.queue_free()
		_celebration_card = null
	if _celebration_tween:
		_celebration_tween.kill()
		_celebration_tween = null
	_update_ui_state()
	super()


func _on_mixture_updated(current_mixture: Array[BaseIngredient], _final_color: Color, _final_scent: Vector3) -> void:
	# Get live preview data from mixing manager.
	var preview := mixing_manager.get_live_preview()

	# Update the beaker visual with per-ingredient color layers.
	_bottle.layers = preview.get("ingredient_layers", [])
	_bottle.liquid_color = preview["family_color"]  # fallback if layers empty
	_bottle.fill_ratio = clampf(float(current_mixture.size()) / 12.0, 0.0, 1.0)

	# Update live feedback.
	_update_live_feedback(preview, current_mixture.is_empty())

	# Update radar chart.
	if _radar:
		_radar.set_weights(preview.get("family_weights", {}))

	_update_blend_display(current_mixture)
	# Refresh ingredient list so available counts stay in sync.
	%GridContainer._refresh()
	# Enable/disable buttons based on whether beaker has contents.
	if not _committed:
		%CommitButton.disabled = current_mixture.is_empty()
		%UndoButton.disabled = current_mixture.is_empty()


func _update_blend_display(mixture: Array[BaseIngredient]) -> void:
	for child in %BlendList.get_children():
		child.queue_free()

	# Count drops per ingredient
	var counts: Dictionary = {}
	var order: Array[String] = []
	for ing in mixture:
		if not counts.has(ing.display_name):
			counts[ing.display_name] = 0
			order.append(ing.display_name)
		counts[ing.display_name] += 1

	if counts.is_empty() and mixing_manager.get_current_accords().is_empty():
		var lbl := Label.new()
		lbl.text = "(empty)"
		lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		%BlendList.add_child(lbl)
		return

	# Show accords first.
	var accord_summary := mixing_manager.get_accord_summary()
	for entry in accord_summary:
		var accord: BaseAccord = entry["accord"]
		var row := _make_blend_row(UITheme.WARM_AMBER, "%s  x%d" % [accord.accord_name, entry["count"]], UITheme.WARM_AMBER)
		%BlendList.add_child(row)

	# Show raw ingredients in reverse order so the list top matches the beaker top.
	for i in range(order.size() - 1, -1, -1):
		var ing_name: String = order[i]
		var dot_color := BeakerDisplay.color_for_ingredient(ing_name)
		var row := _make_blend_row(dot_color, "%s  x%d" % [ing_name, counts[ing_name]])
		%BlendList.add_child(row)


func _on_commit_pressed() -> void:
	if _committed or not mixing_manager:
		return
	var mixture := mixing_manager.get_current_mixture()
	if mixture.is_empty():
		return

	# Consume only manually-added ingredients (not accord-expanded ones).
	var manual_blend := mixing_manager.get_manual_blend_summary()
	for entry in manual_blend:
		InventoryManager.remove_ingredient(entry["ingredient"], int(entry["amount"]))

	# Full blend (including accord components) for quality and bottling.
	var blend := mixing_manager.get_blend_summary()
	var bd: Dictionary = mixing_manager.get_current_breakdown()

	# Create a bottled perfume and send it straight to the aging rack.
	var accords_used := mixing_manager.get_current_accords()
	var bottle := BottledPerfume.create_from_blend(blend, bd, accords_used)
	var placed_on_rack := false
	if CellarManager.rack_has_space():
		CellarManager.add_bottle(bottle)
		CellarManager.place_on_rack(bottle)
		placed_on_rack = true
	else:
		CellarManager.add_bottle(bottle)

	# Check for new accord discoveries.
	var new_accords := AccordManager.check_blend_for_accords(blend)

	# Notify request manager of the blend commit (drives rotation counter).
	RequestManager.on_blend_committed()

	# Lock the blend.
	_committed = true
	_update_ui_state()

	# Start the celebration sequence — scoring is revealed inside the card.
	_start_celebration(bd, placed_on_rack, new_accords)


func _on_undo_pressed() -> void:
	if _committed or not mixing_manager:
		return
	mixing_manager.undo_last_drop()


func _on_clear_pressed() -> void:
	if _committed:
		return
	if mixing_manager:
		mixing_manager.reset_beaker()
	_reset_results()


func _update_ui_state() -> void:
	var is_empty := mixing_manager == null or mixing_manager.get_current_mixture().is_empty()
	%CommitButton.disabled = _committed or is_empty
	%UndoButton.disabled = _committed or is_empty
	%ClearButton.disabled = _committed
	%GridContainer.committed = _committed
	%GridContainer._refresh()


func _update_live_feedback(preview: Dictionary, is_empty: bool) -> void:
	# Description.
	%DescriptionLabel.text = preview["description"] if not is_empty else ""

	# Note indicators — dim when absent, bright when present.
	%TopNote.modulate = Color.WHITE
	%HeartNote.modulate = Color.WHITE
	%BaseNote.modulate = Color.WHITE

	%TopNote.add_theme_color_override("font_color", UITheme.NOTE_LIT if preview["has_top"] else UITheme.NOTE_DIM)
	%HeartNote.add_theme_color_override("font_color", UITheme.NOTE_LIT if preview["has_middle"] else UITheme.NOTE_DIM)
	%BaseNote.add_theme_color_override("font_color", UITheme.NOTE_LIT if preview["has_base"] else UITheme.NOTE_DIM)

	# Balance bar.
	var bal: float = preview["balance_ratio"]
	%BalanceBar.value = bal
	if is_empty:
		%BalanceHint.text = ""
	elif bal < 0.1:
		%BalanceHint.text = "Balanced"
		%BalanceHint.add_theme_color_override("font_color", UITheme.SOFT_GREEN)
	elif bal < 0.5:
		%BalanceHint.text = "Leaning"
		%BalanceHint.add_theme_color_override("font_color", UITheme.WARM_AMBER)
	else:
		%BalanceHint.text = "Overpowering"
		%BalanceHint.add_theme_color_override("font_color", UITheme.SOFT_RED)


func _reset_results() -> void:
	# Reset live feedback.
	%DescriptionLabel.text = ""
	%TopNote.add_theme_color_override("font_color", UITheme.NOTE_DIM)
	%HeartNote.add_theme_color_override("font_color", UITheme.NOTE_DIM)
	%BaseNote.add_theme_color_override("font_color", UITheme.NOTE_DIM)
	%BalanceBar.value = 0.0
	%BalanceHint.text = ""


func _update_request_tracker() -> void:
	var req := RequestManager.active_request
	if req == null:
		%RequestName.text = "(No active request)"
		%RequestName.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		%RequestReqs.text = ""
		return
	%RequestName.add_theme_color_override("font_color", UITheme.WARM_AMBER)
	%RequestName.text = req.request_name
	%RequestReqs.text = RequestManager.get_requirements_text(req)


func _clear_live_feedback() -> void:
	%DescriptionLabel.text = ""
	%TopNote.add_theme_color_override("font_color", UITheme.NOTE_DIM)
	%HeartNote.add_theme_color_override("font_color", UITheme.NOTE_DIM)
	%BaseNote.add_theme_color_override("font_color", UITheme.NOTE_DIM)
	%BalanceBar.value = 0.0
	%BalanceHint.text = ""


func _make_blend_row(dot_color: Color, text: String, text_color: Color = Color.WHITE) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.color = dot_color
	row.add_child(dot)

	var lbl := Label.new()
	lbl.text = text
	if text_color != Color.WHITE:
		lbl.add_theme_color_override("font_color", text_color)
	row.add_child(lbl)

	return row


# ---------------------------------------------------------------------------
# Post-commit celebration
# ---------------------------------------------------------------------------

func _start_celebration(bd: Dictionary, placed_on_rack: bool, new_accords: Array[BaseAccord] = []) -> void:
	# 1. Clear the blend list and live feedback immediately (scoring section stays visible).
	for child in %BlendList.get_children():
		child.queue_free()
	_clear_live_feedback()

	# 2. Drain the beaker liquid over 0.5s (collapse layers into single color for smooth drain).
	_bottle.liquid_color = _bottle.liquid_color  # keep current fallback color
	_bottle.layers = []
	if _celebration_tween:
		_celebration_tween.kill()
	_celebration_tween = create_tween()
	_celebration_tween.tween_property(_bottle, "fill_ratio", 0.0, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	# 3. Show celebration card after the drain finishes.
	_celebration_tween.tween_callback(_show_celebration_card.bind(bd, placed_on_rack, new_accords))

	# 4. No auto-dismiss — player must press the button on the card.


func _show_celebration_card(bd: Dictionary, placed_on_rack: bool, new_accords: Array[BaseAccord] = []) -> void:
	var panel := get_node_or_null("Panel")
	if panel == null:
		return

	# -- Build the card --
	_celebration_card = PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = UITheme.CARD_BG
	UITheme._set_corners(card_style, 12)
	UITheme._set_border(card_style, 2, UITheme.BORDER)
	card_style.shadow_color = Color(0.55, 0.42, 0.15, 0.30)
	card_style.shadow_size = 24
	card_style.shadow_offset = Vector2(0, 0)
	card_style.content_margin_left = 32
	card_style.content_margin_right = 32
	card_style.content_margin_top = 28
	card_style.content_margin_bottom = 28
	_celebration_card.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	_celebration_card.add_child(vbox)

	# Bottle icon — simple drawn shape using a small BeakerDisplay.
	var icon := BeakerDisplay.new()
	icon.custom_minimum_size = Vector2(50, 70)
	icon.liquid_color = _bottle.liquid_color
	icon.fill_ratio = 0.65
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon)

	# Perfume name.
	var name_lbl := Label.new()
	name_lbl.text = "New Perfume"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", UITheme.HEADER_BROWN)
	name_lbl.add_theme_font_size_override("font_size", 20)
	vbox.add_child(name_lbl)

	# Quality tier line.
	var tier_lbl := Label.new()
	tier_lbl.text = "%s — %.1f" % [bd["tier"], bd["quality"]]
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_lbl.add_theme_color_override("font_color", UITheme.GOLD)
	tier_lbl.add_theme_font_size_override("font_size", 18)
	vbox.add_child(tier_lbl)

	# Scoring breakdown (compact, muted).
	var breakdown_lbl := Label.new()
	breakdown_lbl.text = "Compat: %.1f  ·  Balance: %.0f%%  ·  Pyramid: %s" % [
		bd["compatibility"],
		bd["balance"] * 100.0,
		"+0.5" if bd["pyramid"] > 0.0 else "—",
	]
	breakdown_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	breakdown_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	breakdown_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(breakdown_lbl)

	# Separator.
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Rack placement message.
	var msg_lbl := Label.new()
	if placed_on_rack:
		msg_lbl.text = "Placed on the aging rack in your cellar."
	else:
		msg_lbl.text = "Rack is full — stored in your cellar inventory."
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	msg_lbl.add_theme_font_size_override("font_size", 13)
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(msg_lbl)

	# Accord discovery line (if any).
	if not new_accords.is_empty():
		var names: Array[String] = []
		for accord in new_accords:
			names.append(accord.accord_name)
		var accord_lbl := Label.new()
		accord_lbl.text = "Accord Discovered: %s!" % ", ".join(names)
		accord_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		accord_lbl.add_theme_color_override("font_color", UITheme.GOLD)
		accord_lbl.add_theme_font_size_override("font_size", 15)
		accord_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(accord_lbl)

	# Dismiss button.
	var dismiss_btn := Button.new()
	dismiss_btn.text = "OK"
	dismiss_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UITheme.style_commit_button(dismiss_btn)
	dismiss_btn.pressed.connect(_dismiss_celebration)
	vbox.add_child(dismiss_btn)

	# -- Position centered over the Panel --
	_celebration_card.set_anchors_preset(Control.PRESET_CENTER)
	_celebration_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_celebration_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_child(_celebration_card)

	# -- Entrance animation: scale from 80% with ease-out-back, fade in --
	# Defer pivot calculation until the card has been laid out.
	_celebration_card.modulate.a = 0.0
	await get_tree().process_frame
	if not is_instance_valid(_celebration_card):
		return
	_celebration_card.pivot_offset = _celebration_card.size * 0.5
	_celebration_card.scale = Vector2(0.8, 0.8)

	var entrance := create_tween().set_parallel(true)
	entrance.tween_property(_celebration_card, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	entrance.tween_property(_celebration_card, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _dismiss_celebration() -> void:
	if _celebration_card == null or not is_instance_valid(_celebration_card):
		return

	# Kill the auto-dismiss tween so we don't double-fire.
	if _celebration_tween:
		_celebration_tween.kill()
		_celebration_tween = null

	# Fade out the card.
	var fade := create_tween()
	fade.tween_property(_celebration_card, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	fade.tween_callback(func():
		if is_instance_valid(_celebration_card):
			_celebration_card.queue_free()
			_celebration_card = null
		# Now fully reset the mixing UI for a clean slate.
		_reset_after_celebration()
	)


func _reset_after_celebration() -> void:
	if mixing_manager:
		mixing_manager.reset_beaker()
	_committed = false
	_reset_results()
	_update_ui_state()


# ---------------------------------------------------------------------------
# Note pyramid legend styling
# ---------------------------------------------------------------------------

func _style_pyramid_legend() -> void:
	# Style the note labels (Top / Heart / Base) with larger font.
	for note_ref in [%TopNote, %HeartNote, %BaseNote]:
		note_ref.add_theme_font_size_override("font_size", 13)
		note_ref.add_theme_color_override("font_color", UITheme.NOTE_DIM)
		note_ref.mouse_filter = Control.MOUSE_FILTER_STOP

	# Style the legend descriptions with small muted text.
	var legend_labels := [
		get_node("Panel/VBoxContainer/HBoxContainer/ResultColumn/PyramidSection/LegendColumn/TopLegend"),
		get_node("Panel/VBoxContainer/HBoxContainer/ResultColumn/PyramidSection/LegendColumn/HeartLegend"),
		get_node("Panel/VBoxContainer/HBoxContainer/ResultColumn/PyramidSection/LegendColumn/BaseLegend"),
	]
	for lbl in legend_labels:
		if lbl:
			lbl.add_theme_font_size_override("font_size", 11)
			lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)


# ---------------------------------------------------------------------------
# Beaker shelf background
# ---------------------------------------------------------------------------

func _add_beaker_shelf() -> void:
	if _bottle == null:
		return
	var parent := _bottle.get_parent()
	var idx := _bottle.get_index()

	var shelf := PanelContainer.new()
	shelf.add_theme_stylebox_override("panel", UITheme.make_shelf_bg())
	shelf.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shelf.custom_minimum_size = _bottle.custom_minimum_size

	parent.remove_child(_bottle)
	_bottle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bottle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottle.custom_minimum_size = Vector2.ZERO
	shelf.add_child(_bottle)
	parent.add_child(shelf)
	parent.move_child(shelf, idx)
