extends Resource
class_name BaseAccord

@export var accord_name: String = ""
@export var description: String = ""
@export var scent_family: String = ""
@export var note_position: String = "middle"
@export var icon: Texture2D

## Recipe: keys are ingredient resource paths, values are minimum drop counts.
## e.g. { "res://data/vanilla.tres": 1, "res://data/peppermint.tres": 1 }
@export var recipe: Dictionary = {}
