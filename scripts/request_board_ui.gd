extends BaseInteractableUI

## Bulletin board UI. Shows the single active request and lets the player deliver perfumes.
## On successful delivery, shows a celebration card with NPC reaction.

# NPC personality → reaction lines (2-3 per personality).
const NPC_REACTIONS := {
	"romantic": [
		"Oh, this is exactly what I dreamed of...",
		"It's like a love letter in a bottle.",
		"My heart is singing. Truly.",
	],
	"outdoorsy": [
		"This smells like a perfect morning hike!",
		"Now that's the scent of adventure.",
		"I can almost feel the breeze. Wonderful.",
	],
	"nostalgic": [
		"This takes me back to simpler days...",
		"Oh my... it's like a memory I'd forgotten.",
		"I can almost hear my grandmother's garden.",
	],
	"sweet-natured": [
		"Oh, how lovely! You're so kind!",
		"This is the sweetest thing anyone's ever made me.",
		"I'll treasure this forever, truly!",
	],
	"picky": [
		"Hmm... yes. This will do nicely.",
		"Acceptable. Better than I expected, actually.",
		"I suppose you do have some talent after all.",
	],
	"practical": [
		"Solid work. Exactly what I asked for.",
		"Efficient and well-made. I appreciate that.",
		"Good. No fuss, no frills — just right.",
	],
	"dramatic": [
		"Magnifique! The world must know of this!",
		"I am undone! This scent is transcendent!",
		"Darling, you've created a masterpiece!",
	],
	"warm-hearted": [
		"My friend, you've outdone yourself!",
		"This warms my old heart. Thank you.",
		"Ah, you always know just what people need.",
	],
	"whimsical": [
		"It's like bottled starlight! How fun!",
		"Ooh, this makes me want to dance!",
	],
	"elegant": [
		"Refined. Tasteful. As it should be.",
		"You have a discerning nose, I see.",
	],
	"studious": [
		"Fascinating composition. Well-researched.",
		"The balance here is quite impressive.",
	],
	"adventurous": [
		"Bold choice! I love it!",
		"Now that's a scent with spirit!",
	],
	"sentimental": [
		"Oh, this makes me feel things...",
		"You've captured something special here.",
	],
	"mysterious": [
		"Intriguing. Most intriguing.",
		"There are hidden depths here... good.",
	],
}

var _celebration_card: PanelContainer = null
var _celebration_tween: Tween = null


func _ready() -> void:
	super()
	_populate_request()
	_populate_bottles()
	RequestManager.request_changed.connect(_on_request_changed)
	CellarManager.bottles_changed.connect(_populate_bottles)


func open() -> void:
	RequestManager.mark_seen()
	_clear_feedback()
	_dismiss_celebration_immediate()
	_populate_request()
	_populate_bottles()
	super()


# ---------------------------------------------------------------------------
# Active request display
# ---------------------------------------------------------------------------

