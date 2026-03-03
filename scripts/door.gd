extends Area2D

@export_file("*.tscn") var target_scene: String
@export var spawn_marker_name: String = "SpawnPoint"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and target_scene != "":
		# Store the marker name so we can find it in the new scene
		SceneManager.spawn_marker_name = spawn_marker_name
		# Change to the target scene
		get_tree().change_scene_to_file(target_scene)
