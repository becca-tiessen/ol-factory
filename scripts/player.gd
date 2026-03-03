extends CharacterBody2D

@export var speed = 100

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

func _physics_process(delta):
	get_input()
	move_and_slide()