func _populate_request() -> void:
	for child in %RequestDisplay.get_children():
		child.queue_free()

	var req := RequestManager.active_request
	if req == null:
		var lbl := Label.new()
		lbl.text = "All requests completed! Check back later."
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		%RequestDisplay.add_child(lbl)
		return

	var name_lbl := Label.new()
	name_lbl.text = req.request_name
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", UITheme.WARM_AMBER)
	%RequestDisplay.add_child(name_lbl)

	var npc_name := RequestManager.get_npc_name(req)
	if npc_name != "":
		var npc_lbl := Label.new()
		var personality := RequestManager.get_npc_personality(req)
		if personality != "":
			npc_lbl.text = "— %s (%s)" % [npc_name, personality]
		else:
			npc_lbl.text = "— %s" % npc_name
		npc_lbl.add_theme_font_size_override("font_size", 14)
		npc_lbl.add_theme_color_override("font_color", UITheme.HEADER_BROWN)
		%RequestDisplay.add_child(npc_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = "\"%s\"" % req.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	%RequestDisplay.add_child(desc_lbl)

	%RequestDisplay.add_child(HSeparator.new())

	var reward_lbl := Label.new()
	reward_lbl.text = "Reward: " + req.reward_text
	reward_lbl.add_theme_color_override("font_color", UITheme.GOLD)
	reward_lbl.add_theme_font_size_override("font_size", 16)
	reward_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	%RequestDisplay.add_child(reward_lbl)


# ---------------------------------------------------------------------------
# Bottle list
# ---------------------------------------------------------------------------

func _populate_bottles() -> void:
	for child in %BottleList.get_children():
		child.queue_free()

	if CellarManager.bottles.is_empty():
		var lbl := Label.new()
		lbl.text = "No perfumes in inventory."
		lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		%BottleList.add_child(lbl)
		return

	for bottle in CellarManager.bottles:
		var hbox := HBoxContainer.new()

		var info := Label.new()
		info.text = "%s  [%s, %.1f]" % [bottle.get_label(), bottle.get_final_tier(), bottle.get_final_quality()]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.clip_text = true
		hbox.add_child(info)

		var btn := Button.new()
		btn.text = "Deliver"
		btn.disabled = RequestManager.active_request == null
		var b := bottle
		btn.pressed.connect(func(): _on_deliver(b))
		hbox.add_child(btn)

		%BottleList.add_child(hbox)


# ---------------------------------------------------------------------------
# Delivery
# ---------------------------------------------------------------------------

func _on_deliver(bottle: BottledPerfume) -> void:
	var result := RequestManager.deliver_request(bottle)
	if result["success"]:
		CellarManager.deliver_bottle(bottle)
		_clear_feedback()
		_show_delivery_celebration(bottle, result)
	else:
		_show_feedback(result["feedback"], UITheme.SOFT_RED)


func _show_feedback(text: String, color: Color) -> void:
	%FeedbackLabel.text = text
	%FeedbackLabel.add_theme_color_override("font_color", color)
	%FeedbackLabel.show()


func _clear_feedback() -> void:
	%FeedbackLabel.text = ""
	%FeedbackLabel.hide()


func _on_request_changed() -> void:
	_populate_request()


# ---------------------------------------------------------------------------
# Delivery celebration card
# ---------------------------------------------------------------------------

func _get_npc_reaction(personality: String) -> String:
	var lines: Array = NPC_REACTIONS.get(personality, [])
	if lines.is_empty():
		return "Thank you for the lovely perfume!"
	return lines[randi() % lines.size()]


func _show_delivery_celebration(bottle: BottledPerfume, result: Dictionary) -> void:
	_dismiss_celebration_immediate()

	var panel := get_node_or_null("Panel")
	if panel == null:
		return

	var npc_name: String = result.get("npc_name", "")
	var personality: String = result.get("npc_personality", "")
	var req: BaseRequest = result.get("request")

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

	# NPC name header.
	if npc_name != "":
		var name_lbl := Label.new()
		name_lbl.text = npc_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_color_override("font_color", UITheme.HEADER_BROWN)
		name_lbl.add_theme_font_size_override("font_size", 20)
		vbox.add_child(name_lbl)

	# NPC reaction line (personality-driven).
	var reaction_lbl := Label.new()
	reaction_lbl.text = "\"%s\"" % _get_npc_reaction(personality)
	reaction_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reaction_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reaction_lbl.add_theme_color_override("font_color", UITheme.TEXT_DARK)
	reaction_lbl.add_theme_font_size_override("font_size", 14)
	reaction_lbl.custom_minimum_size.x = 220
	vbox.add_child(reaction_lbl)

	# Separator.
	vbox.add_child(HSeparator.new())

	# Perfume label + quality.
	var perfume_lbl := Label.new()
	perfume_lbl.text = bottle.get_label()
	perfume_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	perfume_lbl.add_theme_color_override("font_color", UITheme.TEXT_DARK)
	perfume_lbl.add_theme_font_size_override("font_size", 13)
	perfume_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	perfume_lbl.custom_minimum_size.x = 220
	vbox.add_child(perfume_lbl)

	var tier_lbl := Label.new()
	tier_lbl.text = "%s — %.1f" % [bottle.get_final_tier(), bottle.get_final_quality()]
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_lbl.add_theme_color_override("font_color", UITheme.GOLD)
	tier_lbl.add_theme_font_size_override("font_size", 16)
	vbox.add_child(tier_lbl)

	# Reward line.
	var reward_text := ""
	if req != null:
		reward_text = req.reward_text
	if reward_text != "":
		var reward_lbl := Label.new()
		reward_lbl.text = reward_text
		reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reward_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reward_lbl.add_theme_color_override("font_color", UITheme.SOFT_GREEN)
		reward_lbl.add_theme_font_size_override("font_size", 14)
		vbox.add_child(reward_lbl)

	# Dismiss button.
	var dismiss_btn := Button.new()
	dismiss_btn.text = "Wonderful"
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
	_celebration_card.modulate.a = 0.0
	await get_tree().process_frame
	if not is_instance_valid(_celebration_card):
		return
	_celebration_card.pivot_offset = _celebration_card.size * 0.5
	_celebration_card.scale = Vector2(0.8, 0.8)

	var entrance := create_tween().set_parallel(true)
	entrance.tween_property(_celebration_card, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	entrance.tween_property(_celebration_card, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Auto-dismiss after 3 seconds.
	_celebration_tween = create_tween()
	_celebration_tween.tween_interval(3.0)
	_celebration_tween.tween_callback(_dismiss_celebration)


func _dismiss_celebration() -> void:
	if _celebration_card == null or not is_instance_valid(_celebration_card):
		return

	if _celebration_tween:
		_celebration_tween.kill()
		_celebration_tween = null

	var fade := create_tween()
	fade.tween_property(_celebration_card, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	fade.tween_callback(func():
		if is_instance_valid(_celebration_card):
			_celebration_card.queue_free()
			_celebration_card = null
		_populate_request()
		_populate_bottles()
	)


func _dismiss_celebration_immediate() -> void:
	if _celebration_tween:
		_celebration_tween.kill()
		_celebration_tween = null
	if _celebration_card != null and is_instance_valid(_celebration_card):
		_celebration_card.queue_free()
		_celebration_card = null


func _unhandled_input(event: InputEvent) -> void:
	# Allow clicking or pressing interact/ui_accept to dismiss the card early.
	if _celebration_card != null and is_instance_valid(_celebration_card):
		if event is InputEventMouseButton and event.pressed:
			_dismiss_celebration()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			_dismiss_celebration()
			get_viewport().set_input_as_handled()
			return
	super(event)
