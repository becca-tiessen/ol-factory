extends Area2D

## An unassuming waxy lump on the sand. Special gathering moment — Pepper goes
## wild, a flavour text appears, and the item goes into inventory as a raw
## material that waits for tincturing to be unlocked.
##
## Ambergris uses a special "ingredient" resource (ambergris.tres) which has
## scent_family = "amber" so the processor NPC can reject it by family.

const AMBERGRIS_PATH := "res://data/ambergris.tres"

var _collected := false

func _ready() -> void:
	collision_mask = 0


func collect() -> void:
	if _collected:
		return
	_collected = true

	if not ResourceLoader.exists(AMBERGRIS_PATH):
		push_warning("AmbergrisInteractable: ambergris.tres not found at %s" % AMBERGRIS_PATH)
		return

	var ingredient := load(AMBERGRIS_PATH) as BaseIngredient
	if ingredient == null:
		return

	InventoryManager.add_ingredient(ingredient)

	$CollisionShape2D.set_deferred("disabled", true)

	# --- Special gathering moment ---
	_show_pepper_reaction()
	_spawn_particle_burst()

	# Shrink and vanish
	var tween := get_tree().create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.9)
	await tween.finished
	queue_free()


func _show_pepper_reaction() -> void:
	# Floating flavour text above the player
	var player: Node = get_tree().current_scene.find_child("Player")
	var pos: Vector2
	if player:
		pos = player.global_position + Vector2(-50, -60)
		# Gold flash — more excited than the usual shimmer
		var tween := get_tree().create_tween()
		tween.tween_property(player, "modulate", Color(1.0, 0.9, 0.5, 1.0), 0.06)
		tween.tween_property(player, "modulate", Color(1.0, 0.95, 0.8, 1.0), 0.12)
		tween.tween_property(player, "modulate", Color.WHITE, 0.35)
	else:
		pos = global_position + Vector2(-50, -60)

	var label := Label.new()
	label.text = "Pepper is losing his mind over this thing..."
	label.add_theme_font_size_override("font_size", 13)
	label.position = pos
	get_tree().root.add_child(label)

	var tween2 := get_tree().create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(label, "position:y", label.position.y - 40, 2.5)
	tween2.tween_property(label, "modulate:a", 0.0, 2.5)
	tween2.chain().tween_callback(label.queue_free)

	# Second line, slightly delayed
	var label2 := Label.new()
	label2.text = "+1 Ambergris"
	label2.add_theme_font_size_override("font_size", 16)
	label2.position = pos + Vector2(10, 20)
	get_tree().root.add_child(label2)

	var tween3 := get_tree().create_tween()
	tween3.set_parallel(true)
	tween3.tween_interval(0.4)
	tween3.chain()
	tween3.set_parallel(true)
	tween3.tween_property(label2, "position:y", label2.position.y - 30, 1.2)
	tween3.tween_property(label2, "modulate:a", 0.0, 1.2)
	tween3.chain().tween_callback(label2.queue_free)


func _spawn_particle_burst() -> void:
	var particles := CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = 18
	particles.lifetime = 1.0
	particles.direction = Vector2(0, -1)
	particles.spread = 140.0
	particles.initial_velocity_min = 20.0
	particles.initial_velocity_max = 50.0
	particles.gravity = Vector2(0, -5)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0

	# Warm amber-gold colour
	var col := Color(1.0, 0.85, 0.4, 0.9)
	particles.color = col
	var grad := Gradient.new()
	grad.set_color(0, col)
	grad.set_color(1, Color(1.0, 0.95, 0.7, 0.0))
	particles.color_ramp = grad

	particles.global_position = global_position
	get_tree().root.add_child(particles)
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.1).timeout.connect(particles.queue_free)
