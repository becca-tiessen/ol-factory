extends BaseInteractableUI

## Bulletin board UI. Shows the single active request and lets the player deliver perfumes.


func _ready() -> void:
	super()
	_populate_request()
	_populate_bottles()
	RequestManager.request_changed.connect(_on_request_changed)
	CellarManager.bottles_changed.connect(_populate_bottles)


func open() -> void:
	RequestManager.mark_seen()
	_clear_feedback()
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
	desc_lbl.text = req.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	%RequestDisplay.add_child(desc_lbl)

	var req_lbl := Label.new()
	req_lbl.text = RequestManager.get_requirements_text(req)
	req_lbl.add_theme_color_override("font_color", UITheme.SOFT_BLUE)
	req_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	%RequestDisplay.add_child(req_lbl)

	var reward_lbl := Label.new()
	reward_lbl.text = "Reward: " + req.reward_text
	reward_lbl.add_theme_color_override("font_color", UITheme.SOFT_GREEN)
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
		_show_feedback(result["feedback"], UITheme.SOFT_GREEN)
		_populate_request()
		_populate_bottles()
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
