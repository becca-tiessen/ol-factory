extends Control

## The opening contract-signing scene.
## Displays a parchment deed, lets the player type their name, sign,
## then fades to the castle exterior (courtyard scene).

const COURTYARD_SCENE := "res://scenes/courtyard.tscn"

var _name_input: LineEdit
var _sign_button: Button
var _post_sign_container: VBoxContainer
var _contract_panel: PanelContainer
var _fade_overlay: ColorRect


func _ready() -> void:
	# Full-screen dark background
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_fade_overlay = ColorRect.new()
	_fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.color = Color(0, 0, 0, 0)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.z_index = 100

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.18, 0.14, 0.10)
	add_child(bg)

	# Centered scroll container for the contract
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 80
	scroll.offset_right = -80
	scroll.offset_top = 40
	scroll.offset_bottom = -40
	add_child(scroll)

	# Center wrapper
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.custom_minimum_size.x = 600
	scroll.add_child(center)

	_contract_panel = PanelContainer.new()
	_contract_panel.custom_minimum_size = Vector2(580, 0)
	_contract_panel.add_theme_stylebox_override("panel", _make_parchment_bg())
	center.add_child(_contract_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_contract_panel.add_child(vbox)

	# --- Title ---
	var title := Label.new()
	title.text = "DEED OF TRANSFER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UITheme.HEADER_BROWN)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Commune de Bellefleur"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	vbox.add_child(subtitle)

	_add_separator(vbox)

	var preamble := Label.new()
	preamble.text = "By signing below, the undersigned agrees to the following terms:"
	preamble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preamble.add_theme_color_override("font_color", UITheme.TEXT_DARK)
	vbox.add_child(preamble)

	# --- Clauses ---
	var clauses: Array[String] = [
		"1. The property known as Château Bellefleur, including all structures, grounds, and contents therein, shall be transferred to the undersigned at no cost.",
		"2. The property includes one (1) laboratory, formerly operated as a perfumery, one (1) cellar suitable for storage and aging, and surrounding grounds with native flora.",
		"3. In exchange, the undersigned agrees to restore the perfumery to working condition and contribute to the economic and cultural life of the village of Bellefleur.",
		"4. The commune makes no guarantees regarding the current condition of the property, its contents, or the temperament of the local residents.",
		"5. The undersigned accepts the property entirely as-is.",
	]

	for clause in clauses:
		var lbl := Label.new()
		lbl.text = clause
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_color_override("font_color", UITheme.TEXT_DARK)
		vbox.add_child(lbl)

	_add_separator(vbox)

	# --- Signature area ---
	var sig_label := Label.new()
	sig_label.text = "Signed,"
	sig_label.add_theme_color_override("font_color", UITheme.TEXT_DARK)
	vbox.add_child(sig_label)

	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 12)
	vbox.add_child(input_row)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Your name here..."
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_input.max_length = 24
	_name_input.add_theme_color_override("font_color", UITheme.TEXT_DARK)
	_name_input.add_theme_color_override("font_placeholder_color", UITheme.TEXT_MUTED)
	var input_bg := StyleBoxFlat.new()
	input_bg.bg_color = Color(0.94, 0.90, 0.82)
	input_bg.border_color = UITheme.BORDER_LIGHT
	input_bg.border_width_bottom = 2
	input_bg.content_margin_left = 8
	input_bg.content_margin_right = 8
	input_bg.content_margin_top = 6
	input_bg.content_margin_bottom = 6
	_name_input.add_theme_stylebox_override("normal", input_bg)
	_name_input.add_theme_stylebox_override("focus", input_bg)
	_name_input.text_changed.connect(_on_name_changed)
	_name_input.text_submitted.connect(_on_name_submitted)
	input_row.add_child(_name_input)

	_sign_button = Button.new()
	_sign_button.text = "Sign"
	_sign_button.disabled = true
	_sign_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UITheme.style_commit_button(_sign_button)
	_sign_button.pressed.connect(_on_sign_pressed)
	input_row.add_child(_sign_button)

	# --- Post-sign area (hidden until signed) ---
	_post_sign_container = VBoxContainer.new()
	_post_sign_container.add_theme_constant_override("separation", 16)
	_post_sign_container.visible = false
	vbox.add_child(_post_sign_container)

	# Add the fade overlay last so it's on top
	add_child(_fade_overlay)

	# Focus the name input after a brief delay
	await get_tree().create_timer(0.5).timeout
	_name_input.grab_focus()


