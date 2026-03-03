extends Node
class_name PlayerInteraction

# Reference to the player node
var player: CharacterBody2D
var nearby_interactables: Array[Interactable] = []

func _ready() -> void:
	player = get_parent()
	# Find the interaction area (should be a child of Player)
	var interaction_area = player.get_node_or_null("InteractionArea")
	print("PlayerInteraction: InteractionArea found: ", interaction_area)
	if interaction_area:
		interaction_area.area_entered.connect(_on_interaction_area_entered)
		interaction_area.area_exited.connect(_on_interaction_area_exited)
		print("PlayerInteraction: Connected signals")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		print("PlayerInteraction: Interact pressed, nearby count: ", nearby_interactables.size())
		if not nearby_interactables.is_empty():
			# Interact with the closest interactable
			var closest = nearby_interactables[0]
			print("PlayerInteraction: Collecting from: ", closest)
			closest.collect()
			get_tree().root.set_input_as_handled()

func _on_interaction_area_entered(area: Area2D) -> void:
	print("PlayerInteraction: Area entered: ", area, " - is Interactable? ", area is Interactable)
	if area is Interactable:
		nearby_interactables.append(area)
		print("PlayerInteraction: Added interactable, total nearby: ", nearby_interactables.size())

func _on_interaction_area_exited(area: Area2D) -> void:
	if area is Interactable:
		nearby_interactables.erase(area)
		print("PlayerInteraction: Removed interactable, total nearby: ", nearby_interactables.size())
