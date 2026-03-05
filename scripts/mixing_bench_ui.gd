extends BaseInteractableUI

var mixing_manager: MixingManager
var _committed := false
var _bottle: BeakerDisplay
var _radar: ScentRadarGraph
var _celebration_card: PanelContainer
var _celebration_tween: Tween
var _request_tab: PanelContainer
var _request_card: PanelContainer
var _request_expanded := false
var _discovery_card: PanelContainer
var _discovery_tween: Tween
var _discovery_paused := false

# Pepper reaction state — only updates when tier threshold changes.
var _last_pepper_tier := ""

func _ready() -> void:
	super()
	mixing_manager = get_tree().root.find_child("MixingManager", true, false)
	if mixing_manager:
		mixing_manager.mixture_updated.connect(_on_mixture_updated)
		mixing_manager.accord_just_discovered.connect(_on_accord_discovered)
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

	# Build the collapsible request tab
	_build_request_tab()

	# Style Pepper's reaction label
	%PepperReaction.add_theme_font_size_override("font_size", 12)
	%PepperReaction.add_theme_color_override("font_color", UITheme.TEXT_MUTED)

	RequestManager.request_changed.connect(_update_request_tracker)
	_update_request_tracker()


func _unhandled_input(event: InputEvent) -> void:
	# Dismiss discovery card on mouse click.
	if _discovery_paused and _discovery_card and is_instance_valid(_discovery_card):
		if event is InputEventMouseButton and event.pressed:
			_dismiss_discovery_card()
			get_viewport().set_input_as_handled()
			return
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
	# Clean up any lingering discovery card.
	_dismiss_discovery_card_immediate()
	# Reset request tab to collapsed on every open.
	_request_expanded = false
	if _request_card and is_instance_valid(_request_card):
		_request_card.hide()
	_update_request_tracker()
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
	if not _committed and not _discovery_paused:
		%CommitButton.disabled = current_mixture.is_empty()
		%UndoButton.disabled = current_mixture.is_empty()


func _update_blend_display(mixture: Array[BaseIngredient]) -> void:
	for child in %BlendList.get_children():
		child.queue_free()

	# Count drops per ingredient and track note positions.
	var counts: Dictionary = {}
	var order: Array[String] = []
	var note_map: Dictionary = {}  # name -> note_position
	for ing in mixture:
		if not counts.has(ing.display_name):
			counts[ing.display_name] = 0
			order.append(ing.display_name)
			note_map[ing.display_name] = ing.note_position
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

	# Sort by note position: top notes first, then middle, then base — matches the beaker visually.
	var note_order := { "top": 0, "middle": 1, "base": 2 }
	order.sort_custom(func(a, b):
		var a_pos: int = note_order.get(note_map.get(a, "middle"), 1)
		var b_pos: int = note_order.get(note_map.get(b, "middle"), 1)
		return a_pos < b_pos
	)
	for ing_name in order:
		var dot_color := BeakerDisplay.color_for_ingredient(ing_name)
		var row := _make_blend_row(dot_color, "%s  x%d" % [ing_name, counts[ing_name]])
		%BlendList.add_child(row)


func _on_commit_pressed() -> void:
	if _committed or _discovery_paused or not mixing_manager:
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

	# Create a bottled perfume and add it to the player's inventory.
	var accords_used := mixing_manager.get_current_accords()
	var bottle := BottledPerfume.create_from_blend(blend, bd, accords_used)
	CellarManager.add_bottle(bottle)

	# Notify request manager of the blend commit (drives rotation counter).
	RequestManager.on_blend_committed()

	# Lock the blend.
	_committed = true
	_update_ui_state()

	# Start the celebration sequence — scoring is revealed inside the card.
	_start_celebration(bd)


func _on_undo_pressed() -> void:
	if _committed or _discovery_paused or not mixing_manager:
		return
	mixing_manager.undo_last_drop()


func _on_clear_pressed() -> void:
	if _committed or _discovery_paused:
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
	if is_empty:
		%HintLabel.text = ""
		_update_pepper_reaction("")
		return

	var blend := mixing_manager.get_blend_summary()
	var bd := mixing_manager.get_current_breakdown()
	var tier: String = bd["tier"]
	var total_drops := mixing_manager.get_current_mixture().size()

	# Hint text — updates on every drop, shows most important issue.
	var hint_text := MixingManager.generate_hints(blend, bd)
	%HintLabel.text = hint_text
	var is_positive: bool = tier == "Good" or tier == "Excellent"
	%HintLabel.add_theme_color_override("font_color", UITheme.SOFT_GREEN if is_positive else UITheme.WARM_AMBER)
	%HintLabel.add_theme_font_size_override("font_size", 11)

	# Pepper reaction — only updates at tier thresholds.
	# For very few drops, show a curious/waiting state instead of judging quality.
	if total_drops <= 2:
		_update_pepper_reaction("Starting")
	else:
		_update_pepper_reaction(tier)


