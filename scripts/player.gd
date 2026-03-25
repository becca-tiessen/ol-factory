extends CharacterBody2D

@export var speed = 100

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# If we came from another scene, find the spawn marker
	if SceneManager.spawn_marker_name != "":
		var marker = get_tree().current_scene.find_child(SceneManager.spawn_marker_name)
		if marker:
			global_position = marker.global_position
		SceneManager.spawn_marker_name = ""

func get_input():
	var input_direction = Input.get_vector("left", "right", "up", "down")
	velocity = input_direction * speed

func _update_animation() -> void:
	if velocity == Vector2.ZERO:
		animated_sprite.stop()
		return

	if abs(velocity.y) >= abs(velocity.x):
		if velocity.y > 0:
			animated_sprite.play("walk_down")
		else:
			animated_sprite.play("walk_up")
	else:
		if velocity.x > 0:
			animated_sprite.play("walk_right")
		else:
			animated_sprite.play("walk_left")

func _physics_process(delta):
	if BaseInteractableUI.open_count > 0 or InventoryUI.is_open:
		velocity = Vector2.ZERO
		animated_sprite.stop()
		return
	get_input()
	move_and_slide()
	_update_animation()
