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
	if ingredient == null or _collected:
		return
	_collected = true

	# Add to inventory and emit signal
	InventoryManager.add_ingredient(ingredient)
	ingredient_gathered.emit(ingredient)

	# Visual flourish
	_spawn_particle_burst()
	_shimmer_player()

	# Show floating text above player
	_show_collect_popup()

	# Shrink bush and remove it
	var tween = get_tree().create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.8)
	await tween.finished
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


func _spawn_particle_burst() -> void:
	var particles = CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = 12
	particles.lifetime = 0.7

	# Drift upward and outward gently — pollen / dust motes
	particles.direction = Vector2(0, -1)
	particles.spread = 120.0
	particles.initial_velocity_min = 15.0
	particles.initial_velocity_max = 35.0
	particles.gravity = Vector2(0, -8)  # slight updraft

	# Tiny soft dots
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.0
	particles.scale_amount_curve = _make_fade_curve()

	# Warm golden sparkle, fading to transparent
	var sparkle_color = Color(1.0, 0.95, 0.7, 0.85)
	particles.color = sparkle_color
	var grad = Gradient.new()
	grad.set_color(0, sparkle_color)
	grad.set_color(1, Color(1.0, 1.0, 0.9, 0.0))
	particles.color_ramp = grad

	# Place at the gatherable's world position, parent to root so it survives queue_free
	particles.global_position = global_position
	get_tree().root.add_child(particles)
	particles.emitting = true

	# Auto-cleanup after particles finish
	get_tree().create_timer(particles.lifetime + 0.1).timeout.connect(particles.queue_free)


func _make_fade_curve() -> Curve:
	# Scale: full size then shrink to zero at end of life
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.6, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	return curve


func _shimmer_player() -> void:
	var player = get_tree().current_scene.find_child("Player")
	if player == null:
		return

	# Brief golden flash — like a sparkle washing over the player
	var tween = get_tree().create_tween()
	tween.tween_property(player, "modulate", Color(1.0, 0.97, 0.85, 1.0), 0.08)
	tween.tween_property(player, "modulate", Color.WHITE, 0.25)