func _reset_results() -> void:
	%HintLabel.text = ""
	%PepperReaction.text = ""
	_last_pepper_tier = ""


func _update_request_tracker() -> void:
	var req := RequestManager.active_request
	if req == null:
		if _request_tab:
			_request_tab.hide()
		if _request_card and is_instance_valid(_request_card):
			_request_card.hide()
		_request_expanded = false
		return

	if _request_tab:
		_request_tab.show()

	# Rebuild expanded card content.
	_rebuild_request_card(req)


# ---------------------------------------------------------------------------
# Collapsible request tab
# ---------------------------------------------------------------------------

func _build_request_tab() -> void:
	var panel := get_node_or_null("Panel")
	if panel == null:
		return

	# -- Collapsed tab: small button pinned to top-right of Panel --
	_request_tab = PanelContainer.new()
	var tab_style := StyleBoxFlat.new()
	tab_style.bg_color = UITheme.WARM_AMBER
	UITheme._set_corners(tab_style, 0)
	tab_style.corner_radius_bottom_left = 6
	tab_style.corner_radius_bottom_right = 6
	tab_style.content_margin_left = 10
	tab_style.content_margin_right = 10
	tab_style.content_margin_top = 4
	tab_style.content_margin_bottom = 4
	_request_tab.add_theme_stylebox_override("panel", tab_style)

	var tab_btn := Button.new()
	tab_btn.name = "RequestTabButton"
	tab_btn.text = "Request"
	tab_btn.add_theme_font_size_override("font_size", 12)
	tab_btn.add_theme_color_override("font_color", UITheme.CARD_BG)
	tab_btn.flat = true
	tab_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tab_btn.pressed.connect(_toggle_request_card)
	_request_tab.add_child(tab_btn)

	# Position: top edge of Panel, right side, slightly inset.
	_request_tab.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_request_tab.anchor_left = 1.0
	_request_tab.anchor_right = 1.0
	_request_tab.anchor_top = 0.0
	_request_tab.anchor_bottom = 0.0
	_request_tab.offset_left = -100.0
	_request_tab.offset_right = -16.0
	_request_tab.offset_top = 0.0
	_request_tab.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.add_child(_request_tab)

	# -- Expanded card: dropdown below the tab --
	_request_card = PanelContainer.new()
	_request_card.name = "RequestCard"
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = UITheme.CARD_BG
	UITheme._set_corners(card_style, 8)
	UITheme._set_border(card_style, 1, UITheme.BORDER)
	card_style.shadow_color = Color(0, 0, 0, 0.15)
	card_style.shadow_size = 8
	card_style.shadow_offset = Vector2(0, 4)
	card_style.content_margin_left = 14
	card_style.content_margin_right = 14
	card_style.content_margin_top = 10
	card_style.content_margin_bottom = 10
	_request_card.add_theme_stylebox_override("panel", card_style)

	var card_vbox := VBoxContainer.new()
	card_vbox.name = "CardContent"
	card_vbox.add_theme_constant_override("separation", 6)
	_request_card.add_child(card_vbox)

	# Position: below the tab, right-aligned.
	_request_card.anchor_left = 1.0
	_request_card.anchor_right = 1.0
	_request_card.anchor_top = 0.0
	_request_card.anchor_bottom = 0.0
	_request_card.offset_left = -260.0
	_request_card.offset_right = -16.0
	_request_card.offset_top = 30.0
	_request_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_request_card.custom_minimum_size = Vector2(240, 0)
	_request_card.hide()
	panel.add_child(_request_card)


func _toggle_request_card() -> void:
	_request_expanded = not _request_expanded
	if _request_card and is_instance_valid(_request_card):
		_request_card.visible = _request_expanded


