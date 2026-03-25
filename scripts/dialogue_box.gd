class_name DialogueBox
extends CanvasLayer

## Bottom-of-screen dialogue box for NPC conversations.
## Supports linear multi-page dialogue, delivery prompts, and one-line response displays.
##
## Usage:
##   dialogue_box.open(npc_name, lines)               — plain dialogue
##   dialogue_box.open_delivery(npc_name, lines, bottle) — delivery prompt (yes/no)
##   Connects: dialogue_closed, delivery_confirmed(bottle)

signal dialogue_closed
signal delivery_confirmed(bottle: BottledPerfume)

## Emitted internally; never use open_count for this UI — the player freeze is
## handled separately by checking DialogueBox.is_open directly.
static var is_open: bool = false

var _lines: Array[String] = []
var _current_index: int = 0
var _npc_name: String = ""
var _mode: String = "plain"  # "plain" | "delivery" | "response"
var _delivery_bottle: BottledPerfume = null

@onready var _panel: Panel = $Panel
@onready var _name_label: Label = $Panel/VBox/NameLabel
@onready var _text_label: RichTextLabel = $Panel/VBox/TextLabel
@onready var _continue_hint: Label = $Panel/VBox/ContinueHint
@onready var _yes_button: Button = $Panel/VBox/ButtonRow/YesButton
@onready var _no_button: Button = $Panel/VBox/ButtonRow/NoButton
@onready var _button_row: HBoxContainer = $Panel/VBox/ButtonRow


func _ready() -> void:
	layer = 15  # Above HUD (5), below nothing
	_panel.hide()
	_apply_theme()
	_yes_button.pressed.connect(_on_yes_pressed)
	_no_button.pressed.connect(_on_no_pressed)


func _apply_theme() -> void:
	_panel.add_theme_stylebox_override("panel", UITheme.make_panel_bg())
	_panel.theme = UITheme.create_workshop_theme()

	# Name label — header style
	UITheme.style_header(_name_label)

	# Text label — body size
	_text_label.add_theme_font_size_override("normal_font_size", 14)
	_text_label.add_theme_color_override("default_color", UITheme.TEXT_DARK)

	# Continue hint — muted, small
	_continue_hint.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	_continue_hint.add_theme_font_size_override("font_size", 11)

	# Delivery buttons
	UITheme.style_commit_button(_yes_button)
	UITheme.style_clear_button(_no_button)


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if _mode == "plain" or _mode == "response":
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			_advance()
			get_tree().root.set_input_as_handled()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Open for plain linear dialogue.
func open(npc_name: String, lines: Array[String]) -> void:
	_npc_name = npc_name
	_lines = lines
	_current_index = 0
	_mode = "plain"
	_delivery_bottle = null
	_panel.show()
	is_open = true
	BaseInteractableUI.open_count += 1
	_show_current_line()


## Open for a delivery prompt (last line is the prompt question, then yes/no buttons).
func open_delivery(npc_name: String, lines: Array[String], bottle: BottledPerfume) -> void:
	_npc_name = npc_name
	_lines = lines
	_current_index = 0
	_mode = "delivery"
	_delivery_bottle = bottle
	_panel.show()
	is_open = true
	BaseInteractableUI.open_count += 1
	_show_current_line()


## Replace current text with a response line, then close on next advance.
func show_response(line: String) -> void:
	_mode = "response"
	_lines = [line]
	_current_index = 0
	_button_row.hide()
	_continue_hint.show()
	_show_current_line()


# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------

func _show_current_line() -> void:
	if _lines.is_empty():
		_close()
		return

	_name_label.text = _npc_name
	_text_label.text = _lines[_current_index]

	var is_last: bool = _current_index >= _lines.size() - 1

	if _mode == "delivery" and is_last:
		# Show yes/no buttons, hide continue hint
		_button_row.show()
		_continue_hint.hide()
	else:
		_button_row.hide()
		_continue_hint.text = "▼ Continue" if not is_last else "▼ Close"
		_continue_hint.show()


func _advance() -> void:
	_current_index += 1
	if _current_index >= _lines.size():
		_close()
	else:
		_show_current_line()


func _on_yes_pressed() -> void:
	if _delivery_bottle != null:
		delivery_confirmed.emit(_delivery_bottle)
	# show_response will be called by npc.gd after handling the result


func _on_no_pressed() -> void:
	_close()


func _close() -> void:
	_panel.hide()
	if is_open:
		is_open = false
		BaseInteractableUI.open_count = maxi(BaseInteractableUI.open_count - 1, 0)
	dialogue_closed.emit()
