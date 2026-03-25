extends Node2D

## Forest scene — hides Apprentice-tier gatherables until the player reaches
## that rank. Checking in _ready() is sufficient since gatherables respawn on
## scene re-entry and the player can't rank up while in the forest.


func _ready() -> void:
	var group := get_node_or_null("ApprenticeGatherables")
	if group == null:
		return
	var unlocked: bool = ProgressionManager.has_rank("Apprentice")
	group.visible = unlocked
	group.process_mode = Node.PROCESS_MODE_INHERIT if unlocked else Node.PROCESS_MODE_DISABLED
