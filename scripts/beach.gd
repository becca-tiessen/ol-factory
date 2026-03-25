extends Node2D

## Beach scene root script.
## On _ready, rolls each wash-up spot via BeachManager and activates the
## appropriate gather node (common ingredient, message bottle, ambergris lump,
## or nothing). Fixed gatherables are handled by the Interactable nodes
## themselves — this script only manages the three shoreline wash-up spots.

# Node names for the three wash-up spot containers.
# Each is a Node2D that contains one child node per possible type:
#   "CommonFind"   — Interactable (Area2D), ingredient assigned by this script
#   "BottleNote"   — Area2D with script for note interaction
#   "Ambergris"    — Area2D with script for ambergris interaction
#   (all hidden by default; we show the right one after rolling)
const SPOT_NAMES: Array[String] = ["WashupSpot0", "WashupSpot1", "WashupSpot2"]

func _ready() -> void:
	var results: Array = BeachManager.roll_washup()
	for i in range(SPOT_NAMES.size()):
		var spot: Node2D = get_node_or_null("WashupSpots/" + SPOT_NAMES[i])
		if spot == null:
			continue
		var result: Dictionary = results[i]
		_configure_spot(spot, result)


func _configure_spot(spot: Node2D, result: Dictionary) -> void:
	# Hide everything first
	for child in spot.get_children():
		child.hide()
		if child is Area2D:
			child.process_mode = Node.PROCESS_MODE_DISABLED

	var rtype: String = result.get("type", "nothing")

	match rtype:
		"nothing":
			pass  # All children stay hidden

		"common":
			var node: Node = spot.get_node_or_null("CommonFind")
			if node == null:
				return
			# Assign the rolled ingredient to the Interactable
			var path: String = result.get("ingredient_path", "")
			if path == "":
				return
			if not ResourceLoader.exists(path):
				push_warning("Beach: common find path not found: %s" % path)
				return
			var ingredient := load(path) as BaseIngredient
			if ingredient == null:
				return
			node.ingredient = ingredient
			node.show()
			node.process_mode = Node.PROCESS_MODE_INHERIT

		"note":
			var node: Node = spot.get_node_or_null("BottleNote")
			if node == null:
				return
			var note: Dictionary = result.get("note", {})
			# Store the note data on the node so its script can read it
			node.set_meta("note_data", note)
			node.show()
			node.process_mode = Node.PROCESS_MODE_INHERIT

		"ambergris":
			var node: Node = spot.get_node_or_null("Ambergris")
			if node == null:
				return
			node.show()
			node.process_mode = Node.PROCESS_MODE_INHERIT