func _on_name_changed(new_text: String) -> void:
	var trimmed: String = new_text.strip_edges()
	_sign_button.disabled = trimmed.is_empty()


func _on_name_submitted(_text: String) -> void:
	if not _sign_button.disabled:
		_on_sign_pressed()


func _on_sign_pressed() -> void:
	var chosen_name: String = _name_input.text.strip_edges()
	if chosen_name.is_empty():
		return

	# Disable input
	_name_input.editable = false
	_sign_button.disabled = true
	_sign_button.visible = false

	# Save the name
	GameStartManager.complete_contract(chosen_name)

	# Show post-sign text
	_post_sign_container.visible = true

	var beat_label := Label.new()
	beat_label.text = "\"Congratulations. The château is yours.\nBellefleur is a lovely village — I think you'll fit right in.\""
	beat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	beat_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	beat_label.add_theme_font_size_override("font_size", 15)
	_post_sign_container.add_child(beat_label)

	var continue_btn := Button.new()
	continue_btn.text = "A free castle. There has to be a catch."
	continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_btn.pressed.connect(_on_continue_pressed)
	_post_sign_container.add_child(continue_btn)


func _on_continue_pressed() -> void:
	# Fade to black, then transition to courtyard scene
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "color:a", 1.0, 0.8)
	await tween.finished

	# Brief pause at black — "Three weeks later"
	var time_card := Label.new()
	time_card.text = "Three weeks later."
	time_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	time_card.add_theme_font_size_override("font_size", 22)
	time_card.add_theme_color_override("font_color", Color(0.85, 0.80, 0.70))
	time_card.modulate.a = 0.0
	_fade_overlay.add_child(time_card)

	# Fade the time card in and out
	var card_tween := create_tween()
	card_tween.tween_property(time_card, "modulate:a", 1.0, 0.6)
	card_tween.tween_interval(1.5)
	card_tween.tween_property(time_card, "modulate:a", 0.0, 0.6)
	await card_tween.finished

	# Transition to courtyard — player arrives at the castle entrance
	SceneManager.spawn_marker_name = "SpawnFromLab"
	SceneManager.transition_to_scene(COURTYARD_SCENE)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _add_separator(parent: Node) -> void:
	var sep := HSeparator.new()
	var sep_style := StyleBoxLine.new()
	sep_style.color = UITheme.BORDER_LIGHT
	sep_style.thickness = 1
	sep_style.grow_begin = 4
	sep_style.grow_end = 4
	sep.add_theme_stylebox_override("separator", sep_style)
	parent.add_child(sep)


func _make_parchment_bg() -> StyleBoxFlat:
	var bg := StyleBoxFlat.new()
	bg.bg_color = UITheme.PARCHMENT
	bg.corner_radius_top_left = 8
	bg.corner_radius_top_right = 8
	bg.corner_radius_bottom_left = 8
	bg.corner_radius_bottom_right = 8
	bg.border_color = UITheme.BORDER
	bg.border_width_left = 2
	bg.border_width_right = 2
	bg.border_width_top = 2
	bg.border_width_bottom = 2
	bg.shadow_color = Color(0, 0, 0, 0.3)
	bg.shadow_size = 12
	bg.shadow_offset = Vector2(3, 6)
	bg.content_margin_left = 40
	bg.content_margin_right = 40
	bg.content_margin_top = 32
	bg.content_margin_bottom = 32
	return bg