func _rebuild_request_card(req: BaseRequest) -> void:
	if _request_card == null or not is_instance_valid(_request_card):
		return
	var content := _request_card.get_node_or_null("CardContent")
	if content == null:
		return

	for child in content.get_children():
		child.queue_free()

	# Request name.
	var name_lbl := Label.new()
	name_lbl.text = req.request_name
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", UITheme.WARM_AMBER)
	content.add_child(name_lbl)

	# NPC name + personality.
	var npc_name := RequestManager.get_npc_name(req)
	if npc_name != "":
		var npc_lbl := Label.new()
		var personality := RequestManager.get_npc_personality(req)
		if personality != "":
			npc_lbl.text = "%s (%s)" % [npc_name, personality]
		else:
			npc_lbl.text = npc_name
		npc_lbl.add_theme_font_size_override("font_size", 12)
		npc_lbl.add_theme_color_override("font_color", UITheme.HEADER_BROWN)
		content.add_child(npc_lbl)

	# Separator.
	var sep := HSeparator.new()
	content.add_child(sep)

	# Description (the flavour text — no mechanical details).
	var desc_lbl := Label.new()
	desc_lbl.text = req.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	content.add_child(desc_lbl)


func _clear_live_feedback() -> void:
	%HintLabel.text = ""
	%PepperReaction.text = ""
	_last_pepper_tier = ""


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
# Live accord discovery announcement
# ---------------------------------------------------------------------------

func _on_accord_discovered(accords: Array[BaseAccord]) -> void:
	if accords.is_empty() or _committed:
		return
	# Pepper gets excited about accord discoveries.
	_update_pepper_reaction("", true)
	# Pause mixing interaction and show the discovery card.
	_discovery_paused = true
	%GridContainer.committed = true
	%GridContainer._refresh()
	%CommitButton.disabled = true
	%UndoButton.disabled = true
	%ClearButton.disabled = true
	_show_discovery_card(accords)


