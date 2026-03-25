extends CanvasLayer

## Persistent HUD overlay. Shows coin count and XP progress.

var _coin_label: Label
var _rank_label: Label
var _xp_bar: ProgressBar
var _xp_label: Label
var _xp_panel: PanelContainer


func _ready() -> void:
	layer = 5

	# Hide during the contract opening scene — no coins to show yet.
	if GameStartManager.is_new_game():
		visible = false
		GameStartManager.opening_completed.connect(func(): visible = true, CONNECT_ONE_SHOT)

	_build_coin_panel()
	_build_xp_panel()

	_update_display()
	CoinManager.coins_changed.connect(_update_display)

	_update_xp_display()
	ProgressionManager.xp_changed.connect(_on_xp_changed)
	ProgressionManager.rank_up.connect(_show_rank_up_card)


# ---------------------------------------------------------------------------
# Coin panel (top-right)
# ---------------------------------------------------------------------------

func _build_coin_panel() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -160.0
	panel.offset_top = 10.0
	panel.offset_right = -10.0
	panel.offset_bottom = 50.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	panel.add_child(hbox)

	var icon_lbl := Label.new()
	icon_lbl.text = "Coins:"
	icon_lbl.add_theme_font_size_override("font_size", 16)
	hbox.add_child(icon_lbl)

	_coin_label = Label.new()
	_coin_label.add_theme_font_size_override("font_size", 16)
	_coin_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	hbox.add_child(_coin_label)


func _update_display() -> void:
	_coin_label.text = str(CoinManager.get_coins())


# ---------------------------------------------------------------------------
# XP panel (top-left)
# ---------------------------------------------------------------------------

func _build_xp_panel() -> void:
	_xp_panel = PanelContainer.new()
	_xp_panel.anchor_left = 0.0
	_xp_panel.anchor_top = 0.0
	_xp_panel.anchor_right = 0.0
	_xp_panel.anchor_bottom = 0.0
	_xp_panel.offset_left = 10.0
	_xp_panel.offset_top = 10.0
	_xp_panel.offset_right = 210.0
	_xp_panel.offset_bottom = 60.0
	_xp_panel.grow_horizontal = Control.GROW_DIRECTION_END
	add_child(_xp_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	_xp_panel.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	vbox.add_child(top_row)

	_rank_label = Label.new()
	_rank_label.add_theme_font_size_override("font_size", 14)
	_rank_label.add_theme_color_override("font_color", UITheme.WARM_AMBER)
	top_row.add_child(_rank_label)

	_xp_label = Label.new()
	_xp_label.add_theme_font_size_override("font_size", 12)
	_xp_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	_xp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(_xp_label)

	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(0, 10)
	_xp_bar.show_percentage = false
	vbox.add_child(_xp_bar)


func _update_xp_display() -> void:
	var progress: Dictionary = ProgressionManager.get_xp_progress()
	_rank_label.text = ProgressionManager.current_rank

	if ProgressionManager.is_max_rank():
		_xp_bar.value = 100.0
		_xp_label.text = "MAX"
	else:
		var range_size: int = progress["rank_end"] - progress["rank_start"]
		var filled: int = progress["current"] - progress["rank_start"]
		if range_size > 0:
			_xp_bar.value = clampf(float(filled) / float(range_size) * 100.0, 0.0, 100.0)
		else:
			_xp_bar.value = 0.0
		_xp_label.text = "%d / %d" % [progress["current"], progress["rank_end"]]


func _on_xp_changed(_total_xp: int) -> void:
	_update_xp_display()
	_show_xp_popup()


func _show_xp_popup() -> void:
	var popup := Label.new()
	popup.text = "+XP"
	popup.add_theme_font_size_override("font_size", 14)
	popup.add_theme_color_override("font_color", UITheme.GOLD)
	popup.position = Vector2(_xp_panel.offset_right + 4, _xp_panel.offset_top)
	add_child(popup)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 30.0, 1.2)
	tween.tween_property(popup, "modulate:a", 0.0, 1.2)
	tween.chain().tween_callback(popup.queue_free)


# ---------------------------------------------------------------------------
# Rank-up celebration card
# ---------------------------------------------------------------------------

const RANK_FLAVOR := {
	"Apprentice": {
		"text": "Your nose is getting sharper. Pepper can smell things he couldn't before...",
		"unlock": "A door in the lab has opened — your own workshop awaits.",
	},
	"Journeyman": {
		"text": "Your blends carry a signature that is unmistakably yours.",
		"unlock": "New techniques and rare materials become available.",
	},
	"Master": {
		"text": "They say your perfumes could charm the wind itself.",
		"unlock": "The village looks to you as the master perfumer of Bellefleur.",
	},
}


func _show_rank_up_card(old_rank: String, new_rank: String) -> void:
	# Full-screen overlay to block input.
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Card container.
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -180.0
	card.offset_top = -130.0
	card.offset_right = 180.0
	card.offset_bottom = 130.0
	overlay.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	# "Rank Up!" header.
	var header := Label.new()
	header.text = "Rank Up!"
	header.add_theme_font_size_override("font_size", 28)
	header.add_theme_color_override("font_color", UITheme.GOLD)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	# Old → New rank.
	var rank_line := Label.new()
	rank_line.text = "%s  →  %s" % [old_rank, new_rank]
	rank_line.add_theme_font_size_override("font_size", 20)
	rank_line.add_theme_color_override("font_color", UITheme.HEADER_BROWN)
	rank_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(rank_line)

	# Flavor text.
	var flavor: Dictionary = RANK_FLAVOR.get(new_rank, { "text": "", "unlock": "" })
	if flavor["text"] != "":
		var flavor_lbl := Label.new()
		flavor_lbl.text = flavor["text"]
		flavor_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		flavor_lbl.add_theme_color_override("font_color", UITheme.TEXT_DARK)
		flavor_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(flavor_lbl)

	# Unlock teaser.
	if flavor["unlock"] != "":
		var unlock_lbl := Label.new()
		unlock_lbl.text = flavor["unlock"]
		unlock_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		unlock_lbl.add_theme_font_size_override("font_size", 13)
		unlock_lbl.add_theme_color_override("font_color", UITheme.WARM_AMBER)
		unlock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(unlock_lbl)

	# Continue button.
	var btn := Button.new()
	btn.text = "Continue"
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func(): _dismiss_rank_up_card(overlay))
	vbox.add_child(btn)

	# Scale-in tween.
	card.scale = Vector2(0.6, 0.6)
	card.pivot_offset = card.size / 2.0
	var tween := create_tween()
	tween.tween_property(card, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _dismiss_rank_up_card(overlay: ColorRect) -> void:
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, 0.25)
	tween.tween_callback(overlay.queue_free)
