extends Area2D

## A corked bottle sitting in the sand. Player presses E to pick it up and read
## the note inside. Registers itself with PlayerInteraction via collision layer 2
## so the existing interact system works unchanged.

const BOTTLE_NOTE_POPUP := preload("res://scenes/bottle_note_popup.tscn")

var _collected := false

func _ready() -> void:
	collision_mask = 0


func collect() -> void:
	if _collected:
		return
	_collected = true

	var note: Dictionary = get_meta("note_data", {})
	var note_id: String = note.get("id", "")
	var note_text: String = note.get("text", "")

	# Mark note as read in BeachManager (persists across visits)
	if note_id != "":
		BeachManager.mark_note_read(note_id)

	# Disable collision so player can't re-interact
	$CollisionShape2D.set_deferred("disabled", true)

	# Spawn the parchment popup
	var popup: BottleNotePopup = BOTTLE_NOTE_POPUP.instantiate()
	get_tree().root.add_child(popup)
	popup.show_note(note_text)

	# Brief shimmer on player
	var player: Node = get_tree().current_scene.find_child("Player")
	if player:
		var tween := get_tree().create_tween()
		tween.tween_property(player, "modulate", Color(0.9, 0.95, 1.0, 1.0), 0.1)
		tween.tween_property(player, "modulate", Color.WHITE, 0.3)

	# Hide this node after popup closes
	popup.closed.connect(queue_free)
