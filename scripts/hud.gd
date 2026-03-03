extends CanvasLayer

## Persistent HUD overlay. Shows coin count in the top-right corner.

var _coin_label: Label


func _ready() -> void:
	layer = 5

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

	_update_display()
	CoinManager.coins_changed.connect(_update_display)


func _update_display() -> void:
	_coin_label.text = str(CoinManager.get_coins())