func _show_discovery_card(accords: Array[BaseAccord]) -> void:
	var panel := get_node_or_null("Panel")
	if panel == null:
		return

	# Show one card per accord (queue them if multiple, but typically one at a time).
	var accord := accords[0]

	_discovery_card = PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = UITheme.CARD_BG
	UITheme._set_corners(card_style, 12)
	UITheme._set_border(card_style, 2, UITheme.GOLD)
	card_style.shadow_color = Color(0.65, 0.50, 0.12, 0.35)
	card_style.shadow_size = 32
	card_style.shadow_offset = Vector2(0, 0)
	card_style.content_margin_left = 28
	card_style.content_margin_right = 28
	card_style.content_margin_top = 24
	card_style.content_margin_bottom = 24
	_discovery_card.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	_discovery_card.add_child(vbox)

	# Header.
	var header := Label.new()
	header.text = "Accord Discovered!"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", UITheme.HEADER_BROWN)
	header.add_theme_font_size_override("font_size", 14)
	vbox.add_child(header)

	# Accord name — larger, warm gold.
	var name_lbl := Label.new()
	name_lbl.text = accord.accord_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", UITheme.GOLD)
	name_lbl.add_theme_font_size_override("font_size", 22)
	vbox.add_child(name_lbl)

	# Description.
	if accord.description != "":
		var desc_lbl := Label.new()
		desc_lbl.text = accord.description
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.custom_minimum_size.x = 220
		vbox.add_child(desc_lbl)

	# Ingredient list.
	var components := AccordManager.get_recipe_ingredients(accord)
	if not components.is_empty():
		var names: Array[String] = []
		for entry in components:
			names.append((entry["ingredient"] as BaseIngredient).display_name)
		var ing_lbl := Label.new()
		ing_lbl.text = " + ".join(names)
		ing_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ing_lbl.add_theme_color_override("font_color", UITheme.WARM_AMBER)
		ing_lbl.add_theme_font_size_override("font_size", 13)
		vbox.add_child(ing_lbl)

	# Position centered over the Panel.
	_discovery_card.set_anchors_preset(Control.PRESET_CENTER)
	_discovery_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_discovery_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_child(_discovery_card)

	# Entrance animation: scale from 80% with ease-out-back, fade in.
	_discovery_card.modulate.a = 0.0
	await get_tree().process_frame
	if not is_instance_valid(_discovery_card):
		return
	_discovery_card.pivot_offset = _discovery_card.size * 0.5
	_discovery_card.scale = Vector2(0.8, 0.8)

	if _discovery_tween:
		_discovery_tween.kill()
	_discovery_tween = create_tween().set_parallel(true)
	_discovery_tween.tween_property(_discovery_card, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_discovery_tween.tween_property(_discovery_card, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Auto-dismiss after 2.5 seconds, or on click/keypress.
	var remaining_accords := accords.slice(1)
	_discovery_tween.chain().tween_callback(func():
		# Wait for 2.5s then dismiss.
		var timer := get_tree().create_timer(2.5)
		timer.timeout.connect(func(): _dismiss_discovery_card(remaining_accords))
	)


func _dismiss_discovery_card(remaining_accords: Array[BaseAccord] = []) -> void:
	if _discovery_card == null or not is_instance_valid(_discovery_card):
		_end_discovery_pause(remaining_accords)
		return

	if _discovery_tween:
		_discovery_tween.kill()
		_discovery_tween = null

	var fade := create_tween()
	fade.tween_property(_discovery_card, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	fade.tween_callback(func():
		if is_instance_valid(_discovery_card):
			_discovery_card.queue_free()
			_discovery_card = null
		_end_discovery_pause(remaining_accords)
	)


func _end_discovery_pause(remaining_accords: Array[BaseAccord] = []) -> void:
	if not remaining_accords.is_empty():
		# Show next accord discovery card.
		_show_discovery_card(remaining_accords)
		return

	_discovery_paused = false
	# Refresh the ingredient list so the new accord appears.
	%GridContainer.committed = _committed
	%GridContainer._refresh()
	_update_ui_state()


func _dismiss_discovery_card_immediate() -> void:
	_discovery_paused = false
	if _discovery_tween:
		_discovery_tween.kill()
		_discovery_tween = null
	if _discovery_card and is_instance_valid(_discovery_card):
		_discovery_card.queue_free()
		_discovery_card = null


func _unhandled_key_input(event: InputEvent) -> void:
	# Dismiss discovery card on any key press.
	if _discovery_paused and _discovery_card and is_instance_valid(_discovery_card):
		if event is InputEventKey and event.pressed:
			_dismiss_discovery_card()
			get_viewport().set_input_as_handled()



# ---------------------------------------------------------------------------
# Post-commit celebration
# ---------------------------------------------------------------------------

func _start_celebration(bd: Dictionary) -> void:
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
	_celebration_tween.tween_callback(_show_celebration_card.bind(bd))

	# 4. No auto-dismiss — player must press the button on the card.


func _show_celebration_card(bd: Dictionary) -> void:
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

	# Mentor hint — explains why the score is what it is.
	var blend := mixing_manager.get_blend_summary()
	var hint_text := MixingManager.generate_hints(blend, bd)
	if hint_text != "":
		var hint_lbl := Label.new()
		hint_lbl.text = hint_text
		hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint_lbl.add_theme_font_size_override("font_size", 12)
		# Warm color for positive, muted for constructive.
		var is_positive: bool = bd["tier"] == "Good" or bd["tier"] == "Excellent"
		hint_lbl.add_theme_color_override("font_color", UITheme.SOFT_GREEN if is_positive else UITheme.WARM_AMBER)
		vbox.add_child(hint_lbl)

	# Separator.
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Collection message.
	var msg_lbl := Label.new()
	msg_lbl.text = "Bottled and added to your collection."
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	msg_lbl.add_theme_font_size_override("font_size", 13)
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(msg_lbl)

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
# Pepper reaction system
# ---------------------------------------------------------------------------

## Updates Pepper's reaction text only when the quality tier changes.
## This prevents text flickering on every single drop.
func _update_pepper_reaction(tier: String, force_accord := false) -> void:
	if force_accord:
		# Special reaction for accord discovery — always show.
		%PepperReaction.text = "Pepper can't stop sniffing — this is something special."
		%PepperReaction.add_theme_color_override("font_color", UITheme.GOLD)
		_last_pepper_tier = "accord"
		return

	if tier == _last_pepper_tier:
		return
	_last_pepper_tier = tier

	match tier:
		"":
			%PepperReaction.text = ""
		"Starting":
			%PepperReaction.text = "Pepper's waiting patiently..."
			%PepperReaction.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		"Poor":
			%PepperReaction.text = "Pepper just flinched — something's off."
			%PepperReaction.add_theme_color_override("font_color", UITheme.SOFT_RED)
		"Decent":
			%PepperReaction.text = "Pepper's nose is twitching with interest."
			%PepperReaction.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		"Good":
			%PepperReaction.text = "Pepper seems to like where this is going."
			%PepperReaction.add_theme_color_override("font_color", UITheme.SOFT_GREEN)
		"Excellent":
			%PepperReaction.text = "Pepper can't stop sniffing — this is something special."
			%PepperReaction.add_theme_color_override("font_color", UITheme.GOLD)


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
