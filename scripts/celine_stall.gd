class_name CelineStall
extends Area2D

## Céline's glass-bottle stall in the courtyard.
## Becomes visible when her arc reaches stage 5.
## Player presses E to open the shop UI listing her bottle designs.
##
## Collision layer 4, mask 1 (same as NPC — detects Player on layer 1).

const NPC_ID := "celine"

## Bottle designs available for purchase. Each entry:
##   { "id": String, "name": String, "description": String, "price": int }
const DESIGNS: Array = [
	{
		"id": "curved_glass",
		"name": "Curved Glass",
		"description": "A graceful rounded bottle with a gentle silhouette. Perfect for floral blends.",
		"price": 75
	},
	{
		"id": "tall_vessel",
		"name": "Tall Vessel",
		"description": "An elegant elongated shape that shows off the colour of your perfume.",
		"price": 100
	},
	{
		"id": "reclaimed_crystal",
		"name": "Reclaimed Crystal",
		"description": "An angular, faceted bottle made from old crystal glass. Catches light beautifully.",
		"price": 150
	},
]

var _player_nearby: bool = false

@onready var _label: Label = $NameLabel


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if _label != null:
		_label.text = "Céline's Stall"
		_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and event.is_action_pressed("interact"):
		if BaseInteractableUI.open_count == 0:
			_open_shop()
			get_tree().root.set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		_player_nearby = true
		if _label != null:
			_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		_player_nearby = false
		if _label != null:
			_label.visible = false


func _open_shop() -> void:
	# Build the UI inline — a simple CanvasLayer panel listing designs with Buy buttons.
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	get_tree().root.add_child(canvas)

	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_bg())
	panel.theme = UITheme.create_workshop_theme()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(320, 300)
	canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Céline's Glass Bottles"
	UITheme.style_header(title)
	vbox.add_child(title)

	var coins_label := Label.new()
	coins_label.text = "Your coins: %d" % CoinManager.get_coins()
	coins_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	vbox.add_child(coins_label)

	BaseInteractableUI.open_count += 1

	for design in DESIGNS:
		var design_id: String = design["id"]
		var owned: bool = NpcDialogueManager.has_purchased_design(NPC_ID, design_id)

		var row := HBoxContainer.new()
		vbox.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var name_lbl := Label.new()
		name_lbl.text = design["name"]
		UITheme.style_header(name_lbl)
		info.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = design["description"]
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		desc_lbl.add_theme_font_size_override("font_size", 12)
		info.add_child(desc_lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(90, 0)
		if owned:
			btn.text = "Owned"
			btn.disabled = true
			UITheme.style_clear_button(btn)
		else:
			btn.text = "%d coins" % design["price"]
			UITheme.style_commit_button(btn)
			btn.pressed.connect(_on_buy_pressed.bind(design_id, int(design["price"]), canvas, coins_label))
		row.add_child(btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	UITheme.style_clear_button(close_btn)
	close_btn.pressed.connect(func() -> void:
		BaseInteractableUI.open_count = maxi(BaseInteractableUI.open_count - 1, 0)
		canvas.queue_free()
	)
	vbox.add_child(close_btn)


func _on_buy_pressed(design_id: String, price: int, canvas: CanvasLayer, coins_label: Label) -> void:
	if not CoinManager.spend_coins(price):
		# Not enough coins — flash label briefly.
		coins_label.text = "Not enough coins! (%d)" % CoinManager.get_coins()
		return
	NpcDialogueManager.add_purchased_design(NPC_ID, design_id)
	coins_label.text = "Your coins: %d" % CoinManager.get_coins()
	# Rebuild the panel content by closing and reopening.
	BaseInteractableUI.open_count = maxi(BaseInteractableUI.open_count - 1, 0)
	canvas.queue_free()
	_open_shop()
