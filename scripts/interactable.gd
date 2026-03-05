extends Area2D
class_name Interactable

signal ingredient_gathered(ingredient: BaseIngredient)

@export var ingredient: BaseIngredient
@export var collect_emoji: String = "🌹"

func _ready() -> void:
	# Ensures this Area2D doesn't block player movement
	collision_mask = 0

var _collected := false

func collect() -> void:
	print("Interactable.collect() called on ", name, " _collected=", _collected, " ingredient=", ingredient)
	if ingredient == null or _collected:
		print("Interactable.collect() early return - null or already collected")
		return
	_collected = true

	# Add to inventory and emit signal
	print("Interactable: Adding to inventory: ", ingredient.display_name)
	InventoryManager.add_ingredient(ingredient)
	ingredient_gathered.emit(ingredient)

	# Show floating text above player
	_show_collect_popup()

	# Shrink bush and remove it
	print("Interactable: Starting shrink tween")
	var tween = get_tree().create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.8)
	await tween.finished
	print("Interactable: Tween finished, queue_free")
	queue_free()

func _show_collect_popup() -> void:
	var player = get_tree().current_scene.find_child("Player")
	if player == null:
		return

	var label = Label.new()
	label.text = "+1 %s" % ingredient.display_name
	label.add_theme_font_size_override("font_size", 16)
	label.position = player.global_position + Vector2(-20, -40)

	# Add to root so it survives the bush being freed
	get_tree().root.add_child(label)

	# Float up and fade out — tween owned by the label, not the bush
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 30, 1.2)
	tween.tween_property(label, "modulate:a", 0.0, 1.2)
	tween.chain().tween_callback(label.queue_free)
