extends BaseInteractableUI
class_name BottleNotePopup

## Parchment-style popup shown when the player picks up a message in a bottle.
## Extends BaseInteractableUI so it inherits the parchment theme, player-freeze,
## and E-key dismiss behaviour automatically.

@onready var _name_label: Label = $Panel/VBoxContainer/NameLabel
@onready var _text_label: RichTextLabel = $Panel/VBoxContainer/TextLabel

## Opens the popup with the note text. Must be called after adding to the scene tree.
func show_note(note_text: String) -> void:
	_name_label.text = "A Message in a Bottle"
	_text_label.text = note_text
	open()
